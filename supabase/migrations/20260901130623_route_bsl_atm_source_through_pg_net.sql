-- Fetch public OSM data through pg_net, whose egress path can reach the
-- Overpass provider, then pass the validated response to the locked Edge
-- Function for normalization and database writes.

alter table private.bsl_atm_sync_state
  add column if not exists source_request_id bigint,
  add column if not exists source_requested_at timestamp with time zone,
  add column if not exists source_completed_at timestamp with time zone,
  add column if not exists source_attempt_count smallint not null default 0
    check (source_attempt_count between 0 and 3),
  add column if not exists ingest_request_id bigint,
  add column if not exists ingest_completed_at timestamp with time zone,
  add column if not exists ingest_attempt_count smallint not null default 0
    check (ingest_attempt_count between 0 and 3),
  add column if not exists last_error text;

create or replace function private.bsl_queue_atm_sector(
  p_sector integer,
  p_retry boolean default false
)
returns bigint
language plpgsql
volatile
security definer
set search_path = ''
set statement_timeout = '5s'
as $function$
declare
  v_box text;
  v_query text;
  v_request_id bigint;
  v_attempt smallint;
begin
  case p_sector
    when 0 then v_box := '44.0,15.5,45.4,17.7';
    when 1 then v_box := '44.0,17.7,45.4,19.8';
    when 2 then v_box := '42.4,15.5,44.0,17.7';
    when 3 then v_box := '42.4,17.7,44.0,19.8';
    else
      raise exception using
        errcode = '22023',
        message = 'p_sector must be 0..3';
  end case;

  select source_attempt_count
  into v_attempt
  from private.bsl_atm_sync_state
  where sector = p_sector
  for update;

  if not found then
    raise exception 'ATM sync state is missing for sector %', p_sector;
  end if;

  if p_retry then
    if v_attempt >= 3 then
      raise exception 'ATM source retry limit reached for sector %', p_sector;
    end if;
    v_attempt := v_attempt + 1;
  else
    v_attempt := 1;
  end if;

  v_query := format(
    '[out:json][timeout:45];nwr["amenity"~"^(atm|bank)$"](%s);out center tags;',
    v_box
  );

  v_request_id := net.http_get(
    url := 'https://maps.mail.ru/osm/tools/overpass/api/interpreter',
    params := jsonb_build_object('data', v_query),
    headers := jsonb_build_object(
      'Accept', 'application/json',
      'User-Agent', 'BalkanSmartLife-ATM-Sync/3.0'
    ),
    timeout_milliseconds := 90000
  );

  update private.bsl_atm_sync_state
  set source_request_id = v_request_id,
      source_requested_at = now(),
      source_completed_at = null,
      source_attempt_count = v_attempt,
      ingest_request_id = null,
      ingest_completed_at = null,
      ingest_attempt_count = 0,
      last_error = case when p_retry then last_error else null end,
      updated_at = now()
  where sector = p_sector;

  return v_request_id;
end;
$function$;

alter function private.bsl_queue_atm_sector(integer, boolean)
  owner to postgres;
revoke all on function private.bsl_queue_atm_sector(integer, boolean)
  from public, anon, authenticated, service_role;

create or replace function private.bsl_dispatch_pending_atm_sectors()
returns integer
language plpgsql
volatile
security definer
set search_path = ''
set statement_timeout = '30s'
as $function$
declare
  v_state record;
  v_status integer;
  v_timed_out boolean;
  v_error text;
  v_content text;
  v_payload jsonb;
  v_osm_timestamp timestamp with time zone;
  v_secret text;
  v_ingest_id bigint;
  v_dispatched integer := 0;
  v_failure text;
begin
  select decrypted_secret
  into v_secret
  from vault.decrypted_secrets
  where name = 'bsl_atm_sync_secret'
  limit 1;

  if v_secret is null then
    raise exception 'BSL ATM sync secret is unavailable';
  end if;

  for v_state in
    select *
    from private.bsl_atm_sync_state
    where source_request_id is not null
      and source_completed_at is null
    order by sector
    for update
  loop
    v_status := null;
    v_timed_out := null;
    v_error := null;
    v_content := null;

    select status_code, timed_out, error_msg, content
    into v_status, v_timed_out, v_error, v_content
    from net._http_response
    where id = v_state.source_request_id;

    if not found then
      if v_state.source_requested_at < now() - interval '3 minutes' then
        v_failure := 'Overpass response was not available after 3 minutes';
        update private.bsl_atm_sync_state
        set source_completed_at = now(),
            last_error = v_failure,
            updated_at = now()
        where sector = v_state.sector;

        if v_state.source_attempt_count < 3 then
          perform private.bsl_queue_atm_sector(v_state.sector, true);
        end if;
      end if;
      continue;
    end if;

    if coalesce(v_timed_out, false)
       or v_status is distinct from 200
       or v_content is null then
      v_failure := format(
        'Overpass request failed (HTTP %s%s)',
        coalesce(v_status::text, 'none'),
        case when coalesce(v_timed_out, false) then ', timeout' else '' end
      );
      update private.bsl_atm_sync_state
      set source_completed_at = now(),
          last_error = v_failure,
          updated_at = now()
      where sector = v_state.sector;

      if v_state.source_attempt_count < 3 then
        perform private.bsl_queue_atm_sector(v_state.sector, true);
      end if;
      continue;
    end if;

    if length(v_content) > 10000000 then
      v_failure := 'Overpass response exceeded the 10 MB safety limit';
      update private.bsl_atm_sync_state
      set source_completed_at = now(),
          last_error = v_failure,
          updated_at = now()
      where sector = v_state.sector;
      continue;
    end if;

    begin
      v_payload := v_content::jsonb;
      v_osm_timestamp :=
        (v_payload #>> '{osm3s,timestamp_osm_base}')::timestamp with time zone;
    exception when others then
      v_payload := null;
      v_osm_timestamp := null;
    end;

    if v_payload is null
       or jsonb_typeof(v_payload) <> 'object'
       or jsonb_typeof(v_payload -> 'elements') <> 'array'
       or jsonb_array_length(v_payload -> 'elements') not between 10 and 5000
       or nullif(v_payload ->> 'remark', '') is not null
       or v_osm_timestamp is null
       or v_osm_timestamp < now() - interval '7 days'
       or v_osm_timestamp > now() + interval '1 day' then
      v_failure := 'Overpass response failed shape, count, or freshness validation';
      update private.bsl_atm_sync_state
      set source_completed_at = now(),
          last_error = v_failure,
          updated_at = now()
      where sector = v_state.sector;

      if v_state.source_attempt_count < 3 then
        perform private.bsl_queue_atm_sector(v_state.sector, true);
      end if;
      continue;
    end if;

    v_ingest_id := net.http_post(
      url := 'https://jkzjktrnqtkpdiiugfar.supabase.co/functions/v1/sync-bsl-atm-osm',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-bsl-sync-secret', v_secret
      ),
      body := jsonb_build_object(
        'sector', v_state.sector,
        'payload', v_payload
      ),
      timeout_milliseconds := 90000
    );

    update private.bsl_atm_sync_state
    set source_completed_at = now(),
        ingest_request_id = v_ingest_id,
        ingest_completed_at = null,
        ingest_attempt_count = ingest_attempt_count + 1,
        last_error = null,
        updated_at = now()
    where sector = v_state.sector;

    v_dispatched := v_dispatched + 1;
  end loop;

  for v_state in
    select *
    from private.bsl_atm_sync_state
    where ingest_request_id is not null
      and ingest_completed_at is null
    order by sector
    for update
  loop
    if v_state.last_succeeded_at is not null
       and v_state.last_succeeded_at >= v_state.source_requested_at then
      update private.bsl_atm_sync_state
      set ingest_completed_at = now(),
          last_error = null,
          updated_at = now()
      where sector = v_state.sector;
      continue;
    end if;

    v_status := null;
    v_timed_out := null;
    v_error := null;
    v_content := null;

    select status_code, timed_out, error_msg, content
    into v_status, v_timed_out, v_error, v_content
    from net._http_response
    where id = v_state.ingest_request_id;

    if not found then
      if v_state.source_completed_at < now() - interval '3 minutes' then
        v_failure := 'Edge ingest response was not available after 3 minutes';
      else
        continue;
      end if;
    elsif coalesce(v_timed_out, false) or v_status is distinct from 200 then
      v_failure := format(
        'Edge ingest failed (HTTP %s%s)',
        coalesce(v_status::text, 'none'),
        case when coalesce(v_timed_out, false) then ', timeout' else '' end
      );
    else
      update private.bsl_atm_sync_state
      set ingest_completed_at = now(),
          last_error = null,
          updated_at = now()
      where sector = v_state.sector;
      continue;
    end if;

    update private.bsl_atm_sync_state
    set ingest_completed_at = now(),
        last_error = v_failure,
        updated_at = now()
    where sector = v_state.sector;

    if v_state.ingest_attempt_count < 3 then
      update private.bsl_atm_sync_state
      set source_completed_at = null,
          ingest_request_id = null,
          ingest_completed_at = null,
          updated_at = now()
      where sector = v_state.sector;
    end if;
  end loop;

  return v_dispatched;
end;
$function$;

alter function private.bsl_dispatch_pending_atm_sectors()
  owner to postgres;
revoke all on function private.bsl_dispatch_pending_atm_sectors()
  from public, anon, authenticated, service_role;

comment on function private.bsl_queue_atm_sector(integer, boolean) is
  'Queues one bounded, read-only Overpass request through pg_net.';
comment on function private.bsl_dispatch_pending_atm_sectors() is
  'Validates queued Overpass responses and submits them to the locked ATM ingest function.';

do $unschedule_old_atm_jobs$
declare
  v_job record;
begin
  for v_job in
    select jobid
    from cron.job
    where jobname in (
      'bsl-atm-osm-sector-0',
      'bsl-atm-osm-sector-1',
      'bsl-atm-osm-sector-2',
      'bsl-atm-osm-sector-3',
      'bsl-atm-osm-dispatch'
    )
  loop
    perform cron.unschedule(v_job.jobid);
  end loop;
end;
$unschedule_old_atm_jobs$;

select cron.schedule(
  'bsl-atm-osm-sector-0',
  '17 1 * * 1,4',
  'select private.bsl_queue_atm_sector(0);'
);

select cron.schedule(
  'bsl-atm-osm-sector-1',
  '37 1 * * 1,4',
  'select private.bsl_queue_atm_sector(1);'
);

select cron.schedule(
  'bsl-atm-osm-sector-2',
  '57 1 * * 1,4',
  'select private.bsl_queue_atm_sector(2);'
);

select cron.schedule(
  'bsl-atm-osm-sector-3',
  '17 2 * * 1,4',
  'select private.bsl_queue_atm_sector(3);'
);

select cron.schedule(
  'bsl-atm-osm-dispatch',
  '*/5 1-2 * * 1,4',
  'select private.bsl_dispatch_pending_atm_sectors();'
);

-- Secure and schedule the OSM ATM refresh without exposing privileged write
-- routines or storing a service-role credential in source control.

create extension if not exists pg_cron;

create index if not exists idx_bsl_atm_sources_bank_id
  on public.bsl_atm_sources (bank_id);

create table if not exists private.bsl_atm_sync_state (
  sector smallint primary key check (sector between 0 and 3),
  last_succeeded_at timestamp with time zone,
  seen_count integer not null default 0 check (seen_count >= 0),
  deactivated_count integer not null default 0 check (deactivated_count >= 0),
  updated_at timestamp with time zone not null default now()
);

alter table private.bsl_atm_sync_state enable row level security;
revoke all on table private.bsl_atm_sync_state
  from public, anon, authenticated;
grant all on table private.bsl_atm_sync_state to service_role;

insert into private.bsl_atm_sync_state (sector)
select sector
from generate_series(0, 3) as sector
on conflict (sector) do nothing;

do $create_sync_secret$
begin
  if not exists (
    select 1
    from vault.secrets
    where name = 'bsl_atm_sync_secret'
  ) then
    perform vault.create_secret(
      encode(extensions.gen_random_bytes(32), 'hex'),
      'bsl_atm_sync_secret',
      'Random credential used only by pg_cron to invoke the BSL ATM sync.'
    );
  end if;
end;
$create_sync_secret$;

create or replace function api.bsl_verify_atm_sync_secret(
  p_secret text
)
returns boolean
language sql
stable
security definer
set search_path = ''
set statement_timeout = '1s'
as $function$
  select case
    when p_secret is null or p_secret !~ '^[a-f0-9]{64}$' then false
    else exists (
      select 1
      from vault.decrypted_secrets s
      where s.name = 'bsl_atm_sync_secret'
        and extensions.digest(p_secret, 'sha256') =
            extensions.digest(s.decrypted_secret, 'sha256')
    )
  end;
$function$;

alter function api.bsl_verify_atm_sync_secret(text) owner to postgres;
revoke all on function api.bsl_verify_atm_sync_secret(text)
  from public, anon, authenticated;
grant execute on function api.bsl_verify_atm_sync_secret(text)
  to service_role;

create or replace function api.bsl_finalize_osm_atm_sector(
  p_sector integer,
  p_started_at timestamp with time zone,
  p_seen jsonb
)
returns integer
language plpgsql
volatile
security definer
set search_path = ''
set statement_timeout = '8s'
as $function$
declare
  v_south double precision;
  v_west double precision;
  v_north double precision;
  v_east double precision;
  v_seen_count integer;
  v_deactivated integer;
begin
  case p_sector
    when 0 then
      v_south := 44.0; v_west := 15.5; v_north := 45.4; v_east := 17.7;
    when 1 then
      v_south := 44.0; v_west := 17.7; v_north := 45.4; v_east := 19.8;
    when 2 then
      v_south := 42.4; v_west := 15.5; v_north := 44.0; v_east := 17.7;
    when 3 then
      v_south := 42.4; v_west := 17.7; v_north := 44.0; v_east := 19.8;
    else
      raise exception using
        errcode = '22023',
        message = 'p_sector must be 0..3';
  end case;

  if p_started_at is null
     or p_started_at < now() - interval '30 minutes'
     or p_started_at > now() + interval '1 minute' then
    raise exception using
      errcode = '22023',
      message = 'p_started_at is outside the allowed sync window';
  end if;

  if p_seen is null or jsonb_typeof(p_seen) <> 'array' then
    raise exception using
      errcode = '22023',
      message = 'p_seen must be a JSON array';
  end if;

  v_seen_count := jsonb_array_length(p_seen);
  if v_seen_count < 10 or v_seen_count > 5000 then
    raise exception using
      errcode = '22023',
      message = 'p_seen must contain between 10 and 5000 candidates';
  end if;

  if exists (
    select 1
    from jsonb_to_recordset(p_seen) as r(osm_type text, osm_id bigint)
    where r.osm_type is null
       or r.osm_type not in ('node', 'way', 'relation')
       or r.osm_id is null
       or r.osm_id <= 0
  ) then
    raise exception using
      errcode = '22023',
      message = 'p_seen contains an invalid OSM identifier';
  end if;

  with seen as (
    select distinct r.osm_type, r.osm_id
    from jsonb_to_recordset(p_seen) as r(osm_type text, osm_id bigint)
  ), deactivated as (
    update public.bsl_osm_atm_candidates c
    set atm_confirmed = false
    where c.atm_confirmed = true
      and c.imported_at < p_started_at
      and c.latitude between v_south and v_north
      and c.longitude between v_west and v_east
      and not exists (
        select 1
        from seen s
        where s.osm_type = c.osm_type
          and s.osm_id = c.osm_id
      )
    returning 1
  )
  select count(*) into v_deactivated from deactivated;

  insert into private.bsl_atm_sync_state (
    sector,
    last_succeeded_at,
    seen_count,
    deactivated_count,
    updated_at
  ) values (
    p_sector,
    now(),
    v_seen_count,
    v_deactivated,
    now()
  )
  on conflict (sector) do update
  set last_succeeded_at = excluded.last_succeeded_at,
      seen_count = excluded.seen_count,
      deactivated_count = excluded.deactivated_count,
      updated_at = excluded.updated_at;

  return v_deactivated;
end;
$function$;

alter function api.bsl_finalize_osm_atm_sector(
  integer,
  timestamp with time zone,
  jsonb
) owner to postgres;
revoke all on function api.bsl_finalize_osm_atm_sector(
  integer,
  timestamp with time zone,
  jsonb
) from public, anon, authenticated;
grant execute on function api.bsl_finalize_osm_atm_sector(
  integer,
  timestamp with time zone,
  jsonb
) to service_role;

-- Keep bank branches available as address-based geocoding candidates, but do
-- not rematch standalone ATM objects that a complete sector refresh no longer
-- reports as active ATMs.
create or replace function public.bsl_match_osm_atms()
returns integer
language plpgsql
volatile
security definer
set search_path = ''
set statement_timeout = '8s'
as $function$
declare
  v_count integer := 0;
begin
  update public.bsl_atm_locations
  set latitude = null,
      longitude = null,
      geo_source = null,
      geo_confidence = 0,
      geocode_status = 'pending'
  where geocode_status = 'matched_osm';

  update public.bsl_osm_atm_candidates
  set matched_location_id = null,
      match_confidence = null
  where matched_location_id is not null
     or match_confidence is not null;

  with possible_base as (
    select
      c.osm_type,
      c.osm_id,
      c.latitude,
      c.longitude,
      l.location_id,
      extensions.similarity(
        public.bsl_norm_text(concat_ws(' ', c.addr_street, c.addr_housenumber)),
        public.bsl_norm_text(l.address)
      ) as addr_similarity
    from public.bsl_osm_atm_candidates c
    join public.bsl_banks b on b.active and (
      b.bank_id = c.bank_key
      or (c.bank_key = 'addiko' and b.bank_id like 'addiko_%')
      or (c.bank_key = 'nlb' and b.bank_id like 'nlb_%')
      or (c.bank_key = 'unicredit' and b.bank_id like 'unicredit_%')
    )
    join public.bsl_atm_locations l on l.bank_id = b.bank_id
      and public.bsl_norm_text(l.city) =
          public.bsl_norm_text(coalesce(c.addr_city, c.addr_place, ''))
    where c.bank_key is not null
      and (
        c.atm_confirmed = true
        or coalesce(c.tags ->> 'amenity', '') = 'bank'
      )
      and public.bsl_norm_text(
        concat_ws(' ', c.addr_street, c.addr_housenumber)
      ) <> ''
      and l.record_status in ('active', 'source_stale')
      and l.geocode_status not in ('manual_verified', 'official_coordinates')
  ), ranked as (
    select
      p.*,
      0.55 + 0.45 * p.addr_similarity as score,
      row_number() over (
        partition by p.location_id
        order by p.addr_similarity desc, p.osm_type, p.osm_id
      ) as rank_for_location,
      row_number() over (
        partition by p.osm_type, p.osm_id
        order by p.addr_similarity desc, p.location_id
      ) as rank_for_candidate
    from possible_base p
  ), winners as (
    select *
    from ranked
    where rank_for_location = 1
      and rank_for_candidate = 1
      and score >= 0.78
  ), updated_locations as (
    update public.bsl_atm_locations l
    set latitude = w.latitude,
        longitude = w.longitude,
        geo_source = 'OpenStreetMap/Overpass',
        geo_confidence = w.score,
        geocode_status = 'matched_osm',
        last_verified_at = current_date
    from winners w
    where l.location_id = w.location_id
    returning l.location_id
  ), updated_candidates as (
    update public.bsl_osm_atm_candidates c
    set matched_location_id = w.location_id,
        match_confidence = w.score
    from winners w
    where c.osm_type = w.osm_type
      and c.osm_id = w.osm_id
    returning c.osm_type, c.osm_id
  )
  select count(*) into v_count from updated_candidates;

  return v_count;
end;
$function$;

alter function public.bsl_match_osm_atms() owner to postgres;
revoke all on function public.bsl_match_osm_atms()
  from public, anon, authenticated;
grant execute on function public.bsl_match_osm_atms() to service_role;

create or replace function private.bsl_atm_sync_health_internal()
returns table (
  healthy boolean,
  oldest_sector_sync_at timestamp with time zone,
  confirmed_candidates bigint,
  pending_official_locations bigint
)
language sql
stable
security definer
set search_path = ''
set statement_timeout = '3s'
as $function$
  with state as (
    select
      count(*) filter (where last_succeeded_at is not null) as synced_sectors,
      min(last_succeeded_at) as oldest_sector_sync_at
    from private.bsl_atm_sync_state
  ), metrics as (
    select
      count(*) filter (where atm_confirmed = true) as confirmed_candidates
    from public.bsl_osm_atm_candidates
  ), official as (
    select count(*) as pending_official_locations
    from public.bsl_atm_locations
    where record_status in ('active', 'source_stale')
      and geocode_status = 'pending'
  )
  select
    coalesce(
      state.synced_sectors = 4
      and state.oldest_sector_sync_at >= now() - interval '5 days',
      false
    ) as healthy,
    state.oldest_sector_sync_at,
    metrics.confirmed_candidates,
    official.pending_official_locations
  from state
  cross join metrics
  cross join official;
$function$;

alter function private.bsl_atm_sync_health_internal() owner to postgres;
revoke all on function private.bsl_atm_sync_health_internal()
  from public;
grant usage on schema private to anon, authenticated, service_role;
grant execute on function private.bsl_atm_sync_health_internal()
  to anon, authenticated, service_role;

create or replace function api.bsl_atm_sync_health()
returns table (
  healthy boolean,
  oldest_sector_sync_at timestamp with time zone,
  confirmed_candidates bigint,
  pending_official_locations bigint
)
language sql
stable
security invoker
set search_path = ''
as $function$
  select * from private.bsl_atm_sync_health_internal();
$function$;

alter function api.bsl_atm_sync_health() owner to postgres;
revoke all on function api.bsl_atm_sync_health() from public;
grant execute on function api.bsl_atm_sync_health()
  to anon, authenticated, service_role;

comment on function api.bsl_verify_atm_sync_secret(text) is
  'Service-only verifier for the random Vault credential used by the ATM sync.';
comment on function api.bsl_finalize_osm_atm_sector(
  integer,
  timestamp with time zone,
  jsonb
) is
  'Service-only reconciliation of a complete bounded OSM ATM sector refresh.';
comment on function api.bsl_atm_sync_health() is
  'Read-only bounded health summary for the four scheduled OSM ATM sectors.';

select cron.schedule(
  'bsl-atm-osm-sector-0',
  '17 1 * * 1,4',
  $cron$
    select net.http_post(
      url := 'https://jkzjktrnqtkpdiiugfar.supabase.co/functions/v1/sync-bsl-atm-osm',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-bsl-sync-secret', (
          select decrypted_secret
          from vault.decrypted_secrets
          where name = 'bsl_atm_sync_secret'
        )
      ),
      body := '{"sector":0}'::jsonb,
      timeout_milliseconds := 90000
    ) as request_id;
  $cron$
);

select cron.schedule(
  'bsl-atm-osm-sector-1',
  '37 1 * * 1,4',
  $cron$
    select net.http_post(
      url := 'https://jkzjktrnqtkpdiiugfar.supabase.co/functions/v1/sync-bsl-atm-osm',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-bsl-sync-secret', (
          select decrypted_secret
          from vault.decrypted_secrets
          where name = 'bsl_atm_sync_secret'
        )
      ),
      body := '{"sector":1}'::jsonb,
      timeout_milliseconds := 90000
    ) as request_id;
  $cron$
);

select cron.schedule(
  'bsl-atm-osm-sector-2',
  '57 1 * * 1,4',
  $cron$
    select net.http_post(
      url := 'https://jkzjktrnqtkpdiiugfar.supabase.co/functions/v1/sync-bsl-atm-osm',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-bsl-sync-secret', (
          select decrypted_secret
          from vault.decrypted_secrets
          where name = 'bsl_atm_sync_secret'
        )
      ),
      body := '{"sector":2}'::jsonb,
      timeout_milliseconds := 90000
    ) as request_id;
  $cron$
);

select cron.schedule(
  'bsl-atm-osm-sector-3',
  '17 2 * * 1,4',
  $cron$
    select net.http_post(
      url := 'https://jkzjktrnqtkpdiiugfar.supabase.co/functions/v1/sync-bsl-atm-osm',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-bsl-sync-secret', (
          select decrypted_secret
          from vault.decrypted_secrets
          where name = 'bsl_atm_sync_secret'
        )
      ),
      body := '{"sector":3}'::jsonb,
      timeout_milliseconds := 90000
    ) as request_id;
  $cron$
);

notify pgrst, 'reload schema';

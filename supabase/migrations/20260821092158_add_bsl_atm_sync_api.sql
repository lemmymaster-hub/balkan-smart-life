-- Production migration version: 20260821092158.
-- Keep the OSM Edge Function operational while public remains outside
-- PostgREST. These routines are callable only with the service role.

create or replace function api.bsl_upsert_osm_atm_candidates(
  p_rows jsonb
)
returns integer
language plpgsql
volatile
security definer
set search_path = ''
set statement_timeout = '8s'
as $function$
declare
  v_input_count integer;
  v_affected integer;
begin
  if p_rows is null or jsonb_typeof(p_rows) <> 'array' then
    raise exception using
      errcode = '22023',
      message = 'p_rows must be a JSON array';
  end if;

  v_input_count := jsonb_array_length(p_rows);
  if v_input_count > 250 then
    raise exception using
      errcode = '22023',
      message = 'p_rows may contain at most 250 candidates';
  end if;

  if v_input_count = 0 then
    return 0;
  end if;

  if exists (
    select 1
    from jsonb_to_recordset(p_rows) as r(
      osm_type text,
      osm_id bigint,
      latitude double precision,
      longitude double precision
    )
    where r.osm_type not in ('node', 'way', 'relation')
       or r.osm_type is null
       or r.osm_id is null
       or r.latitude is null
       or r.latitude::text in ('NaN', 'Infinity', '-Infinity')
       or r.latitude < -90
       or r.latitude > 90
       or r.longitude is null
       or r.longitude::text in ('NaN', 'Infinity', '-Infinity')
       or r.longitude < -180
       or r.longitude > 180
  ) then
    raise exception using
      errcode = '22023',
      message = 'p_rows contains an invalid OSM candidate';
  end if;

  insert into public.bsl_osm_atm_candidates (
    osm_type,
    osm_id,
    latitude,
    longitude,
    name,
    operator,
    brand,
    network,
    addr_city,
    addr_place,
    addr_street,
    addr_housenumber,
    bank_key,
    tags,
    imported_at,
    atm_confirmed
  )
  select
    r.osm_type,
    r.osm_id,
    r.latitude,
    r.longitude,
    r.name,
    r.operator,
    r.brand,
    r.network,
    r.addr_city,
    r.addr_place,
    r.addr_street,
    r.addr_housenumber,
    r.bank_key,
    coalesce(r.tags, '{}'::jsonb),
    coalesce(r.imported_at, now()),
    coalesce(r.atm_confirmed, true)
  from jsonb_to_recordset(p_rows) as r(
    osm_type text,
    osm_id bigint,
    latitude double precision,
    longitude double precision,
    name text,
    operator text,
    brand text,
    network text,
    addr_city text,
    addr_place text,
    addr_street text,
    addr_housenumber text,
    bank_key text,
    tags jsonb,
    imported_at timestamp with time zone,
    atm_confirmed boolean
  )
  on conflict (osm_type, osm_id) do update
  set latitude = excluded.latitude,
      longitude = excluded.longitude,
      name = excluded.name,
      operator = excluded.operator,
      brand = excluded.brand,
      network = excluded.network,
      addr_city = excluded.addr_city,
      addr_place = excluded.addr_place,
      addr_street = excluded.addr_street,
      addr_housenumber = excluded.addr_housenumber,
      bank_key = excluded.bank_key,
      tags = excluded.tags,
      imported_at = excluded.imported_at,
      atm_confirmed = excluded.atm_confirmed;

  get diagnostics v_affected = row_count;
  return v_affected;
end;
$function$;

alter function api.bsl_upsert_osm_atm_candidates(jsonb)
  owner to postgres;

revoke all on function api.bsl_upsert_osm_atm_candidates(jsonb)
  from public, anon, authenticated;
grant execute on function api.bsl_upsert_osm_atm_candidates(jsonb)
  to service_role;

create or replace function api.bsl_match_osm_atms()
returns integer
language sql
volatile
security invoker
set search_path = ''
as $function$
  select public.bsl_match_osm_atms();
$function$;

revoke all on function api.bsl_match_osm_atms()
  from public, anon, authenticated;
grant execute on function api.bsl_match_osm_atms()
  to service_role;

comment on function api.bsl_upsert_osm_atm_candidates(jsonb) is
  'Service-only bounded batch upsert used by the OSM ATM Edge Function.';
comment on function api.bsl_match_osm_atms() is
  'Service-only API wrapper for the internal OSM-to-official ATM matcher.';

notify pgrst, 'reload schema';

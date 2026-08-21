-- Harden the ATM Data API without changing its REST path or response shape.
-- Only the dedicated api schema is exposed through PostgREST. The raw tables,
-- PostGIS objects and privileged implementation remain outside the Data API.

create schema if not exists api;
create schema if not exists private;

revoke all on schema api from public;
revoke all on schema private from public;
revoke create on schema public from public, anon, authenticated;
grant usage on schema api to anon, authenticated, service_role;
grant usage on schema private to anon, authenticated, service_role;

create or replace function private.bsl_nearby_atms_map_internal(
  p_lat double precision,
  p_lon double precision,
  p_radius_m integer
)
returns table(
  location_id text,
  bank_id text,
  bank_brand text,
  name text,
  address text,
  city text,
  latitude double precision,
  longitude double precision,
  distance_m double precision,
  cash_deposit boolean,
  is_24h boolean,
  source text,
  verified boolean
)
language sql
stable
security definer
set search_path = ''
set statement_timeout = '5s'
as $function$
  with parameters as (
    select least(greatest(coalesce(p_radius_m, 10000), 100), 50000) as radius_m
  ),
  target as (
    select public.st_setsrid(
      public.st_makepoint(p_lon, p_lat),
      4326
    )::public.geography as g
  ),
  official as (
    select
      l.location_id,
      l.bank_id,
      b.brand_name as bank_brand,
      coalesce(nullif(l.name, ''), b.brand_name || ' bankomat') as name,
      l.address,
      l.city,
      l.latitude,
      l.longitude,
      public.st_distance(l.geom, t.g) as distance_m,
      coalesce(bool_or(d.cash_deposit), false) as cash_deposit,
      coalesce(bool_or(d.is_24h), false) as is_24h,
      coalesce(l.geo_source, 'BSL official') as source,
      (
        l.geocode_status in (
          'manual_verified',
          'official_coordinates',
          'matched_osm'
        )
      ) as verified
    from public.bsl_atm_locations l
    join public.bsl_banks b
      on b.bank_id = l.bank_id
     and b.active
    cross join target t
    cross join parameters p
    left join public.bsl_atm_devices d
      on d.location_id = l.location_id
     and d.record_status = 'active'
    where l.geom is not null
      and l.record_status = 'active'
      and public.st_dwithin(l.geom, t.g, p.radius_m)
    group by
      l.location_id,
      l.bank_id,
      b.brand_name,
      l.name,
      l.address,
      l.city,
      l.latitude,
      l.longitude,
      l.geom,
      t.g,
      l.geo_source,
      l.geocode_status
  ),
  osm_candidates as (
    select
      c.*,
      public.st_distance(c.geom, t.g) as distance_m
    from public.bsl_osm_atm_candidates c
    cross join target t
    cross join parameters p
    where c.matched_location_id is null
      and c.atm_confirmed = true
      and public.st_dwithin(c.geom, t.g, p.radius_m)
      and not exists (
        select 1
        from official o
        where c.bank_key is not null
          and o.bank_id = c.bank_key
          and public.st_dwithin(
            c.geom,
            public.st_setsrid(
              public.st_makepoint(o.longitude, o.latitude),
              4326
            )::public.geography,
            80
          )
      )
      and not exists (
        select 1
        from public.bsl_osm_atm_candidates c2
        where c.bank_key is not null
          and c2.matched_location_id is null
          and c2.atm_confirmed = true
          and c2.bank_key = c.bank_key
          and (c2.osm_type, c2.osm_id) < (c.osm_type, c.osm_id)
          and public.st_dwithin(c.geom, c2.geom, 50)
      )
  ),
  osm_unmatched as (
    select
      'osm:' || c.osm_type || ':' || c.osm_id::text as location_id,
      coalesce(c.bank_key, 'osm_other') as bank_id,
      public.bsl_osm_bank_brand(c.bank_key) as bank_brand,
      coalesce(
        nullif(c.name, ''),
        public.bsl_osm_bank_brand(c.bank_key) || ' bankomat'
      ) as name,
      trim(
        concat_ws(
          ' ',
          nullif(c.addr_street, ''),
          nullif(c.addr_housenumber, ''),
          nullif(c.addr_place, '')
        )
      ) as address,
      coalesce(
        nullif(c.addr_city, ''),
        nullif(c.addr_place, ''),
        ''
      ) as city,
      c.latitude,
      c.longitude,
      c.distance_m,
      lower(
        coalesce(
          c.tags ->> 'cash_in',
          c.tags ->> 'cash_deposit',
          c.tags ->> 'deposit',
          ''
        )
      ) in ('yes', 'true', '1') as cash_deposit,
      replace(
        lower(coalesce(c.tags ->> 'opening_hours', '')),
        ' ',
        ''
      ) in ('24/7', '24-7') as is_24h,
      'OpenStreetMap'::text as source,
      false as verified
    from osm_candidates c
  ),
  combined as (
    select * from official
    union all
    select * from osm_unmatched
  )
  select *
  from combined
  order by distance_m
  limit 500;
$function$;

alter function private.bsl_nearby_atms_map_internal(
  double precision,
  double precision,
  integer
) owner to postgres;

revoke all on function private.bsl_nearby_atms_map_internal(
  double precision,
  double precision,
  integer
) from public;

grant execute on function private.bsl_nearby_atms_map_internal(
  double precision,
  double precision,
  integer
) to anon, authenticated, service_role;

create or replace function api.bsl_nearby_atms_map(
  p_lat double precision,
  p_lon double precision,
  p_radius_m integer default 10000
)
returns table(
  location_id text,
  bank_id text,
  bank_brand text,
  name text,
  address text,
  city text,
  latitude double precision,
  longitude double precision,
  distance_m double precision,
  cash_deposit boolean,
  is_24h boolean,
  source text,
  verified boolean
)
language plpgsql
stable
security invoker
set search_path = ''
as $function$
begin
  if p_lat is null
     or p_lat::text in ('NaN', 'Infinity', '-Infinity')
     or p_lat < -90
     or p_lat > 90 then
    raise exception using
      errcode = '22023',
      message = 'p_lat must be a finite number between -90 and 90';
  end if;

  if p_lon is null
     or p_lon::text in ('NaN', 'Infinity', '-Infinity')
     or p_lon < -180
     or p_lon > 180 then
    raise exception using
      errcode = '22023',
      message = 'p_lon must be a finite number between -180 and 180';
  end if;

  if p_radius_m is null or p_radius_m < 100 or p_radius_m > 50000 then
    raise exception using
      errcode = '22023',
      message = 'p_radius_m must be between 100 and 50000';
  end if;

  return query
  select *
  from private.bsl_nearby_atms_map_internal(
    p_lat,
    p_lon,
    p_radius_m
  );
end;
$function$;

revoke all on function api.bsl_nearby_atms_map(
  double precision,
  double precision,
  integer
) from public;

grant execute on function api.bsl_nearby_atms_map(
  double precision,
  double precision,
  integer
) to anon, authenticated, service_role;

-- Keep the former public routine as a service-only compatibility wrapper.
-- It is not reachable through PostgREST after the api schema becomes the sole
-- exposed schema.
create or replace function public.bsl_nearby_atms_map(
  p_lat double precision,
  p_lon double precision,
  p_radius_m integer default 10000
)
returns table(
  location_id text,
  bank_id text,
  bank_brand text,
  name text,
  address text,
  city text,
  latitude double precision,
  longitude double precision,
  distance_m double precision,
  cash_deposit boolean,
  is_24h boolean,
  source text,
  verified boolean
)
language sql
stable
security invoker
set search_path = ''
as $function$
  select *
  from api.bsl_nearby_atms_map(
    p_lat,
    p_lon,
    p_radius_m
  );
$function$;

revoke all on function public.bsl_nearby_atms_map(
  double precision,
  double precision,
  integer
) from public, anon, authenticated;

grant execute on function public.bsl_nearby_atms_map(
  double precision,
  double precision,
  integer
) to service_role;

revoke all on table
  public.bsl_banks,
  public.bsl_atm_locations,
  public.bsl_atm_devices,
  public.bsl_atm_sources,
  public.bsl_osm_atm_candidates
from anon, authenticated;

revoke execute on function public.bsl_norm_text(text)
  from public, anon, authenticated;
revoke execute on function public.bsl_osm_bank_brand(text)
  from public, anon, authenticated;
revoke execute on function public.bsl_refresh_atm_geom()
  from public, anon, authenticated;
revoke execute on function public.bsl_touch_updated_at()
  from public, anon, authenticated;

grant execute on function public.bsl_norm_text(text)
  to service_role;
grant execute on function public.bsl_osm_bank_brand(text)
  to service_role;
grant execute on function public.bsl_refresh_atm_geom()
  to service_role;
grant execute on function public.bsl_touch_updated_at()
  to service_role;

alter function public.bsl_match_osm_atms()
  set search_path = '';

alter default privileges for role postgres in schema public
  revoke all on tables from anon, authenticated, service_role;
alter default privileges for role postgres in schema public
  revoke all on sequences from anon, authenticated, service_role;
alter default privileges for role postgres in schema public
  revoke execute on functions from anon, authenticated, service_role;
alter default privileges for role postgres in schema public
  revoke execute on functions from public;

alter default privileges for role postgres in schema api
  revoke all on tables from public, anon, authenticated, service_role;
alter default privileges for role postgres in schema api
  revoke all on sequences from public, anon, authenticated, service_role;
alter default privileges for role postgres in schema api
  revoke execute on functions from public, anon, authenticated, service_role;

alter default privileges for role postgres in schema private
  revoke all on tables from public, anon, authenticated, service_role;
alter default privileges for role postgres in schema private
  revoke all on sequences from public, anon, authenticated, service_role;
alter default privileges for role postgres in schema private
  revoke execute on functions from public, anon, authenticated, service_role;

comment on function api.bsl_nearby_atms_map(
  double precision,
  double precision,
  integer
) is
  'Sole public Data API routine for BSL ATM lookup. Validates coordinates, limits radius to 50 km and caps results at 500.';

comment on function public.bsl_nearby_atms_map(
  double precision,
  double precision,
  integer
) is
  'Service-only compatibility wrapper. The public schema is not exposed through PostgREST.';

comment on function private.bsl_nearby_atms_map_internal(
  double precision,
  double precision,
  integer
) is
  'Non-exposed privileged implementation for the BSL ATM Data API wrapper.';

-- Supabase's PostGIS extension owns public.spatial_ref_sys, so the project
-- role cannot enable RLS or alter its platform-managed grants. Removing the
-- entire public schema from PostgREST is the supported boundary and also
-- prevents exposure of all PostGIS tables and routines.
alter role authenticator set pgrst.db_schemas = 'api';

notify pgrst, 'reload config';
notify pgrst, 'reload schema';

-- Emergency rollback for 20260901084929_secure_bsl_atm_sync_scheduler.
-- This removes only BSL-owned jobs and objects; pg_cron itself is preserved.

select cron.unschedule(jobid)
from cron.job
where jobname in (
  'bsl-atm-osm-sector-0',
  'bsl-atm-osm-sector-1',
  'bsl-atm-osm-sector-2',
  'bsl-atm-osm-sector-3'
);

drop function if exists api.bsl_atm_sync_health();
drop function if exists private.bsl_atm_sync_health_internal();
drop function if exists api.bsl_finalize_osm_atm_sector(
  integer,
  timestamp with time zone,
  jsonb
);
drop function if exists api.bsl_verify_atm_sync_secret(text);
drop table if exists private.bsl_atm_sync_state;
drop index if exists public.idx_bsl_atm_sources_bank_id;

delete from vault.secrets
where name = 'bsl_atm_sync_secret';

create or replace function public.bsl_match_osm_atms()
returns integer
language plpgsql
volatile
security definer
set search_path = ''
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

notify pgrst, 'reload schema';

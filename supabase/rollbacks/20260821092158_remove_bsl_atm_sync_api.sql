-- Roll back production migration 20260821092158.
-- Removes the service-only OSM sync RPCs.

drop function if exists api.bsl_match_osm_atms();
drop function if exists api.bsl_upsert_osm_atm_candidates(jsonb);

notify pgrst, 'reload schema';

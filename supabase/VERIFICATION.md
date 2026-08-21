# Production verification — 2026-08-21

Project: `bsl_backend` (`jkzjktrnqtkpdiiugfar`)  
Migration: `20260821091042_harden_bsl_atm_public_api`  
Verified at: `2026-08-21 09:13:15 UTC`

## Backup and rollback rehearsal

- The pre-migration schema, deployed Edge Function sources, and all ATM rows
  were captured under `snapshots/2026-08-21/` and `functions/`.
- The full migration and security test suite first ran inside a transaction
  that was rolled back.
- After rollback, neither `api` nor `private` existed, the original RPC was
  unchanged, and all source row counts matched the backup.

## Post-migration assertions

| Check | Result |
| --- | --- |
| PostgREST exposed schemas | `api` only |
| Tables in exposed `api` schema | `0` |
| Exposed routines | `api.bsl_nearby_atms_map(...)` only |
| API wrapper mode | `SECURITY INVOKER` |
| Private helper | `SECURITY DEFINER`, empty `search_path`, 5 s timeout |
| Raw ATM table access for `anon` | denied on all five tables |
| Public compatibility RPC for `anon` / `authenticated` | denied |
| Sarajevo query result | 172 rows, bounded below 500 |
| Radius above 50 km | rejected with SQLSTATE `22023` / HTTP 400 |

## Row-count reconciliation

| Table | Before | After |
| --- | ---: | ---: |
| `bsl_banks` | 22 | 22 |
| `bsl_atm_locations` | 362 | 362 |
| `bsl_atm_devices` | 371 | 371 |
| `bsl_atm_sources` | 24 | 24 |
| `bsl_osm_atm_candidates` | 1,433 | 1,433 |
| **Total** | **2,212** | **2,212** |

## Live REST checks

The checks were issued through `pg_net` against the production REST URL with
the same publishable key used by Flutter.

| Request | HTTP | Result |
| --- | ---: | --- |
| Valid RPC without profile header (legacy client behavior) | 200 | 172 rows |
| Valid RPC with `Content-Profile: api` | 200 | 172 rows |
| `Accept-Profile: public` against `spatial_ref_sys` | 406 | `PGRST106`, only `api` is exposed |
| RPC radius `50001` m | 400 | input rejected |

## Advisor notes

The Supabase advisor continues to report platform-owned PostGIS objects in
`public` (`spatial_ref_sys`, `postgis`, and `st_estimatedextent`). The project
role cannot alter those objects because they are owned by `supabase_admin`.
The live REST test above is the authoritative exposure check: requesting
`public` is rejected before object privileges are evaluated.

The five RLS-without-policy notices are informational and intentional: the
raw ATM tables are inaccessible to client roles and the entire `public`
schema is outside PostgREST.

References:

- https://supabase.com/docs/guides/api/securing-your-api
- https://supabase.com/docs/guides/api/using-custom-schemas
- https://supabase.com/docs/guides/troubleshooting/postgrest-not-recognizing-objects-in-schema
- https://supabase.com/docs/guides/database/database-advisors

# Production verification — 2026-09-01

Project: `bsl_backend` (`jkzjktrnqtkpdiiugfar`)
Project status: `ACTIVE_HEALTHY`
Postgres: `17.6.1.155` (`eu-central-1`)

Migrations:

- `20260901084929_secure_bsl_atm_sync_scheduler`
- `20260901130623_route_bsl_atm_source_through_pg_net`

## ATM sync recovery

Direct Overpass requests from the Edge runtime timed out or returned HTTP 502,
including minimal probe queries. The same global source was reachable through
the separate `pg_net` egress path. The production scheduler now uses a
two-stage route:

1. Four staggered jobs enqueue read-only, bounded Overpass requests.
2. A private dispatcher validates response size, shape, row count, and OSM
   snapshot freshness.
3. Only a validated payload is sent with the Vault credential to Edge Function
   `sync-bsl-atm-osm` version 12 for normalization, upsert, reconciliation, and
   matching.

The private queue and dispatcher functions are executable only by their
`postgres` owner. `anon`, `authenticated`, and `service_role` cannot invoke
them. Source and ingest stages retry at most twice after the initial attempt.

## Initial four-sector run

| Sector | Candidates | Source attempts | Ingest attempts | Deactivated | Completed (UTC) |
| ---: | ---: | ---: | ---: | ---: | --- |
| 0 | 455 | 1 | 1 | 0 | 2026-09-01 13:08:04 |
| 1 | 536 | 1 | 1 | 0 | 2026-09-01 13:09:36 |
| 2 | 934 | 2 | 1 | 0 | 2026-09-01 13:11:39 |
| 3 | 897 | 2 | 1 | 0 | 2026-09-01 13:14:10 |

The automatic retry recovered transient source failures for sectors 2 and 3.
All four final states have `last_error = null`.

## Production assertions

| Check | Result |
| --- | --- |
| `api.bsl_atm_sync_health()` | `healthy=true` |
| Oldest sector sync | `2026-09-01 13:08:04 UTC` |
| Total OSM candidates | 2,822 |
| Confirmed ATM candidates | 2,333 |
| Bank-branch candidates | 1,026 |
| Matched official locations | 41 |
| Invalid coordinates | 0 |
| Pending official locations | 317 |
| Active ATM cron jobs | 5 (4 source + 1 dispatcher) |
| Full SQL security suite | passed |
| Edge request without sync secret | HTTP 401, `Unauthorized` |
| Edge Function | version 12, active, handler-enforced Vault auth |

## Advisor notes

No advisor finding was introduced by either ATM migration. The remaining
security findings are extension-owned PostGIS objects in `public`
(`spatial_ref_sys`, `postgis`, and three `st_estimatedextent` overloads).
Attempting the owner-only RLS change as the project `postgres` role correctly
failed because these objects are owned by `supabase_admin`. PostgREST remains
configured to expose only `api`, so `public` is outside the Data API.

The RLS-without-policy INFO notices are intentional deny-by-default controls on
private/raw tables. The unused-index INFO notices are not actionable immediately
after deployment; the indexes support known joins or foreign keys and need
representative statistics before removal is considered.

---

# Historical verification — 2026-08-21

Project: `bsl_backend` (`jkzjktrnqtkpdiiugfar`)  
Migrations:

- `20260821091042_harden_bsl_atm_public_api`
- `20260821092158_add_bsl_atm_sync_api`

Verified at: `2026-08-21 09:24:18 UTC`

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
| API routines | 1 client RPC and 2 service-only OSM sync RPCs |
| API wrapper mode | `SECURITY INVOKER` |
| Private helper | `SECURITY DEFINER`, empty `search_path`, 5 s timeout |
| Raw ATM table access for `anon` | denied on all five tables |
| Public compatibility RPC for `anon` / `authenticated` | denied |
| OSM sync RPCs for `anon` / `authenticated` | denied |
| OSM sync RPCs for `service_role` | allowed |
| Sarajevo query result | 172 rows, bounded below 500 |
| Radius above 50 km | rejected with SQLSTATE `22023` / HTTP 400 |
| Edge Function `sync-bsl-atm-osm` | version 6, active, JWT required |
| Transactional service upsert test | 1 existing row, rolled back |
| Transactional matcher test | 40 matches, rolled back |

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
| Anonymous call to service-only upsert RPC | 401 | `42501`, permission denied |
| Edge Function request with invalid sector | 400 | function version 6 executed and validated input |

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

# BSL Supabase backend

Supabase project: `bsl_backend`  
Project reference: `jkzjktrnqtkpdiiugfar`

## Repository layout

- `migrations/` — reviewed database changes in application order.
- `rollbacks/` — explicit emergency compatibility rollbacks.
- `tests/` — database security and behavior assertions.
- `functions/` — source snapshots of deployed Edge Functions.
- `snapshots/` — dated schema and public ATM data recovery points.

## Security model

- Raw ATM tables have RLS enabled and are not granted to `anon` or
  `authenticated`.
- PostgREST exposes only the dedicated `api` schema; `public`, PostGIS,
  raw tables, and helper routines are outside the Data API.
- Flutter calls only
  `api.bsl_nearby_atms_map(double precision,double precision,integer)`.
- The API function is a validating `SECURITY INVOKER` wrapper.
- Privileged reads are performed by a non-exposed helper in the `private`
  schema.
- Public requests are limited to valid coordinates, a 100 m–50 km radius,
  five seconds of database execution, and 500 returned rows.
- The former `public.bsl_nearby_atms_map` routine remains as a service-role
  compatibility wrapper and is not callable by client roles.

The migration intentionally sets `pgrst.db_schemas=api` on the
`authenticator` role. This is a manual Data API schema override; future
changes to exposed schemas must be made in a reviewed migration (or the role
setting must first be reset so Dashboard management becomes authoritative
again).

## Emergency rollback

If clients cannot reach the dedicated `api` schema, apply
`rollbacks/20260821091042_restore_public_data_api.sql`. It temporarily
exposes both `public` and `api`, restoring compatibility for old and new
clients while keeping the bounded wrapper. This is a security downgrade and
should be used only for incident recovery.

The Supabase publishable key is intentionally present in the Flutter client
and smoke workflow. It is not a secret. Never commit the service-role key,
secret key, database password, or Edge Function secrets.

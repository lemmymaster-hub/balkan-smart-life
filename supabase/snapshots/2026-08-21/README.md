# bsl_backend snapshot — 2026-08-21

This snapshot was captured before the ATM API security hardening.

It contains:

- the current application schema, functions, triggers, indexes, RLS state,
  and grants in `schema.sql`;
- all application ATM rows in `data/*.json`;
- a manifest with expected table counts;
- the pre-hardening deployed Edge Function sources in `functions/`;
- a restore script that recreates derived PostGIS geography columns from
  latitude and longitude.

The snapshot intentionally excludes Supabase-managed schemas, API keys,
database passwords, function secrets, and the PostGIS-managed
`spatial_ref_sys` rows.

## Restore into an empty Supabase project

1. Apply `schema.sql` to an empty test project.
2. Set `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` in your shell.
3. Run:

   ```bash
   deno run --allow-env --allow-net --allow-read restore_data.ts
   ```

4. Verify the row counts against `data/manifest.json`.
5. Apply later migrations in timestamp order.

Do not run `schema.sql` against the existing production project because it
contains `CREATE TABLE` statements.

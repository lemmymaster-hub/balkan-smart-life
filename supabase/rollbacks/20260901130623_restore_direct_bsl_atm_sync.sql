-- Emergency rollback for 20260901130623_route_bsl_atm_source_through_pg_net.
-- This restores the previous direct Edge fetch path, which may remain unable
-- to reach public Overpass servers from some Edge regions.

do $unschedule_routed_atm_jobs$
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
$unschedule_routed_atm_jobs$;

drop function if exists private.bsl_dispatch_pending_atm_sectors();
drop function if exists private.bsl_queue_atm_sector(integer, boolean);

alter table private.bsl_atm_sync_state
  drop column if exists source_request_id,
  drop column if exists source_requested_at,
  drop column if exists source_completed_at,
  drop column if exists source_attempt_count,
  drop column if exists ingest_request_id,
  drop column if exists ingest_completed_at,
  drop column if exists ingest_attempt_count,
  drop column if exists last_error;

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
          limit 1
        )
      ),
      body := '{"sector":0}'::jsonb,
      timeout_milliseconds := 90000
    );
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
          limit 1
        )
      ),
      body := '{"sector":1}'::jsonb,
      timeout_milliseconds := 90000
    );
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
          limit 1
        )
      ),
      body := '{"sector":2}'::jsonb,
      timeout_milliseconds := 90000
    );
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
          limit 1
        )
      ),
      body := '{"sector":3}'::jsonb,
      timeout_milliseconds := 90000
    );
  $cron$
);

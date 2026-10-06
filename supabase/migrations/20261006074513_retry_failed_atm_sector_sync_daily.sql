-- Retry only failed and stale ATM sectors once daily rather than waiting
-- until the next twice-weekly full refresh. Keep existing retry limits and
-- API safety validation unchanged.
select cron.schedule(
  'bsl-atm-osm-recover-failed-sectors',
  '17 4 * * *',
  $cron$
    select private.bsl_queue_atm_sector(sector)
    from private.bsl_atm_sync_state
    where last_error is not null
      and source_completed_at is not null
      and (ingest_request_id is null or ingest_completed_at is not null)
      and (last_succeeded_at is null or last_succeeded_at < now() - interval '2 days')
      and (source_requested_at is null or source_requested_at < now() - interval '2 hours')
    order by sector;
  $cron$
);

-- Process only the queued requests; the dispatcher already validates OSM
-- payloads and requires the private Edge Function synchronization secret.
select cron.schedule(
  'bsl-atm-osm-recover-dispatch',
  '*/5 4-5 * * *',
  'select private.bsl_dispatch_pending_atm_sectors();'
);
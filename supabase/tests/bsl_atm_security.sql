-- Run after the hardening migration. All assertions raise on failure.

do $test$
declare
  v_api_is_definer boolean;
  v_public_is_definer boolean;
  v_private_is_definer boolean;
  v_result_count integer;
  v_exposed_schemas text;
  v_cron_jobs integer;
begin
  select split_part(setting, '=', 2)
  into v_exposed_schemas
  from pg_roles r
  cross join lateral unnest(r.rolconfig) as setting
  where r.rolname = 'authenticator'
    and setting like 'pgrst.db_schemas=%';

  if replace(coalesce(v_exposed_schemas, ''), ' ', '') <> 'api' then
    raise exception 'PostgREST must expose only the api schema, got %',
      coalesce(v_exposed_schemas, '<unset>');
  end if;

  select p.prosecdef
  into v_api_is_definer
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'api'
    and p.oid = 'api.bsl_nearby_atms_map(double precision,double precision,integer)'::regprocedure;

  if v_api_is_definer is distinct from false then
    raise exception 'API ATM wrapper must be SECURITY INVOKER';
  end if;

  select p.prosecdef
  into v_public_is_definer
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.oid = 'public.bsl_nearby_atms_map(double precision,double precision,integer)'::regprocedure;

  if v_public_is_definer is distinct from false then
    raise exception 'Service compatibility wrapper must be SECURITY INVOKER';
  end if;

  select p.prosecdef
  into v_private_is_definer
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'private'
    and p.oid = 'private.bsl_nearby_atms_map_internal(double precision,double precision,integer)'::regprocedure;

  if v_private_is_definer is distinct from true then
    raise exception 'Private ATM implementation must be SECURITY DEFINER';
  end if;

  if not has_function_privilege(
    'anon',
    'api.bsl_nearby_atms_map(double precision,double precision,integer)',
    'EXECUTE'
  ) then
    raise exception 'anon must be able to execute the API ATM wrapper';
  end if;

  if has_function_privilege(
    'anon',
    'public.bsl_nearby_atms_map(double precision,double precision,integer)',
    'EXECUTE'
  ) then
    raise exception 'anon must not execute the compatibility wrapper in public';
  end if;

  if not has_schema_privilege('anon', 'api', 'USAGE') then
    raise exception 'anon needs USAGE on the api schema';
  end if;

  if has_function_privilege(
    'anon',
    'api.bsl_upsert_osm_atm_candidates(jsonb)',
    'EXECUTE'
  ) or has_function_privilege(
    'authenticated',
    'api.bsl_upsert_osm_atm_candidates(jsonb)',
    'EXECUTE'
  ) or has_function_privilege(
    'anon',
    'api.bsl_match_osm_atms()',
    'EXECUTE'
  ) or has_function_privilege(
    'authenticated',
    'api.bsl_match_osm_atms()',
    'EXECUTE'
  ) then
    raise exception 'Client roles must not execute OSM sync routines';
  end if;

  if not has_function_privilege(
    'service_role',
    'api.bsl_upsert_osm_atm_candidates(jsonb)',
    'EXECUTE'
  ) or not has_function_privilege(
    'service_role',
    'api.bsl_match_osm_atms()',
    'EXECUTE'
  ) then
    raise exception 'service_role needs the OSM sync routines';
  end if;

  if has_function_privilege(
    'anon',
    'api.bsl_verify_atm_sync_secret(text)',
    'EXECUTE'
  ) or has_function_privilege(
    'authenticated',
    'api.bsl_verify_atm_sync_secret(text)',
    'EXECUTE'
  ) or has_function_privilege(
    'anon',
    'api.bsl_finalize_osm_atm_sector(integer,timestamp with time zone,jsonb)',
    'EXECUTE'
  ) or has_function_privilege(
    'authenticated',
    'api.bsl_finalize_osm_atm_sector(integer,timestamp with time zone,jsonb)',
    'EXECUTE'
  ) then
    raise exception 'Client roles must not execute scheduled sync controls';
  end if;

  if not has_function_privilege(
    'service_role',
    'api.bsl_verify_atm_sync_secret(text)',
    'EXECUTE'
  ) or not has_function_privilege(
    'service_role',
    'api.bsl_finalize_osm_atm_sector(integer,timestamp with time zone,jsonb)',
    'EXECUTE'
  ) then
    raise exception 'service_role needs scheduled sync controls';
  end if;

  if has_function_privilege(
    'anon',
    'private.bsl_queue_atm_sector(integer,boolean)',
    'EXECUTE'
  ) or has_function_privilege(
    'authenticated',
    'private.bsl_queue_atm_sector(integer,boolean)',
    'EXECUTE'
  ) or has_function_privilege(
    'service_role',
    'private.bsl_queue_atm_sector(integer,boolean)',
    'EXECUTE'
  ) or has_function_privilege(
    'anon',
    'private.bsl_dispatch_pending_atm_sectors()',
    'EXECUTE'
  ) or has_function_privilege(
    'authenticated',
    'private.bsl_dispatch_pending_atm_sectors()',
    'EXECUTE'
  ) or has_function_privilege(
    'service_role',
    'private.bsl_dispatch_pending_atm_sectors()',
    'EXECUTE'
  ) then
    raise exception 'Only the postgres-owned scheduler may queue or dispatch source data';
  end if;

  if not has_function_privilege(
    'anon',
    'api.bsl_atm_sync_health()',
    'EXECUTE'
  ) then
    raise exception 'anon must be able to read bounded ATM sync health';
  end if;

  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'api'
  ) then
    raise exception 'The exposed api schema must not contain tables';
  end if;

  if has_table_privilege('anon', 'public.bsl_banks', 'SELECT')
     or has_table_privilege('anon', 'public.bsl_atm_locations', 'SELECT')
     or has_table_privilege('anon', 'public.bsl_atm_devices', 'SELECT')
     or has_table_privilege('anon', 'public.bsl_atm_sources', 'SELECT')
     or has_table_privilege('anon', 'public.bsl_osm_atm_candidates', 'SELECT') then
    raise exception 'anon must not have direct access to raw ATM tables';
  end if;

  if has_table_privilege(
    'anon',
    'private.bsl_atm_sync_state',
    'SELECT'
  ) then
    raise exception 'anon must not read private ATM sync state';
  end if;

  select count(*)
  into v_cron_jobs
  from cron.job
  where active
    and jobname in (
      'bsl-atm-osm-sector-0',
      'bsl-atm-osm-sector-1',
      'bsl-atm-osm-sector-2',
      'bsl-atm-osm-sector-3',
      'bsl-atm-osm-dispatch'
    );

  if v_cron_jobs <> 5 then
    raise exception 'Expected five active ATM sync jobs, got %', v_cron_jobs;
  end if;

  if exists (
    select 1
    from cron.job
    where jobname like 'bsl-atm-osm-%'
      and (
        command ilike '%decrypted_secret%'
        or command ilike '%http_post%'
      )
  ) then
    raise exception 'ATM cron commands must invoke only private scheduler functions';
  end if;

  select count(*)
  into v_result_count
  from api.bsl_nearby_atms_map(
    43.8563,
    18.4131,
    10000
  );

  if v_result_count < 1 or v_result_count > 500 then
    raise exception 'Sarajevo ATM smoke query returned % rows', v_result_count;
  end if;

  begin
    perform *
    from api.bsl_nearby_atms_map(
      91,
      18.4131,
      10000
    );
    raise exception 'Invalid latitude was accepted';
  exception
    when sqlstate '22023' then
      null;
  end;

  begin
    perform *
    from api.bsl_nearby_atms_map(
      43.8563,
      18.4131,
      50001
    );
    raise exception 'Oversized radius was accepted';
  exception
    when sqlstate '22023' then
      null;
  end;
end;
$test$;

-- Exercise the complete privilege chain as the same database role used by a
-- request carrying only the publishable key.
begin;
set local role anon;

do $anon_test$
declare
  v_result_count integer;
  v_health_count integer;
begin
  select count(*)
  into v_result_count
  from api.bsl_nearby_atms_map(
    43.8563,
    18.4131,
    10000
  );

  if v_result_count < 1 or v_result_count > 500 then
    raise exception 'anon Sarajevo smoke query returned % rows',
      v_result_count;
  end if;

  select count(*)
  into v_health_count
  from api.bsl_atm_sync_health();

  if v_health_count <> 1 then
    raise exception 'ATM sync health must return exactly one row';
  end if;
end;
$anon_test$;

rollback;

-- The service role can reach the bounded sync API without mutating data.
begin;
set local role service_role;

do $service_test$
declare
  v_affected integer;
  v_authorized boolean;
begin
  select api.bsl_upsert_osm_atm_candidates('[]'::jsonb)
  into v_affected;

  if v_affected <> 0 then
    raise exception 'Empty service upsert affected % rows', v_affected;
  end if;

  select api.bsl_verify_atm_sync_secret('invalid')
  into v_authorized;

  if v_authorized then
    raise exception 'Invalid ATM sync secret was accepted';
  end if;
end;
$service_test$;

rollback;

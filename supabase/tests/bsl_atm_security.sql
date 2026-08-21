-- Run after the hardening migration. All assertions raise on failure.

do $test$
declare
  v_api_is_definer boolean;
  v_public_is_definer boolean;
  v_private_is_definer boolean;
  v_result_count integer;
  v_exposed_schemas text;
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
end;
$anon_test$;

rollback;

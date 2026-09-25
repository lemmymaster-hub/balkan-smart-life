-- Expose only the boolean health state required by external smoke tests.
-- Detailed sync metrics stay behind api.bsl_atm_sync_health() and service_role.

create or replace function api.bsl_atm_public_health()
returns table (healthy boolean)
language sql
security invoker
set search_path = ''
set statement_timeout = '3s'
as $$
  select h.healthy
  from private.bsl_atm_sync_health_internal() as h;
$$;

revoke all on function api.bsl_atm_public_health() from public;
grant execute on function api.bsl_atm_public_health()
to anon, authenticated, service_role;

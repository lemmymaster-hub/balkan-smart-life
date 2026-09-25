-- Detailed ATM sync telemetry is backend-only.
-- Public monitoring uses api.bsl_atm_public_health() instead.

revoke execute on function api.bsl_atm_sync_health()
from anon, authenticated;

grant execute on function api.bsl_atm_sync_health()
to service_role;

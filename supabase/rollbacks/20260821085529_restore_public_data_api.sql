-- Emergency compatibility rollback for the dedicated API schema migration.
-- This intentionally widens the exposed surface and should only be used to
-- restore service while the dedicated api schema issue is investigated.

grant execute on function public.bsl_nearby_atms_map(
  double precision,
  double precision,
  integer
) to anon, authenticated;

alter role authenticator set pgrst.db_schemas = 'public,api';

notify pgrst, 'reload config';
notify pgrst, 'reload schema';

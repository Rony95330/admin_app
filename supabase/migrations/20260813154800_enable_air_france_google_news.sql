update public.aviation_sources
set
  is_active = true,
  last_attempt_at = null,
  last_success_at = null,
  last_error = null
where id = 'air_france';

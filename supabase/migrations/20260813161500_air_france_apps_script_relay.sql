update public.aviation_sources
set
  feed_url = 'https://script.google.com/macros/s/AKfycbwShULwTAEJ0Zf94dAwb72jclWqJfugxMZFC9kZfriRUm67TSf6KtMwO_P7UGVpK8Xm2g/exec',
  is_active = true,
  last_attempt_at = null,
  last_success_at = null,
  last_error = null
where id = 'air_france';

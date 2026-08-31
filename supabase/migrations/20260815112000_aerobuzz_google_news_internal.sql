update public.aviation_sources
set
  feed_url = 'https://news.google.com/rss/search?q=site%3Aaerobuzz.fr&hl=fr&gl=FR&ceid=FR%3Afr',
  is_active = true,
  last_attempt_at = null,
  last_success_at = null,
  last_error = null
where id = 'aerobuzz';

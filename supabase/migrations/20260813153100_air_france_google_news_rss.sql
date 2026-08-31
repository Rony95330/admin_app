update public.aviation_sources
set
  feed_url = 'https://news.google.com/rss/search?q=site%3Acorporate.airfrance.com%2Ffr%2Factualites%20%22Air%20France%22&hl=fr&gl=FR&ceid=FR%3Afr',
  last_attempt_at = null,
  last_success_at = null,
  last_error = null
where id = 'air_france';

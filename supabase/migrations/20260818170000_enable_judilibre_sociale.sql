begin;

insert into public.labour_sources (
  id,
  name,
  channel_name,
  feed_url,
  source_kind,
  source_category,
  is_active,
  sort_order,
  default_topics,
  requires_filter,
  last_attempt_at,
  last_success_at,
  last_error
)
values (
  'cour_cassation_sociale',
  'Cour de cassation',
  'Chambre sociale',
  null,
  'judilibre',
  'official',
  true,
  40,
  array['caseLaw']::text[],
  false,
  null,
  null,
  null
)
on conflict (id) do update
set
  name = excluded.name,
  channel_name = excluded.channel_name,
  feed_url = null,
  source_kind = excluded.source_kind,
  source_category = excluded.source_category,
  is_active = true,
  sort_order = excluded.sort_order,
  default_topics = excluded.default_topics,
  requires_filter = excluded.requires_filter,
  last_attempt_at = null,
  last_success_at = null,
  last_error = null;

commit;

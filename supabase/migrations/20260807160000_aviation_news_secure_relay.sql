begin;

create table if not exists public.aviation_sources (
  id text primary key,
  name text not null,
  feed_url text not null,
  is_active boolean not null default true,
  is_specialized_press boolean not null default false,
  sort_order integer not null default 100,
  last_attempt_at timestamptz,
  last_success_at timestamptz,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint aviation_sources_id_format
    check (id ~ '^[a-z0-9_]{2,50}$'),
  constraint aviation_sources_name_length
    check (char_length(name) between 2 and 160),
  constraint aviation_sources_https_feed
    check (feed_url ~ '^https://[^[:space:]]+$'),
  constraint aviation_sources_error_length
    check (last_error is null or char_length(last_error) <= 500)
);

comment on table public.aviation_sources is
  'Sources RSS du Fil aérien. Lecture et écriture réservées au relais serveur.';

create table if not exists public.aviation_news (
  id text primary key,
  source_id text not null
    references public.aviation_sources(id)
    on update cascade
    on delete restrict,
  source_name text not null,
  title text not null,
  summary text not null default '',
  url text not null,
  image_url text,
  published_at timestamptz,
  topics text[] not null default array['operations']::text[],
  is_hidden boolean not null default false,
  is_pinned boolean not null default false,
  fetched_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint aviation_news_title_length
    check (char_length(title) between 1 and 300),
  constraint aviation_news_summary_length
    check (char_length(summary) <= 1500),
  constraint aviation_news_source_name_length
    check (char_length(source_name) between 2 and 160),
  constraint aviation_news_https_url
    check (url ~ '^https?://[^[:space:]]+$'),
  constraint aviation_news_https_image
    check (image_url is null or image_url ~ '^https?://[^[:space:]]+$'),
  constraint aviation_news_topics_allowed
    check (
      topics <@ array[
        'group',
        'specializedPress',
        'social',
        'operations',
        'safety',
        'environment'
      ]::text[]
      and cardinality(topics) > 0
    ),
  constraint aviation_news_source_url_unique unique (source_id, url)
);

comment on table public.aviation_news is
  'Cache serveur des articles du Fil aérien. Aucun accès direct depuis Flutter.';

create index if not exists aviation_news_visible_published_idx
  on public.aviation_news (is_hidden, is_pinned desc, published_at desc);

create index if not exists aviation_news_source_idx
  on public.aviation_news (source_id, published_at desc);

create index if not exists aviation_news_fetched_at_idx
  on public.aviation_news (fetched_at);

create or replace function public.set_aviation_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists aviation_sources_set_updated_at
  on public.aviation_sources;
create trigger aviation_sources_set_updated_at
before update on public.aviation_sources
for each row execute function public.set_aviation_updated_at();

drop trigger if exists aviation_news_set_updated_at
  on public.aviation_news;
create trigger aviation_news_set_updated_at
before update on public.aviation_news
for each row execute function public.set_aviation_updated_at();

insert into public.aviation_sources (
  id,
  name,
  feed_url,
  is_active,
  is_specialized_press,
  sort_order
)
values
  (
    'air_france',
    'Air France Corporate',
    'https://corporate.airfrance.com/fr/actualites/rss.xml',
    true,
    false,
    10
  ),
  (
    'easa_news',
    'EASA Actualités',
    'https://www.easa.europa.eu/newsroom-and-events/news/feed.xml',
    true,
    false,
    20
  ),
  (
    'easa_press',
    'EASA Communiqués',
    'https://www.easa.europa.eu/newsroom-and-events/press-releases/feed.xml',
    true,
    false,
    30
  ),
  (
    'air_journal',
    'Air Journal',
    'https://www.air-journal.fr/feed',
    true,
    true,
    40
  ),
  (
    'aerobuzz',
    'Aerobuzz',
    'https://www.aerobuzz.fr/feed/',
    true,
    true,
    50
  ),
  (
    'journal_aviation',
    'Le Journal de l’Aviation',
    'https://www.journal-aviation.com/feed',
    true,
    true,
    60
  )
on conflict (id) do update
set
  name = excluded.name,
  feed_url = excluded.feed_url,
  is_specialized_press = excluded.is_specialized_press,
  sort_order = excluded.sort_order;

alter table public.aviation_sources enable row level security;
alter table public.aviation_news enable row level security;

-- Aucun client ne lit directement les URL des sources ou le cache.
-- La fonction Edge utilise le rôle serveur, qui contourne la RLS.
revoke all on table public.aviation_sources from anon, authenticated;
revoke all on table public.aviation_news from anon, authenticated;
grant all on table public.aviation_sources to service_role;
grant all on table public.aviation_news to service_role;

revoke all on function public.set_aviation_updated_at()
  from public, anon, authenticated;

commit;

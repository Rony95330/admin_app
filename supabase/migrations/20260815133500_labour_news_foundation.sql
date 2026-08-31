begin;

create table if not exists public.labour_sources (
  id text primary key,
  name text not null,
  channel_name text,
  feed_url text,

  source_kind text not null default 'feed',
  source_category text not null default 'institutional',

  is_active boolean not null default true,
  sort_order integer not null default 100,

  default_topics text[] not null default array[]::text[],
  requires_filter boolean not null default false,

  last_attempt_at timestamptz,
  last_success_at timestamptz,
  last_error text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint labour_sources_id_format
    check (id ~ '^[a-z0-9_]{2,60}$'),

  constraint labour_sources_name_length
    check (char_length(name) between 2 and 160),

  constraint labour_sources_channel_length
    check (
      channel_name is null
      or char_length(channel_name) between 2 and 160
    ),

  constraint labour_sources_https_feed
    check (
      feed_url is null
      or feed_url ~ '^https://[^[:space:]]+$'
    ),

  constraint labour_sources_kind_allowed
    check (
      source_kind in (
        'feed',
        'google_news',
        'judilibre'
      )
    ),

  constraint labour_sources_category_allowed
    check (
      source_category in (
        'official',
        'institutional',
        'specialized'
      )
    ),

  constraint labour_sources_default_topics_allowed
    check (
      default_topics <@ array[
        'contractTermination',
        'workingTime',
        'compensation',
        'leaveAbsence',
        'cseDialogue',
        'unionsStrike',
        'healthSafety',
        'qvct',
        'equalityDiscrimination',
        'trainingEmployment',
        'caseLaw',
        'lawsRegulation'
      ]::text[]
    ),

  constraint labour_sources_error_length
    check (
      last_error is null
      or char_length(last_error) <= 500
    )
);

comment on table public.labour_sources is
  'Sources du Fil juridique. Accès réservé au relais serveur.';


create table if not exists public.labour_news (
  id text primary key,

  source_id text not null
    references public.labour_sources(id)
    on update cascade
    on delete restrict,

  source_name text not null,
  channel_name text,

  title text not null,
  summary text not null default '',

  url text not null,
  image_url text,

  published_at timestamptz,

  topics text[] not null default array[]::text[],

  is_hidden boolean not null default false,
  is_pinned boolean not null default false,

  fetched_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint labour_news_title_length
    check (char_length(title) between 1 and 300),

  constraint labour_news_summary_length
    check (char_length(summary) <= 2000),

  constraint labour_news_source_name_length
    check (char_length(source_name) between 2 and 160),

  constraint labour_news_channel_length
    check (
      channel_name is null
      or char_length(channel_name) between 2 and 160
    ),

  constraint labour_news_http_url
    check (url ~ '^https?://[^[:space:]]+$'),

  constraint labour_news_http_image
    check (
      image_url is null
      or image_url ~ '^https?://[^[:space:]]+$'
    ),

  constraint labour_news_topics_allowed
    check (
      topics <@ array[
        'contractTermination',
        'workingTime',
        'compensation',
        'leaveAbsence',
        'cseDialogue',
        'unionsStrike',
        'healthSafety',
        'qvct',
        'equalityDiscrimination',
        'trainingEmployment',
        'caseLaw',
        'lawsRegulation'
      ]::text[]
    ),

  constraint labour_news_source_url_unique
    unique (source_id, url)
);

comment on table public.labour_news is
  'Cache serveur du Fil juridique. Aucun accès direct depuis Flutter.';


create index if not exists labour_news_visible_published_idx
  on public.labour_news (
    is_hidden,
    is_pinned desc,
    published_at desc
  );

create index if not exists labour_news_source_idx
  on public.labour_news (
    source_id,
    published_at desc
  );

create index if not exists labour_news_fetched_at_idx
  on public.labour_news (fetched_at);

create index if not exists labour_news_topics_idx
  on public.labour_news
  using gin (topics);


create or replace function public.set_labour_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;


drop trigger if exists labour_sources_set_updated_at
  on public.labour_sources;

create trigger labour_sources_set_updated_at
before update on public.labour_sources
for each row
execute function public.set_labour_updated_at();


drop trigger if exists labour_news_set_updated_at
  on public.labour_news;

create trigger labour_news_set_updated_at
before update on public.labour_news
for each row
execute function public.set_labour_updated_at();


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
  requires_filter
)
values

(
  'tissot_droit_travail',
  'Éditions Tissot',
  'Droit du travail',
  'https://www.editions-tissot.fr/actualite/feeds/droit-du-travail/last_news.atom',
  'feed',
  'specialized',
  true,
  10,
  array[]::text[],
  false
),

(
  'service_public_pro',
  'Service-Public',
  'Entreprendre',
  'https://www.service-public.fr/abonnements/rss/actu-actu-pro.rss',
  'feed',
  'official',
  true,
  20,
  array[]::text[],
  true
),

(
  'ministere_travail',
  'Ministère du Travail',
  'Actualités',
  'https://news.google.com/rss/search?q=site%3Atravail-emploi.gouv.fr&hl=fr&gl=FR&ceid=FR%3Afr',
  'google_news',
  'official',
  true,
  30,
  array[]::text[],
  true
),

(
  'cour_cassation_sociale',
  'Cour de cassation',
  'Chambre sociale',
  null,
  'judilibre',
  'official',
  false,
  40,
  array['caseLaw']::text[],
  false
),

(
  'inrs_sst',
  'INRS',
  'Santé et sécurité au travail',
  'https://portaildocumentaire.inrs.fr/Portal/Recherche/Search.svc/SearchRss?key=024df2f03c2b0609b50b18424f9cf0ee&useSearchResultSize=true&useSearchSort=false',
  'feed',
  'institutional',
  true,
  50,
  array['healthSafety']::text[],
  false
),

(
  'anact_dialogue_social',
  'ANACT',
  'Dialogue social',
  'https://veille-travail.anact.fr/osiros/result/rss.php?queryosiros=Dialogue+social&fq=fulltext%3A%28Dialogue+social%29+AND+frbr%3A1&tmstp=2018-11-30T15%3A18%3A12Z&sort_define=date_crea_notice&sort_order=1',
  'feed',
  'institutional',
  true,
  60,
  array['cseDialogue']::text[],
  false
),

(
  'anact_cse',
  'ANACT',
  'CSE',
  'https://veille-travail.anact.fr/osiros/result/rss.php?queryosiros=CSE&sort_define=tri_annee&ct=drupal',
  'feed',
  'institutional',
  true,
  70,
  array['cseDialogue']::text[],
  false
),

(
  'anact_egalite',
  'ANACT',
  'Égalité professionnelle',
  'https://veille-travail.anact.fr/osiros/result/rss.php?queryosiros=%22%C3%A9galit%C3%A9+professionnelle%22&fq=fulltext%3A%28%22%C3%A9galit%C3%A9+professionnelle%22%29+AND+frbr%3A1&tmstp=2017-11-03T16%3A53%3A17Z&sort_define=date_crea_notice&sort_order=1',
  'feed',
  'institutional',
  true,
  80,
  array['equalityDiscrimination']::text[],
  false
),

(
  'anact_qvct',
  'ANACT',
  'QVCT',
  'https://veille-travail.anact.fr/osiros/result/rss.php?queryosiros=%22qualit%C3%A9+de+vie+au+travail%22&fq=fulltext%3A%28%22qualit%C3%A9+de+vie+au+travail%22%29+AND+frbr%3A1&tmstp=2017-11-03T16%3A49%3A35Z&sort_define=date_crea_notice&sort_order=1',
  'feed',
  'institutional',
  true,
  90,
  array['qvct']::text[],
  false
),

(
  'anact_sante',
  'ANACT',
  'Santé au travail',
  'https://veille-travail.anact.fr/osiros/result/rss.php?queryosiros=Sant%C3%A9&fq=fulltext%3A%28Sant%C3%A9%29+AND+frbr%3A1&tmstp=2017-11-03T16%3A50%3A47Z&sort_define=date_crea_notice&sort_order=1',
  'feed',
  'institutional',
  true,
  100,
  array['healthSafety']::text[],
  false
),

(
  'anact_teletravail',
  'ANACT',
  'Télétravail',
  'https://veille-travail.anact.fr/osiros/result/rss.php?queryosiros=t%C3%A9l%C3%A9travail&sort_define=date_crea_notice',
  'feed',
  'institutional',
  true,
  110,
  array['workingTime']::text[],
  false
)

on conflict (id) do update
set
  name = excluded.name,
  channel_name = excluded.channel_name,
  feed_url = excluded.feed_url,
  source_kind = excluded.source_kind,
  source_category = excluded.source_category,
  sort_order = excluded.sort_order,
  default_topics = excluded.default_topics,
  requires_filter = excluded.requires_filter;


alter table public.labour_sources enable row level security;
alter table public.labour_news enable row level security;

revoke all
on table public.labour_sources
from anon, authenticated;

revoke all
on table public.labour_news
from anon, authenticated;

grant all
on table public.labour_sources
to service_role;

grant all
on table public.labour_news
to service_role;

revoke all
on function public.set_labour_updated_at()
from public, anon, authenticated;

commit;

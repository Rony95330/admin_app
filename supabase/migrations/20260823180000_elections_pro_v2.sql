-- Élections Pro V2
-- Extension additive du module élections existant.
-- Ajoute : média de couverture géré par Storage, publications PDF/image/article,
-- position de la hero card sur l'accueil et copie complète des publications.

begin;

alter table public.election_campaigns
  add column if not exists hero_storage_path text,
  add column if not exists home_position integer not null default 1,
  add column if not exists home_card_cta text not null default 'Découvrir la campagne';

alter table public.election_campaigns
  drop constraint if exists election_campaigns_home_position_ck;

alter table public.election_campaigns
  add constraint election_campaigns_home_position_ck
  check (home_position in (1, 2));

create table if not exists public.election_publications (
  id uuid primary key default gen_random_uuid(),
  campaign_id uuid not null references public.election_campaigns(id) on delete cascade,
  publication_type text not null
    check (publication_type in ('pdf', 'image', 'article')),
  title text not null,
  summary text,
  body text,
  media_url text,
  media_storage_path text,
  cover_image_url text,
  cover_storage_path text,
  audience_tags text[] not null default array['ALL']::text[],
  is_active boolean not null default true,
  is_featured boolean not null default false,
  published_at timestamptz,
  sort_order integer not null default 100,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists election_publications_campaign_idx
  on public.election_publications (campaign_id, is_active, is_featured, sort_order);
create index if not exists election_publications_audience_gin
  on public.election_publications using gin (audience_tags);

drop trigger if exists trg_election_publications_updated on public.election_publications;
create trigger trg_election_publications_updated
before update on public.election_publications
for each row execute function public.set_election_updated_at();

alter table public.election_publications enable row level security;

drop policy if exists "elections publications read" on public.election_publications;
create policy "elections publications read"
on public.election_publications for select
to authenticated
using (
  public.can_view_election_campaign(campaign_id)
  or public.can_manage_election_campaign(campaign_id)
);

drop policy if exists "elections publications write" on public.election_publications;
create policy "elections publications write"
on public.election_publications for all
to authenticated
using (public.can_manage_election_campaign(campaign_id))
with check (public.can_manage_election_campaign(campaign_id));

-- Bucket public : les URLs sont générées automatiquement par l'Admin App.
insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'elections',
  'elections',
  true,
  26214400,
  array[
    'image/jpeg',
    'image/png',
    'image/webp',
    'application/pdf'
  ]::text[]
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- Chemin attendu : campaigns/<campaign_uuid>/<type>/<fichier>
drop policy if exists "elections storage admin insert" on storage.objects;
create policy "elections storage admin insert"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'elections'
  and name ~ '^campaigns/[0-9a-fA-F-]{36}/'
  and public.can_manage_election_campaign(split_part(name, '/', 2)::uuid)
);

drop policy if exists "elections storage admin update" on storage.objects;
create policy "elections storage admin update"
on storage.objects for update
to authenticated
using (
  bucket_id = 'elections'
  and name ~ '^campaigns/[0-9a-fA-F-]{36}/'
  and public.can_manage_election_campaign(split_part(name, '/', 2)::uuid)
)
with check (
  bucket_id = 'elections'
  and name ~ '^campaigns/[0-9a-fA-F-]{36}/'
  and public.can_manage_election_campaign(split_part(name, '/', 2)::uuid)
);

drop policy if exists "elections storage admin delete" on storage.objects;
create policy "elections storage admin delete"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'elections'
  and name ~ '^campaigns/[0-9a-fA-F-]{36}/'
  and public.can_manage_election_campaign(split_part(name, '/', 2)::uuid)
);

-- Bundle côté application : ajoute la clé publications.
create or replace function public.get_election_campaign_bundle(
  p_campaign_id uuid
)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  with ctx as (
    select * from public.get_my_election_context()
  ),
  selected_campaign as (
    select c.*
    from public.election_campaigns c
    cross join ctx
    where c.id = p_campaign_id
      and c.is_active = true
      and c.status = 'published'
      and (c.display_start_at is null or c.display_start_at <= now())
      and (c.display_end_at is null or c.display_end_at >= now())
      and (
        c.scope_level in ('GLOBAL','CSEC')
        or (
          c.scope_level = 'CSE'
          and ctx.cse_code is not null
          and upper(btrim(c.cse_code)) = upper(btrim(ctx.cse_code))
        )
      )
  ),
  selected_sections as (
    select s.*
    from public.election_sections s
    cross join ctx
    where s.campaign_id = p_campaign_id
      and s.is_active = true
      and (
        'ALL' = any(s.audience_tags)
        or ctx.audience = any(s.audience_tags)
      )
  )
  select jsonb_build_object(
    'campaign', (select to_jsonb(c) from selected_campaign c),
    'publications', coalesce((
      select jsonb_agg(to_jsonb(p) order by p.is_featured desc, p.sort_order, p.created_at desc)
      from public.election_publications p
      cross join ctx
      where p.campaign_id = p_campaign_id
        and p.is_active = true
        and (p.published_at is null or p.published_at <= now())
        and (
          'ALL' = any(p.audience_tags)
          or ctx.audience = any(p.audience_tags)
        )
    ), '[]'::jsonb),
    'sections', coalesce((
      select jsonb_agg(
        to_jsonb(s) ||
        jsonb_build_object(
          'items', coalesce((
            select jsonb_agg(to_jsonb(i) order by i.sort_order, i.created_at)
            from public.election_content_items i
            cross join ctx
            where i.section_id = s.id
              and i.is_active = true
              and (
                'ALL' = any(i.audience_tags)
                or ctx.audience = any(i.audience_tags)
              )
          ), '[]'::jsonb)
        )
        order by s.sort_order, s.created_at
      )
      from selected_sections s
    ), '[]'::jsonb),
    'candidates', coalesce((
      select jsonb_agg(to_jsonb(ca) order by ca.sort_order, ca.list_position, ca.last_name)
      from public.election_candidates ca
      cross join ctx
      where ca.campaign_id = p_campaign_id
        and ca.is_active = true
        and (
          'ALL' = any(ca.audience_tags)
          or ctx.audience = any(ca.audience_tags)
        )
    ), '[]'::jsonb)
  );
$$;

-- Duplication V2 : recopie aussi la couverture Storage et les publications.
create or replace function public.duplicate_election_campaign(
  p_campaign_id uuid,
  p_new_title text,
  p_new_slug text,
  p_new_year integer default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_source public.election_campaigns%rowtype;
  v_new_campaign_id uuid;
  v_source_section record;
  v_new_section_id uuid;
begin
  select * into v_source
  from public.election_campaigns
  where id = p_campaign_id;

  if not found then
    raise exception 'Campagne source introuvable';
  end if;

  if not public.can_manage_election_campaign(p_campaign_id) then
    raise exception 'Accès refusé';
  end if;

  if nullif(btrim(p_new_title), '') is null
     or nullif(btrim(p_new_slug), '') is null then
    raise exception 'Titre et slug obligatoires';
  end if;

  insert into public.election_campaigns (
    slug, title, subtitle, election_year, scope_level, cse_code,
    status, is_active, hero_image_url, hero_storage_path, intro_text,
    vote_start_at, vote_end_at, display_start_at, display_end_at,
    home_position, home_card_cta, sort_order, created_by
  )
  values (
    btrim(p_new_slug), btrim(p_new_title), v_source.subtitle, p_new_year,
    v_source.scope_level, v_source.cse_code, 'draft', false,
    v_source.hero_image_url, v_source.hero_storage_path, v_source.intro_text,
    v_source.vote_start_at, v_source.vote_end_at, null, null,
    v_source.home_position, v_source.home_card_cta, v_source.sort_order, auth.uid()
  )
  returning id into v_new_campaign_id;

  insert into public.election_publications (
    campaign_id, publication_type, title, summary, body,
    media_url, media_storage_path, cover_image_url, cover_storage_path,
    audience_tags, is_active, is_featured, published_at, sort_order
  )
  select
    v_new_campaign_id, p.publication_type, p.title, p.summary, p.body,
    p.media_url, p.media_storage_path, p.cover_image_url, p.cover_storage_path,
    p.audience_tags, p.is_active, p.is_featured, p.published_at, p.sort_order
  from public.election_publications p
  where p.campaign_id = p_campaign_id;

  for v_source_section in
    select * from public.election_sections
    where campaign_id = p_campaign_id
    order by sort_order, created_at
  loop
    insert into public.election_sections (
      campaign_id, section_type, title, subtitle, intro_text, icon_name,
      audience_tags, is_active, is_featured, sort_order
    )
    values (
      v_new_campaign_id, v_source_section.section_type,
      v_source_section.title, v_source_section.subtitle,
      v_source_section.intro_text, v_source_section.icon_name,
      v_source_section.audience_tags, v_source_section.is_active,
      v_source_section.is_featured, v_source_section.sort_order
    )
    returning id into v_new_section_id;

    insert into public.election_content_items (
      section_id, item_type, title, body, badge, metric_value,
      image_url, document_url, link_url, audience_tags,
      is_active, sort_order, metadata
    )
    select
      v_new_section_id, i.item_type, i.title, i.body, i.badge, i.metric_value,
      i.image_url, i.document_url, i.link_url, i.audience_tags,
      i.is_active, i.sort_order, i.metadata
    from public.election_content_items i
    where i.section_id = v_source_section.id;
  end loop;

  insert into public.election_candidates (
    campaign_id, first_name, last_name, job_title, sector, college,
    list_role, list_position, bio, photo_url, audience_tags,
    is_active, sort_order
  )
  select
    v_new_campaign_id, c.first_name, c.last_name, c.job_title, c.sector,
    c.college, c.list_role, c.list_position, c.bio, c.photo_url,
    c.audience_tags, c.is_active, c.sort_order
  from public.election_candidates c
  where c.campaign_id = p_campaign_id;

  return v_new_campaign_id;
end;
$$;

grant select, insert, update, delete on public.election_publications to authenticated;
grant execute on function public.get_election_campaign_bundle(uuid) to authenticated;
grant execute on function public.duplicate_election_campaign(uuid,text,text,integer) to authenticated;

commit;

-- Module Élections CFDT
-- Multi-campagnes / multi-CSE / CSEC / ciblage cadres/non-cadres.
-- Intégré aux droits existants :
--   role_table.role = adm      -> administration de son propre CSE
--   role_table.role = supuser  -> administration de tous les CSE + CSEC/GLOBAL
--
-- IMPORTANT :
-- election_campaigns.cse_code doit contenir la valeur exacte de liste_cse.cse
-- / users.cse, par exemple "CSE EXPLOITATION HUB".

create extension if not exists pgcrypto;

create table if not exists public.election_campaigns (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  title text not null,
  subtitle text,
  election_year integer,
  scope_level text not null default 'CSE'
    check (scope_level in ('GLOBAL','CSEC','CSE')),
  cse_code text,
  status text not null default 'draft'
    check (status in ('draft','published','archived')),
  is_active boolean not null default false,
  hero_image_url text,
  intro_text text,
  vote_start_at timestamptz,
  vote_end_at timestamptz,
  display_start_at timestamptz,
  display_end_at timestamptz,
  sort_order integer not null default 100,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint election_campaigns_scope_cse_ck check (
    (scope_level = 'CSE' and cse_code is not null and btrim(cse_code) <> '')
    or (scope_level in ('GLOBAL','CSEC') and cse_code is null)
  )
);

create table if not exists public.election_sections (
  id uuid primary key default gen_random_uuid(),
  campaign_id uuid not null references public.election_campaigns(id) on delete cascade,
  section_type text not null default 'custom',
  title text not null,
  subtitle text,
  intro_text text,
  icon_name text,
  audience_tags text[] not null default array['ALL']::text[],
  is_active boolean not null default true,
  is_featured boolean not null default false,
  sort_order integer not null default 100,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.election_content_items (
  id uuid primary key default gen_random_uuid(),
  section_id uuid not null references public.election_sections(id) on delete cascade,
  item_type text not null default 'text'
    check (item_type in ('text','commitment','result','news','document','link','metric','quote','image')),
  title text not null,
  body text,
  badge text,
  metric_value text,
  image_url text,
  document_url text,
  link_url text,
  audience_tags text[] not null default array['ALL']::text[],
  is_active boolean not null default true,
  sort_order integer not null default 100,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.election_candidates (
  id uuid primary key default gen_random_uuid(),
  campaign_id uuid not null references public.election_campaigns(id) on delete cascade,
  first_name text not null,
  last_name text not null,
  job_title text,
  sector text,
  college text,
  list_role text,
  list_position integer,
  bio text,
  photo_url text,
  audience_tags text[] not null default array['ALL']::text[],
  is_active boolean not null default true,
  sort_order integer not null default 100,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists election_campaigns_visible_idx
  on public.election_campaigns (is_active, status, cse_code, sort_order);
create index if not exists election_sections_campaign_idx
  on public.election_sections (campaign_id, is_active, sort_order);
create index if not exists election_items_section_idx
  on public.election_content_items (section_id, is_active, sort_order);
create index if not exists election_candidates_campaign_idx
  on public.election_candidates (campaign_id, is_active, sort_order);
create index if not exists election_sections_audience_gin
  on public.election_sections using gin (audience_tags);
create index if not exists election_items_audience_gin
  on public.election_content_items using gin (audience_tags);
create index if not exists election_candidates_audience_gin
  on public.election_candidates using gin (audience_tags);

create or replace function public.set_election_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_election_campaigns_updated on public.election_campaigns;
create trigger trg_election_campaigns_updated
before update on public.election_campaigns
for each row execute function public.set_election_updated_at();

drop trigger if exists trg_election_sections_updated on public.election_sections;
create trigger trg_election_sections_updated
before update on public.election_sections
for each row execute function public.set_election_updated_at();

drop trigger if exists trg_election_items_updated on public.election_content_items;
create trigger trg_election_items_updated
before update on public.election_content_items
for each row execute function public.set_election_updated_at();

drop trigger if exists trg_election_candidates_updated on public.election_candidates;
create trigger trg_election_candidates_updated
before update on public.election_candidates
for each row execute function public.set_election_updated_at();

-- ---------------------------------------------------------------------------
-- Ciblage utilisateur
-- ---------------------------------------------------------------------------

create or replace function public.election_audience_from_level(p_level text)
returns text
language plpgsql
immutable
as $$
declare
  v text := upper(replace(coalesce(p_level, ''), ' ', ''));
begin
  -- Les données existent selon les sources sous forme N12 ou 12.
  if v ~ '^N[0-9]+$' then
    v := substring(v from 2);
  end if;

  -- Règles confirmées dans le référentiel fourni :
  -- Cadres : N12/N21/N22/N31/N32/CT
  if v in ('12','21','22','31','32','CT') then
    return 'CADRE';
  end if;

  -- Techniciens N1-N4 + Maîtrises N5.
  if v in ('1','2','3','4','5') then
    return 'NON_CADRE';
  end if;

  -- Pour les codes non encore qualifiés : ne pas risquer un mauvais ciblage.
  return 'ALL';
end;
$$;

create or replace function public.get_my_election_context()
returns table(cse_code text, audience text)
language sql
stable
security definer
set search_path = public
as $$
  select
    nullif(btrim(u.cse), '') as cse_code,
    public.election_audience_from_level(u.niveau) as audience
  from public.users u
  where u.id = auth.uid()
  limit 1;
$$;

-- ---------------------------------------------------------------------------
-- Droits d'administration intégrés à role_table/effectif
-- ---------------------------------------------------------------------------

create or replace function public.get_my_election_admin_context()
returns table(admin_role text, admin_cse text)
language sql
stable
security definer
set search_path = public
as $$
  select
    lower(btrim(rt.role)) as admin_role,
    nullif(btrim(coalesce(e.cse, u.cse)), '') as admin_cse
  from public.users u
  left join public.role_table rt
    on btrim(rt.matricule) = btrim(u.matriculeaf)
  left join public.effectif e
    on btrim(e.matricule) = btrim(u.matriculeaf)
  where u.id = auth.uid()
  limit 1;
$$;

create or replace function public.can_manage_election_values(
  p_scope_level text,
  p_cse_code text
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((
    select
      ctx.admin_role = 'supuser'
      or (
        ctx.admin_role = 'adm'
        and p_scope_level = 'CSE'
        and ctx.admin_cse is not null
        and upper(btrim(ctx.admin_cse)) = upper(btrim(p_cse_code))
      )
    from public.get_my_election_admin_context() ctx
  ), false);
$$;

create or replace function public.can_manage_election_campaign(p_campaign_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((
    select public.can_manage_election_values(c.scope_level, c.cse_code)
    from public.election_campaigns c
    where c.id = p_campaign_id
  ), false);
$$;



create or replace function public.get_manageable_election_campaigns()
returns setof public.election_campaigns
language sql
stable
security definer
set search_path = public
as $$
  select c.*
  from public.election_campaigns c
  where public.can_manage_election_campaign(c.id)
  order by c.created_at desc;
$$;

create or replace function public.get_manageable_election_cse()
returns table(cse text)
language sql
stable
security definer
set search_path = public
as $$
  with ctx as (
    select * from public.get_my_election_admin_context()
  )
  select lc.cse
  from public.liste_cse lc
  cross join ctx
  where ctx.admin_role = 'supuser'
     or (
       ctx.admin_role = 'adm'
       and ctx.admin_cse is not null
       and upper(btrim(lc.cse)) = upper(btrim(ctx.admin_cse))
     )
  order by lc.cse;
$$;

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
  select *
  into v_source
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
    slug,
    title,
    subtitle,
    election_year,
    scope_level,
    cse_code,
    status,
    is_active,
    hero_image_url,
    intro_text,
    sort_order,
    created_by
  )
  values (
    btrim(p_new_slug),
    btrim(p_new_title),
    v_source.subtitle,
    p_new_year,
    v_source.scope_level,
    v_source.cse_code,
    'draft',
    false,
    v_source.hero_image_url,
    v_source.intro_text,
    v_source.sort_order,
    auth.uid()
  )
  returning id into v_new_campaign_id;

  for v_source_section in
    select *
    from public.election_sections
    where campaign_id = p_campaign_id
    order by sort_order, created_at
  loop
    insert into public.election_sections (
      campaign_id,
      section_type,
      title,
      subtitle,
      intro_text,
      icon_name,
      audience_tags,
      is_active,
      is_featured,
      sort_order
    )
    values (
      v_new_campaign_id,
      v_source_section.section_type,
      v_source_section.title,
      v_source_section.subtitle,
      v_source_section.intro_text,
      v_source_section.icon_name,
      v_source_section.audience_tags,
      v_source_section.is_active,
      v_source_section.is_featured,
      v_source_section.sort_order
    )
    returning id into v_new_section_id;

    insert into public.election_content_items (
      section_id,
      item_type,
      title,
      body,
      badge,
      metric_value,
      image_url,
      document_url,
      link_url,
      audience_tags,
      is_active,
      sort_order,
      metadata
    )
    select
      v_new_section_id,
      i.item_type,
      i.title,
      i.body,
      i.badge,
      i.metric_value,
      i.image_url,
      i.document_url,
      i.link_url,
      i.audience_tags,
      i.is_active,
      i.sort_order,
      i.metadata
    from public.election_content_items i
    where i.section_id = v_source_section.id;
  end loop;

  insert into public.election_candidates (
    campaign_id,
    first_name,
    last_name,
    job_title,
    sector,
    college,
    list_role,
    list_position,
    bio,
    photo_url,
    audience_tags,
    is_active,
    sort_order
  )
  select
    v_new_campaign_id,
    c.first_name,
    c.last_name,
    c.job_title,
    c.sector,
    c.college,
    c.list_role,
    c.list_position,
    c.bio,
    c.photo_url,
    c.audience_tags,
    c.is_active,
    c.sort_order
  from public.election_candidates c
  where c.campaign_id = p_campaign_id;

  return v_new_campaign_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- RPC côté application adhérent.
-- Le CSE et l'audience sont DÉDUITS du profil connecté, pas fournis par Flutter.
-- ---------------------------------------------------------------------------

create or replace function public.get_visible_election_campaigns()
returns setof public.election_campaigns
language sql
stable
security definer
set search_path = public
as $$
  with ctx as (
    select * from public.get_my_election_context()
  )
  select c.*
  from public.election_campaigns c
  cross join ctx
  where c.is_active = true
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
  order by
    case c.scope_level when 'CSE' then 0 when 'CSEC' then 1 else 2 end,
    c.sort_order,
    c.created_at desc;
$$;

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


create or replace function public.can_view_election_campaign(p_campaign_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  with ctx as (
    select * from public.get_my_election_context()
  )
  select coalesce((
    select true
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
  ), false);
$$;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

alter table public.election_campaigns enable row level security;
alter table public.election_sections enable row level security;
alter table public.election_content_items enable row level security;
alter table public.election_candidates enable row level security;

drop policy if exists "elections authenticated read campaigns" on public.election_campaigns;
create policy "elections authenticated read campaigns"
on public.election_campaigns for select
to authenticated
using (
  public.can_view_election_campaign(id)
  or public.can_manage_election_campaign(id)
);

drop policy if exists "elections authenticated read sections" on public.election_sections;
create policy "elections authenticated read sections"
on public.election_sections for select
to authenticated
using (
  public.can_view_election_campaign(campaign_id)
  or public.can_manage_election_campaign(campaign_id)
);

drop policy if exists "elections authenticated read items" on public.election_content_items;
create policy "elections authenticated read items"
on public.election_content_items for select
to authenticated
using (
  exists (
    select 1
    from public.election_sections s
    where s.id = section_id
      and (
        public.can_view_election_campaign(s.campaign_id)
        or public.can_manage_election_campaign(s.campaign_id)
      )
  )
);

drop policy if exists "elections authenticated read candidates" on public.election_candidates;
create policy "elections authenticated read candidates"
on public.election_candidates for select
to authenticated
using (
  public.can_view_election_campaign(campaign_id)
  or public.can_manage_election_campaign(campaign_id)
);

drop policy if exists "elections campaign insert" on public.election_campaigns;
create policy "elections campaign insert"
on public.election_campaigns for insert
to authenticated
with check (
  public.can_manage_election_values(scope_level, cse_code)
  and (created_by is null or created_by = auth.uid())
);

drop policy if exists "elections campaign update" on public.election_campaigns;
create policy "elections campaign update"
on public.election_campaigns for update
to authenticated
using (public.can_manage_election_campaign(id))
with check (public.can_manage_election_values(scope_level, cse_code));

drop policy if exists "elections campaign delete" on public.election_campaigns;
create policy "elections campaign delete"
on public.election_campaigns for delete
to authenticated
using (public.can_manage_election_campaign(id));

drop policy if exists "elections section write" on public.election_sections;
create policy "elections section write"
on public.election_sections for all
to authenticated
using (public.can_manage_election_campaign(campaign_id))
with check (public.can_manage_election_campaign(campaign_id));

drop policy if exists "elections item write" on public.election_content_items;
create policy "elections item write"
on public.election_content_items for all
to authenticated
using (
  exists (
    select 1 from public.election_sections s
    where s.id = section_id
      and public.can_manage_election_campaign(s.campaign_id)
  )
)
with check (
  exists (
    select 1 from public.election_sections s
    where s.id = section_id
      and public.can_manage_election_campaign(s.campaign_id)
  )
);

drop policy if exists "elections candidate write" on public.election_candidates;
create policy "elections candidate write"
on public.election_candidates for all
to authenticated
using (public.can_manage_election_campaign(campaign_id))
with check (public.can_manage_election_campaign(campaign_id));

grant execute on function public.election_audience_from_level(text) to authenticated;
grant execute on function public.get_my_election_context() to authenticated;
grant execute on function public.get_my_election_admin_context() to authenticated;
grant execute on function public.get_manageable_election_campaigns() to authenticated;
grant execute on function public.get_manageable_election_cse() to authenticated;
grant execute on function public.duplicate_election_campaign(uuid,text,text,integer) to authenticated;
grant execute on function public.can_manage_election_values(text,text) to authenticated;
grant execute on function public.can_manage_election_campaign(uuid) to authenticated;
grant execute on function public.can_view_election_campaign(uuid) to authenticated;
grant execute on function public.get_visible_election_campaigns() to authenticated;
grant execute on function public.get_election_campaign_bundle(uuid) to authenticated;

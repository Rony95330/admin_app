-- Studio Podcasts IA CFDT : brouillons, sources PDF privées et audios publiables.

create or replace function public.current_user_is_podcast_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.users u
    left join public.role_table r
      on r.matricule::text = u.matriculeaf::text
    where u.id = auth.uid()
      and lower(coalesce(r.role::text, u.level::text, ''))
        in ('adm', 'admin', 'supuser', 'superuser')
  );
$$;

revoke all on function public.current_user_is_podcast_admin() from public;
grant execute on function public.current_user_is_podcast_admin()
  to authenticated, service_role;

create table if not exists public.podcast_ai_jobs (
  id uuid primary key default gen_random_uuid(),
  created_by uuid not null references auth.users(id) on delete cascade,
  title text not null check (char_length(btrim(title)) between 2 and 180),
  cse text not null check (char_length(btrim(cse)) between 1 and 120),
  requested_minutes integer not null default 5
    check (requested_minutes between 2 and 10),
  source_pdf_name text,
  source_pdf_path text,
  source_page_count integer,
  source_character_count integer,
  script text,
  status text not null default 'draft'
    check (status in (
      'draft', 'uploading', 'uploaded', 'script_ready',
      'generating_audio', 'ready', 'published', 'failed'
    )),
  audio_path text,
  audio_url text,
  error_message text,
  published_podcast_id text,
  script_model text,
  tts_model text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  published_at timestamptz
);

create index if not exists podcast_ai_jobs_creator_created_idx
  on public.podcast_ai_jobs(created_by, created_at desc);
create index if not exists podcast_ai_jobs_status_idx
  on public.podcast_ai_jobs(status, updated_at desc);

alter table public.podcast_ai_jobs enable row level security;

drop policy if exists "podcast_ai_jobs_admin_select" on public.podcast_ai_jobs;
create policy "podcast_ai_jobs_admin_select"
on public.podcast_ai_jobs
for select
to authenticated
using (
  created_by = auth.uid()
  and public.current_user_is_podcast_admin()
);

drop policy if exists "podcast_ai_jobs_admin_insert" on public.podcast_ai_jobs;
create policy "podcast_ai_jobs_admin_insert"
on public.podcast_ai_jobs
for insert
to authenticated
with check (
  created_by = auth.uid()
  and public.current_user_is_podcast_admin()
);

drop policy if exists "podcast_ai_jobs_admin_update" on public.podcast_ai_jobs;
create policy "podcast_ai_jobs_admin_update"
on public.podcast_ai_jobs
for update
to authenticated
using (
  created_by = auth.uid()
  and public.current_user_is_podcast_admin()
)
with check (
  created_by = auth.uid()
  and public.current_user_is_podcast_admin()
);

drop policy if exists "podcast_ai_jobs_admin_delete" on public.podcast_ai_jobs;
create policy "podcast_ai_jobs_admin_delete"
on public.podcast_ai_jobs
for delete
to authenticated
using (
  created_by = auth.uid()
  and public.current_user_is_podcast_admin()
  and status <> 'published'
);

grant select, insert, update, delete on public.podcast_ai_jobs to authenticated;

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'podcast_sources',
  'podcast_sources',
  false,
  20971520,
  array['application/pdf']::text[]
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'podcast_ai_audio',
  'podcast_ai_audio',
  true,
  52428800,
  array['audio/wav']::text[]
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "podcast_sources_admin_insert" on storage.objects;
create policy "podcast_sources_admin_insert"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'podcast_sources'
  and public.current_user_is_podcast_admin()
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "podcast_sources_admin_select" on storage.objects;
create policy "podcast_sources_admin_select"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'podcast_sources'
  and public.current_user_is_podcast_admin()
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "podcast_sources_admin_delete" on storage.objects;
create policy "podcast_sources_admin_delete"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'podcast_sources'
  and public.current_user_is_podcast_admin()
  and (storage.foldername(name))[1] = auth.uid()::text
);

comment on table public.podcast_ai_jobs is
  'Projets du studio CFDT transformant un compte rendu PDF en podcast à deux voix.';
comment on column public.podcast_ai_jobs.source_pdf_path is
  'Chemin privé temporaire, effacé après génération réussie du script.';

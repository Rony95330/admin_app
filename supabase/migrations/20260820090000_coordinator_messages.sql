-- Module « Le mot du coordinateur » — CFDT Air France.

create extension if not exists pgcrypto;

create table if not exists public.coordinator_messages (
  id uuid primary key default gen_random_uuid(),
  cse text not null check (char_length(btrim(cse)) between 1 and 120),
  coordinator_member_id bigint,
  coordinator_name text not null
    check (char_length(btrim(coordinator_name)) between 1 and 160),
  coordinator_role text,
  coordinator_photo_url text,
  headline text check (headline is null or char_length(headline) <= 180),
  body text not null check (char_length(btrim(body)) between 1 and 10000),
  published_from timestamptz,
  published_until timestamptz,
  is_active boolean not null default false,
  sort_order integer not null default 100,
  archived_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint coordinator_messages_dates_ok check (
    published_until is null
    or published_from is null
    or published_until > published_from
  )
);

create index if not exists coordinator_messages_live_cse_idx
  on public.coordinator_messages (
    cse,
    is_active,
    archived_at,
    sort_order,
    published_from desc
  );

create or replace function public.touch_coordinator_message_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  new.updated_by = auth.uid();
  return new;
end;
$$;

drop trigger if exists trg_coordinator_messages_updated_at
  on public.coordinator_messages;
create trigger trg_coordinator_messages_updated_at
before update on public.coordinator_messages
for each row execute function public.touch_coordinator_message_updated_at();

-- Un seul message est actif à la fois pour une section. Le remplacement est
-- réalisé dans la même transaction que l'enregistrement du nouveau message.
create or replace function public.keep_one_active_coordinator_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.is_active then
    update public.coordinator_messages
    set is_active = false
    where cse = new.cse
      and id <> new.id
      and is_active = true;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_coordinator_messages_one_active
  on public.coordinator_messages;
create trigger trg_coordinator_messages_one_active
before insert or update of is_active, cse
on public.coordinator_messages
for each row execute function public.keep_one_active_coordinator_message();

create or replace function public.is_coordinator_message_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    exists (
      select 1
      from public.users u
      where u.id = auth.uid()
        and lower(coalesce(u.level::text, ''))
          in ('adm', 'admin', 'supuser', 'superadmin')
    )
    or exists (
      select 1
      from public.users u
      join public.role_table r
        on r.matricule::text = u.matriculeaf::text
      where u.id = auth.uid()
        and lower(coalesce(r.role::text, ''))
          in ('adm', 'admin', 'supuser', 'superadmin')
    );
$$;

revoke all on function public.is_coordinator_message_admin() from public;
grant execute on function public.is_coordinator_message_admin()
  to authenticated;

alter table public.coordinator_messages enable row level security;

drop policy if exists coordinator_messages_public_read_live
  on public.coordinator_messages;
create policy coordinator_messages_public_read_live
on public.coordinator_messages
for select
to anon, authenticated
using (
  is_active = true
  and archived_at is null
  and (published_from is null or published_from <= now())
  and (published_until is null or published_until > now())
);

drop policy if exists coordinator_messages_admin_select
  on public.coordinator_messages;
create policy coordinator_messages_admin_select
on public.coordinator_messages
for select
to authenticated
using (public.is_coordinator_message_admin());

drop policy if exists coordinator_messages_admin_insert
  on public.coordinator_messages;
create policy coordinator_messages_admin_insert
on public.coordinator_messages
for insert
to authenticated
with check (public.is_coordinator_message_admin());

drop policy if exists coordinator_messages_admin_update
  on public.coordinator_messages;
create policy coordinator_messages_admin_update
on public.coordinator_messages
for update
to authenticated
using (public.is_coordinator_message_admin())
with check (public.is_coordinator_message_admin());

drop policy if exists coordinator_messages_admin_delete
  on public.coordinator_messages;
create policy coordinator_messages_admin_delete
on public.coordinator_messages
for delete
to authenticated
using (public.is_coordinator_message_admin());

grant select on public.coordinator_messages to anon, authenticated;
grant insert, update, delete on public.coordinator_messages to authenticated;

-- Actions enrichies des bandeaux d'accueil CFDT.
-- Les anciens types restent autorisés pour ne casser aucun bandeau existant.

alter table public.home_banners
  drop constraint if exists home_banners_action_type_check;

alter table public.home_banners
  add constraint home_banners_action_type_check
  check (
    action_type in (
      'none',
      'internal',
      'url',
      'pdf',
      'news',
      'tract',
      'press_review',
      'podcast'
    )
  );

update storage.buckets
set file_size_limit = 52428800
where id = 'home-banners';

-- Les PDF ajoutés depuis l'éditeur sont conservés dans le bucket privé
-- home-banners. Ils ne sont lisibles que lorsqu'un bandeau actif les référence.
drop policy if exists home_banners_storage_live_read on storage.objects;
create policy home_banners_storage_live_read
on storage.objects
for select
to anon, authenticated
using (
  bucket_id = 'home-banners'
  and exists (
    select 1
    from public.home_banners b
    where (
        b.image_storage_path = name
        or (
          b.action_type = 'pdf'
          and b.action_value = ('home-banners:' || name)
        )
      )
      and b.is_active = true
      and b.archived_at is null
      and (b.starts_at is null or b.starts_at <= now())
      and (b.ends_at is null or b.ends_at > now())
  )
);

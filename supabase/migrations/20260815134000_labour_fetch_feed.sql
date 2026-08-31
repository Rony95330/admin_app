begin;

create or replace function public.labour_fetch_feed(p_url text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status integer;
  v_content text;
begin
  if p_url is null or btrim(p_url) = '' then
    raise exception 'URL de flux manquante.';
  end if;

  if not (
    p_url ~ '^https://www\.editions-tissot\.fr/'
    or p_url ~ '^https://www\.service-public\.fr/'
    or p_url ~ '^https://news\.google\.com/'
    or p_url ~ '^https://portaildocumentaire\.inrs\.fr/'
    or p_url ~ '^https://veille-travail\.anact\.fr/'
  ) then
    raise exception 'Hôte de flux juridique non autorisé.';
  end if;

  select
    response.status,
    response.content
  into
    v_status,
    v_content
  from extensions.http_get(p_url) as response;

  if v_status is distinct from 200 then
    raise exception 'Flux juridique HTTP %', coalesce(v_status, 0);
  end if;

  if v_content is null or btrim(v_content) = '' then
    raise exception 'Flux juridique vide.';
  end if;

  return v_content;
end;
$$;

comment on function public.labour_fetch_feed(text) is
  'Récupère côté PostgreSQL les flux autorisés du Fil juridique. Réservé au service_role.';

revoke all
on function public.labour_fetch_feed(text)
from public, anon, authenticated;

grant execute
on function public.labour_fetch_feed(text)
to service_role;

commit;

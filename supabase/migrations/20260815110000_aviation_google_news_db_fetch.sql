create extension if not exists http with schema extensions;

create or replace function public.aviation_fetch_google_news(p_url text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_url text;
  v_status integer;
  v_content text;
begin
  v_url := btrim(p_url);

  -- Sécurité : cette fonction est exclusivement destinée à Google News RSS.
  if v_url is null
     or v_url !~ '^https://news\.google\.com/' then
    raise exception 'URL Google News non autorisée';
  end if;

  select
    r.status,
    r.content
  into
    v_status,
    v_content
  from extensions.http_get(v_url) as r;

  if v_status <> 200 then
    raise exception 'Google News HTTP %', v_status;
  end if;

  if v_content is null or length(v_content) = 0 then
    raise exception 'Google News a retourné une réponse vide';
  end if;

  return v_content;
end;
$$;

revoke execute
on function public.aviation_fetch_google_news(text)
from public, anon, authenticated;

grant execute
on function public.aviation_fetch_google_news(text)
to service_role;

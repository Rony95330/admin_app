-- Métadonnées nécessaires à la synchronisation durable du corpus RH IA.
alter table public.rh_ai_documents
  add column if not exists category text,
  add column if not exists sha256 text,
  add column if not exists page_count integer,
  add column if not exists indexed_at timestamptz;

create unique index if not exists rh_ai_documents_file_path_uidx
  on public.rh_ai_documents(file_path)
  where file_path is not null;

create index if not exists rh_ai_documents_sha256_idx
  on public.rh_ai_documents(sha256);

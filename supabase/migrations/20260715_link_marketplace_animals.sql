-- Vincula publicaciones automáticas del Marketplace con su animal de origen.
alter table if exists public.marketplace_items
  add column if not exists source_animal_id text;

create unique index if not exists marketplace_user_source_animal_idx
  on public.marketplace_items(user_id, source_animal_id)
  where source_animal_id is not null;

notify pgrst, 'reload schema';

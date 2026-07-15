-- Colaboración clínica ganadero-veterinario. Ninguna aprobación administrativa
-- concede acceso a fincas: el vínculo accepted es obligatorio.
create table if not exists public.vet_farm_links (
  id text primary key, farmer_id uuid not null references auth.users(id) on delete cascade,
  vet_id uuid not null references auth.users(id) on delete cascade, farm_id text not null,
  status text not null check (status in ('pending','accepted','rejected','revoked','expired')),
  permissions text not null default '[]', created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(), expires_at timestamptz
);
create table if not exists public.clinical_case_chats (
  id text primary key, case_id text not null, animal_id text, farm_id text,
  farmer_id uuid not null references auth.users(id) on delete cascade,
  vet_id uuid not null references auth.users(id) on delete cascade,
  status text not null check (status in ('open','waiting_vet','waiting_farmer','in_review','resolved','closed')),
  priority text not null check (priority in ('green','yellow','red','urgent')),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), closed_at timestamptz
);
create table if not exists public.clinical_case_messages (
  id text primary key, chat_id text not null references public.clinical_case_chats(id) on delete cascade,
  case_id text, sender_id text not null, sender_role text, message_type text not null,
  message text, media_path text, ai_generated boolean not null default false,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  sync_status text not null default 'synced'
);
create table if not exists public.vet_visits (
  id text primary key, vet_id uuid not null references auth.users(id), farmer_id uuid not null references auth.users(id),
  farm_id text, animal_id text, case_id text, chat_id text, visit_date timestamptz,
  reason text, priority text, status text not null, notes text,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.vet_validations (
  id text primary key, vet_id uuid not null references auth.users(id), farmer_id uuid not null references auth.users(id),
  animal_id text, target_type text not null, target_id text not null, status text not null,
  comments text, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

alter table public.vet_farm_links enable row level security;
alter table public.clinical_case_chats enable row level security;
alter table public.clinical_case_messages enable row level security;
alter table public.vet_visits enable row level security;
alter table public.vet_validations enable row level security;

drop policy if exists vet_farm_links_participants on public.vet_farm_links;
create policy vet_farm_links_participants on public.vet_farm_links for select to authenticated
  using (farmer_id = auth.uid() or vet_id = auth.uid());
drop policy if exists vet_farm_links_farmer_insert on public.vet_farm_links;
create policy vet_farm_links_farmer_insert on public.vet_farm_links for insert to authenticated
  with check (farmer_id = auth.uid() and status = 'pending');
drop policy if exists vet_farm_links_participant_update on public.vet_farm_links;
create policy vet_farm_links_participant_update on public.vet_farm_links for update to authenticated
  using (farmer_id = auth.uid() or vet_id = auth.uid())
  with check (farmer_id = auth.uid() or vet_id = auth.uid());

drop policy if exists clinical_chats_participants on public.clinical_case_chats;
create policy clinical_chats_participants on public.clinical_case_chats for select to authenticated
  using (farmer_id = auth.uid() or vet_id = auth.uid());
drop policy if exists clinical_chats_authorized_insert on public.clinical_case_chats;
create policy clinical_chats_authorized_insert on public.clinical_case_chats for insert to authenticated
  with check ((farmer_id = auth.uid() or vet_id = auth.uid()) and exists (
    select 1 from public.vet_farm_links link where link.farmer_id = clinical_case_chats.farmer_id
      and link.vet_id = clinical_case_chats.vet_id and link.farm_id = clinical_case_chats.farm_id and link.status = 'accepted'));
drop policy if exists clinical_chats_participant_update on public.clinical_case_chats;
create policy clinical_chats_participant_update on public.clinical_case_chats for update to authenticated
  using (farmer_id = auth.uid() or vet_id = auth.uid());

drop policy if exists clinical_messages_participants on public.clinical_case_messages;
create policy clinical_messages_participants on public.clinical_case_messages for select to authenticated
  using (exists (select 1 from public.clinical_case_chats chat where chat.id = chat_id and (chat.farmer_id = auth.uid() or chat.vet_id = auth.uid())));
drop policy if exists clinical_messages_authorized_insert on public.clinical_case_messages;
create policy clinical_messages_authorized_insert on public.clinical_case_messages for insert to authenticated
  with check ((sender_id = auth.uid()::text or ai_generated = true) and exists (
    select 1 from public.clinical_case_chats chat join public.vet_farm_links link
      on link.farmer_id = chat.farmer_id and link.vet_id = chat.vet_id and link.farm_id = chat.farm_id
    where chat.id = chat_id and link.status = 'accepted' and (chat.farmer_id = auth.uid() or chat.vet_id = auth.uid())));

do $$ declare table_name text; begin
  foreach table_name in array array['vet_visits','vet_validations'] loop
    execute format('drop policy if exists %I on public.%I', table_name || '_participants', table_name);
    execute format('create policy %I on public.%I for all to authenticated using (farmer_id = auth.uid() or vet_id = auth.uid()) with check ((farmer_id = auth.uid() or vet_id = auth.uid()) and exists (select 1 from public.vet_farm_links link where link.farmer_id = %I.farmer_id and link.vet_id = %I.vet_id and link.status = ''accepted''))', table_name || '_participants', table_name, table_name, table_name);
  end loop;
end $$;

create index if not exists vet_links_participants_idx on public.vet_farm_links(farmer_id, vet_id, status);
create index if not exists clinical_chats_case_idx on public.clinical_case_chats(case_id);
create index if not exists clinical_messages_chat_date_idx on public.clinical_case_messages(chat_id, created_at);

-- Resuelve correo, UUID o número de licencia sin exponer el directorio completo.
create or replace function public.resolve_approved_veterinarian(identifier text)
returns uuid language sql stable security definer set search_path = public
as $$
  select profile.user_id
  from public.user_profiles profile
  where profile.role = 'Veterinario' and profile.status = 'active'
    and (profile.user_id::text = identifier or lower(profile.email) = lower(identifier)
      or profile.license_number = identifier)
  limit 1
$$;
revoke all on function public.resolve_approved_veterinarian(text) from public;
grant execute on function public.resolve_approved_veterinarian(text) to authenticated;
notify pgrst, 'reload schema';

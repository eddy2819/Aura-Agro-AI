-- Inventario inteligente de medicamentos y trazabilidad de movimientos.
alter table if exists public.medicine_inventory
  add column if not exists active_ingredient text,
  add column if not exists presentation text,
  add column if not exists concentration text,
  add column if not exists batch_number text,
  add column if not exists label_photo_path text,
  add column if not exists withdrawal_period text,
  add column if not exists indications text,
  add column if not exists contraindications text,
  add column if not exists notes text;

create table if not exists public.medicine_movements (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  medicine_id text not null,
  animal_id text,
  movement_type text not null,
  quantity double precision not null check (quantity >= 0),
  reason text,
  responsible text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  synced integer not null default 0
);

alter table public.medicine_movements enable row level security;

create table if not exists public.farm_authorizations (
  id text primary key,
  ganadero_id uuid not null references auth.users(id) on delete cascade,
  veterinario_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'active'
);

drop policy if exists medicine_movements_owner_all on public.medicine_movements;
create policy medicine_movements_owner_all
  on public.medicine_movements for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- Un veterinario solo puede consultar el inventario si el ganadero lo autorizó.
-- La escritura sigue reservada al propietario para conservar trazabilidad.
drop policy if exists medicine_inventory_authorized_vet_read on public.medicine_inventory;
create policy medicine_inventory_authorized_vet_read
  on public.medicine_inventory for select to authenticated
  using (
    user_id = auth.uid()
    or exists (
      select 1 from public.farm_authorizations authorization
      where authorization.ganadero_id = medicine_inventory.user_id
        and authorization.veterinario_id = auth.uid()
        and authorization.status = 'active'
    )
  );

drop policy if exists medicine_movements_authorized_vet_read on public.medicine_movements;
create policy medicine_movements_authorized_vet_read
  on public.medicine_movements for select to authenticated
  using (
    user_id = auth.uid()
    or exists (
      select 1 from public.farm_authorizations authorization
      where authorization.ganadero_id = medicine_movements.user_id
        and authorization.veterinario_id = auth.uid()
        and authorization.status = 'active'
    )
  );

create index if not exists medicine_movements_user_date_idx
  on public.medicine_movements(user_id, created_at desc);
create index if not exists medicine_movements_medicine_idx
  on public.medicine_movements(medicine_id, created_at desc);

notify pgrst, 'reload schema';

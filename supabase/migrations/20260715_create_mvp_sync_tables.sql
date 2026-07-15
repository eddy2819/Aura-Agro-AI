-- Tablas offline-first usadas por los módulos MVP de AURA Agro.
create table if not exists public.sos_cases (
  id text primary key, user_id uuid not null references auth.users(id) on delete cascade,
  animal_id text, symptoms_text text, selected_symptoms text, risk_level text,
  title text, explanation text, safe_actions text, notify_vet boolean default false,
  created_at timestamptz default now(), updated_at timestamptz default now(), synced integer default 0
);

create table if not exists public.animal_exits (
  id text primary key, user_id uuid not null references auth.users(id) on delete cascade,
  animal_id text, exit_type text, exit_date text, reason text, sale_price double precision,
  buyer text, observations text, created_at timestamptz default now(),
  updated_at timestamptz default now(), synced integer default 0
);

create table if not exists public.medicine_inventory (
  id text primary key, user_id uuid not null references auth.users(id) on delete cascade,
  name text, type text, quantity double precision, unit text, min_stock double precision,
  expiration_date text, provider text, created_at timestamptz default now(),
  updated_at timestamptz default now(), synced integer default 0
);

create table if not exists public.medical_treatments (
  id text primary key, user_id uuid not null references auth.users(id) on delete cascade,
  animal_id text, diagnosis text, symptoms text, treatment text, medicine_id text,
  dose double precision, responsible text, date text, observations text,
  created_at timestamptz default now(), updated_at timestamptz default now(), synced integer default 0
);

create table if not exists public.reproduction_records (
  id text primary key, user_id uuid not null references auth.users(id) on delete cascade,
  animal_id text, event_type text, event_date text, notes text, expected_birth_date text,
  created_at timestamptz default now(), updated_at timestamptz default now(), synced integer default 0
);

create table if not exists public.operating_expenses (
  id text primary key, user_id uuid not null references auth.users(id) on delete cascade,
  category text, amount double precision, date text, description text, animal_id text,
  farm_id text, created_at timestamptz default now(), updated_at timestamptz default now(), synced integer default 0
);

alter table public.sos_cases enable row level security;
alter table public.animal_exits enable row level security;
alter table public.medicine_inventory enable row level security;
alter table public.medical_treatments enable row level security;
alter table public.reproduction_records enable row level security;
alter table public.operating_expenses enable row level security;

do $$
declare table_name text;
begin
  foreach table_name in array array[
    'sos_cases', 'animal_exits', 'medicine_inventory',
    'medical_treatments', 'reproduction_records', 'operating_expenses'
  ] loop
    execute format('drop policy if exists %I on public.%I', table_name || '_own_rows', table_name);
    execute format(
      'create policy %I on public.%I for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid())',
      table_name || '_own_rows', table_name
    );
  end loop;
end $$;

create index if not exists sos_cases_user_idx on public.sos_cases(user_id);
create index if not exists animal_exits_user_idx on public.animal_exits(user_id);
create index if not exists medicine_inventory_user_idx on public.medicine_inventory(user_id);
create index if not exists medical_treatments_user_idx on public.medical_treatments(user_id);
create index if not exists reproduction_records_user_idx on public.reproduction_records(user_id);
create index if not exists operating_expenses_user_idx on public.operating_expenses(user_id);

-- Relación usada para crear o actualizar automáticamente el anuncio de un
-- animal marcado como "Disponible para la venta".
alter table if exists public.marketplace_items
  add column if not exists source_animal_id text;

create unique index if not exists marketplace_user_source_animal_idx
  on public.marketplace_items(user_id, source_animal_id)
  where source_animal_id is not null;

notify pgrst, 'reload schema';

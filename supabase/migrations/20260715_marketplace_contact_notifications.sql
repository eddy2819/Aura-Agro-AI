-- Mensajes y ofertas enviados desde el Marketplace.
create table if not exists public.marketplace_notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_user_id uuid not null references auth.users(id) on delete cascade,
  sender_user_id uuid not null references auth.users(id) on delete cascade,
  marketplace_local_id bigint,
  listing_title text not null,
  notification_type text not null check (notification_type in ('message', 'offer')),
  message text not null,
  offer_amount double precision,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

alter table public.marketplace_notifications enable row level security;

drop policy if exists marketplace_notifications_recipient_select
  on public.marketplace_notifications;
create policy marketplace_notifications_recipient_select
  on public.marketplace_notifications for select
  to authenticated
  using (recipient_user_id = auth.uid());

drop policy if exists marketplace_notifications_sender_insert
  on public.marketplace_notifications;
create policy marketplace_notifications_sender_insert
  on public.marketplace_notifications for insert
  to authenticated
  with check (
    sender_user_id = auth.uid()
    and recipient_user_id <> auth.uid()
  );

drop policy if exists marketplace_notifications_recipient_update
  on public.marketplace_notifications;
create policy marketplace_notifications_recipient_update
  on public.marketplace_notifications for update
  to authenticated
  using (recipient_user_id = auth.uid())
  with check (recipient_user_id = auth.uid());

create index if not exists marketplace_notifications_recipient_idx
  on public.marketplace_notifications(recipient_user_id, created_at desc);

-- El Marketplace es visible para compradores autenticados; escritura y borrado
-- continúan protegidos por las políticas de propietario existentes.
drop policy if exists marketplace_items_authenticated_read
  on public.marketplace_items;
create policy marketplace_items_authenticated_read
  on public.marketplace_items for select
  to authenticated
  using (true);

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'marketplace_notifications'
  ) then
    alter publication supabase_realtime
      add table public.marketplace_notifications;
  end if;
end $$;

notify pgrst, 'reload schema';

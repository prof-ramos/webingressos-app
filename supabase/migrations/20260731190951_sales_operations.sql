-- Commercial records, tickets and the online-first check-in operation.

create type public.order_status as enum ('pending', 'confirmed', 'cancelled', 'refunded');

create table public.promoters (
  id bigint generated always as identity primary key,
  public_id uuid not null default gen_random_uuid() unique,
  event_id bigint not null references public.events (id) on delete restrict,
  display_name text not null check (char_length(trim(display_name)) between 2 and 160),
  contact text,
  commission_rate_basis_points integer not null default 0 check (commission_rate_basis_points between 0 and 10000),
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create index promoters_event_id_idx on public.promoters (event_id);

create table public.orders (
  id bigint generated always as identity primary key,
  public_id uuid not null default gen_random_uuid() unique,
  event_id bigint not null references public.events (id) on delete restrict,
  promoter_id bigint references public.promoters (id) on delete restrict,
  status public.order_status not null default 'pending',
  total_cents bigint not null check (total_cents >= 0),
  currency text not null default 'BRL' check (currency = 'BRL'),
  buyer_name text,
  buyer_email text,
  buyer_phone text,
  created_by uuid not null references auth.users (id) on delete restrict,
  created_at timestamptz not null default now()
);

create index orders_event_id_idx on public.orders (event_id);
create index orders_promoter_id_idx on public.orders (promoter_id);
create index orders_status_idx on public.orders (event_id, status);

create table public.order_items (
  id bigint generated always as identity primary key,
  order_id bigint not null references public.orders (id) on delete restrict,
  lot_id bigint not null references public.lots (id) on delete restrict,
  quantity integer not null check (quantity > 0),
  unit_price_cents bigint not null check (unit_price_cents >= 0),
  subtotal_cents bigint not null check (subtotal_cents >= 0),
  created_at timestamptz not null default now(),
  check (subtotal_cents = quantity::bigint * unit_price_cents)
);

create index order_items_order_id_idx on public.order_items (order_id);
create index order_items_lot_id_idx on public.order_items (lot_id);

create table public.tickets (
  id bigint generated always as identity primary key,
  public_id uuid not null default gen_random_uuid() unique,
  order_item_id bigint not null references public.order_items (id) on delete restrict,
  event_id bigint not null references public.events (id) on delete restrict,
  public_code text not null default replace(gen_random_uuid()::text, '-', '') unique,
  created_at timestamptz not null default now()
);

create index tickets_order_item_id_idx on public.tickets (order_item_id);
create index tickets_event_id_idx on public.tickets (event_id);

create table public.check_ins (
  id bigint generated always as identity primary key,
  public_id uuid not null default gen_random_uuid() unique,
  ticket_id bigint not null references public.tickets (id) on delete restrict,
  event_id bigint not null references public.events (id) on delete restrict,
  checked_by uuid not null references auth.users (id) on delete restrict,
  device_label text,
  checked_in_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (ticket_id)
);

create index check_ins_event_id_checked_in_at_idx
  on public.check_ins (event_id, checked_in_at desc);
create index check_ins_checked_by_idx on public.check_ins (checked_by);

alter table public.promoters enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.tickets enable row level security;
alter table public.check_ins enable row level security;

create policy promoters_select_member
  on public.promoters for select to authenticated
  using (public.can_access_event(event_id));

create policy promoters_insert_operator
  on public.promoters for insert to authenticated
  with check (public.has_event_role(event_id, array['owner', 'ops']::public.organization_role[]));

create policy promoters_update_operator
  on public.promoters for update to authenticated
  using (public.has_event_role(event_id, array['owner', 'ops']::public.organization_role[]))
  with check (public.has_event_role(event_id, array['owner', 'ops']::public.organization_role[]));

create policy orders_select_member
  on public.orders for select to authenticated
  using (public.can_access_event(event_id));

create policy orders_insert_operator
  on public.orders for insert to authenticated
  with check (
    public.has_event_role(event_id, array['owner', 'ops']::public.organization_role[])
    and created_by = (select auth.uid())
  );

create policy orders_update_operator
  on public.orders for update to authenticated
  using (public.has_event_role(event_id, array['owner', 'ops']::public.organization_role[]))
  with check (public.has_event_role(event_id, array['owner', 'ops']::public.organization_role[]));

create policy order_items_select_member
  on public.order_items for select to authenticated
  using (
    exists (
      select 1
      from public.orders order_record
      where order_record.id = order_id
        and public.can_access_event(order_record.event_id)
    )
  );

create policy order_items_insert_operator
  on public.order_items for insert to authenticated
  with check (
    exists (
      select 1
      from public.orders order_record
      join public.lots lot on lot.id = lot_id
      where order_record.id = order_id
        and order_record.event_id = lot.event_id
        and public.has_event_role(order_record.event_id, array['owner', 'ops']::public.organization_role[])
    )
  );

create policy tickets_select_gate
  on public.tickets for select to authenticated
  using (public.has_event_role(event_id, array['owner', 'ops', 'gate']::public.organization_role[]));

create policy tickets_insert_operator
  on public.tickets for insert to authenticated
  with check (public.has_event_role(event_id, array['owner', 'ops']::public.organization_role[]));

create policy check_ins_select_gate
  on public.check_ins for select to authenticated
  using (public.has_event_role(event_id, array['owner', 'ops', 'gate']::public.organization_role[]));

create or replace function public.check_in_ticket(
  ticket_code text,
  target_event_public_id uuid,
  scanner_device_label text default null
)
returns table (
  status text,
  reason text,
  ticket_public_id uuid,
  checked_in_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  ticket_record record;
  existing_check_in timestamptz;
  inserted_check_in timestamptz;
begin
  select
    ticket.id,
    ticket.public_id,
    ticket.event_id,
    event_record.public_id as event_public_id,
    event_record.status as event_status,
    order_record.status as order_status
  into ticket_record
  from public.tickets ticket
  join public.events event_record on event_record.id = ticket.event_id
  join public.order_items item on item.id = ticket.order_item_id
  join public.orders order_record on order_record.id = item.order_id
  where ticket.public_code = ticket_code;

  if not found then
    return query select 'invalid', 'not_found', null::uuid, null::timestamptz;
    return;
  end if;

  if not public.has_event_role(ticket_record.event_id, array['owner', 'ops', 'gate']::public.organization_role[]) then
    raise exception using errcode = '42501', message = 'Not authorized to check in for this event';
  end if;

  if ticket_record.event_public_id <> target_event_public_id then
    return query select 'invalid', 'wrong_event', ticket_record.public_id, null::timestamptz;
    return;
  end if;

  if ticket_record.event_status = 'cancelado'
    or ticket_record.order_status in ('cancelled', 'refunded') then
    return query select 'invalid', 'cancelled', ticket_record.public_id, null::timestamptz;
    return;
  end if;

  select check_in.checked_in_at
  into existing_check_in
  from public.check_ins check_in
  where check_in.ticket_id = ticket_record.id
  for update;

  if existing_check_in is not null then
    return query select 'already_checked_in', null, ticket_record.public_id, existing_check_in;
    return;
  end if;

  insert into public.check_ins (ticket_id, event_id, checked_by, device_label)
  values (ticket_record.id, ticket_record.event_id, (select auth.uid()), scanner_device_label)
  on conflict (ticket_id) do nothing
  returning check_ins.checked_in_at into inserted_check_in;

  if inserted_check_in is not null then
    return query select 'accepted', null, ticket_record.public_id, inserted_check_in;
    return;
  end if;

  select check_in.checked_in_at
  into existing_check_in
  from public.check_ins check_in
  where check_in.ticket_id = ticket_record.id;

  return query select 'already_checked_in', null, ticket_record.public_id, existing_check_in;
end;
$$;

revoke all on function public.check_in_ticket(text, uuid, text) from public;
grant execute on function public.check_in_ticket(text, uuid, text) to authenticated;

grant usage on all sequences in schema public to authenticated;
grant select on public.promoters, public.orders, public.order_items, public.tickets, public.check_ins
  to authenticated;
grant insert, update on public.promoters, public.orders, public.order_items, public.tickets
  to authenticated;

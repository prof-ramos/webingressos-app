-- Reconcile concurrency and lifecycle guards for already-applied migrations.

create or replace function public.prevent_order_item_write_after_confirmation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  current_order_status public.order_status;
begin
  select status
  into current_order_status
  from public.orders
  where id = new.order_id
  for update;

  if current_order_status is distinct from 'pending' then
    raise exception using errcode = '23514', message = 'Order items require a pending order';
  end if;

  return new;
end;
$$;

create or replace function public.prevent_lot_event_change()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.event_id is distinct from old.event_id then
    raise exception using errcode = '23001', message = 'Lot event cannot be changed';
  end if;

  return new;
end;
$$;

drop trigger if exists lots_event_immutable on public.lots;
create trigger lots_event_immutable
  before update on public.lots
  for each row execute function public.prevent_lot_event_change();

revoke all on function public.prevent_lot_event_change() from public;

drop policy if exists ledger_entries_insert_finance on public.ledger_entries;
create policy ledger_entries_insert_finance
  on public.ledger_entries for insert to authenticated
  with check (
    public.has_event_role(event_id, array['owner', 'finance']::public.organization_role[])
    and public.is_org_member(organization_id)
    and created_by = (select auth.uid())
    and status = 'previsto'
    and approved_by is null
    and paid_at is null
    and exists (
      select 1
      from public.events event_record
      where event_record.id = event_id
        and event_record.status <> 'prestacao_contas_fechada'
    )
  );

create or replace function public.prevent_ledger_write_after_settlement()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  event_status public.event_status;
begin
  select status
  into event_status
  from public.events
  where id = new.event_id
  for update;

  if event_status = 'prestacao_contas_fechada' then
    raise exception using errcode = '23514', message = 'Ledger is closed for this event';
  end if;

  return new;
end;
$$;

drop trigger if exists ledger_entries_require_open_event on public.ledger_entries;
create trigger ledger_entries_require_open_event
  before insert or update on public.ledger_entries
  for each row execute function public.prevent_ledger_write_after_settlement();

revoke all on function public.prevent_ledger_write_after_settlement() from public;

create or replace function public.guard_order_confirmation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  event_status public.event_status;
  order_items_total bigint;
  target_lot_id bigint;
  lot_capacity integer;
  lot_sales_start_at timestamptz;
  lot_sales_end_at timestamptz;
  current_order_lot_quantity bigint;
  confirmed_lot_quantity bigint;
begin
  if new.status <> 'confirmed' or old.status = 'confirmed' then
    return new;
  end if;

  select status
  into event_status
  from public.events
  where id = new.event_id
  for update;

  if event_status <> 'vendas_abertas' then
    raise exception using errcode = '23514', message = 'Event is not open for sales';
  end if;

  select coalesce(sum(item.subtotal_cents), 0)
  into order_items_total
  from public.order_items item
  where item.order_id = new.id;

  if order_items_total <> new.total_cents then
    raise exception using errcode = '23514', message = 'Order total does not match its items';
  end if;

  for target_lot_id in
    select distinct item.lot_id
    from public.order_items item
    where item.order_id = new.id
    order by item.lot_id
  loop
    select lot.capacity, lot.sales_start_at, lot.sales_end_at
    into lot_capacity, lot_sales_start_at, lot_sales_end_at
    from public.lots lot
    where lot.id = target_lot_id
    for update;

    if (lot_sales_start_at is not null and now() < lot_sales_start_at)
      or (lot_sales_end_at is not null and now() > lot_sales_end_at) then
      raise exception using errcode = '23514', message = 'Lot is outside its sales window';
    end if;

    if lot_capacity is null then
      continue;
    end if;

    select coalesce(sum(item.quantity), 0)
    into current_order_lot_quantity
    from public.order_items item
    where item.order_id = new.id
      and item.lot_id = target_lot_id;

    select coalesce(sum(item.quantity), 0)
    into confirmed_lot_quantity
    from public.order_items item
    join public.orders order_record on order_record.id = item.order_id
    where item.lot_id = target_lot_id
      and order_record.status = 'confirmed';

    if confirmed_lot_quantity + current_order_lot_quantity > lot_capacity then
      raise exception using errcode = '23514', message = 'Lot capacity exceeded';
    end if;
  end loop;

  return new;
end;
$$;

drop trigger if exists orders_guard_confirmation on public.orders;
create trigger orders_guard_confirmation
  before update of status on public.orders
  for each row execute function public.guard_order_confirmation();

revoke all on function public.guard_order_confirmation() from public;

create or replace function public.assign_ticket_public_code()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.public_code := replace(gen_random_uuid()::text, '-', '');
  return new;
end;
$$;

drop trigger if exists a_tickets_assign_public_code on public.tickets;
create trigger a_tickets_assign_public_code
  before insert on public.tickets
  for each row execute function public.assign_ticket_public_code();

revoke all on function public.assign_ticket_public_code() from public;

create or replace function public.guard_ticket_issuance_lifecycle()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  order_event_id bigint;
  order_status public.order_status;
  event_status public.event_status;
begin
  select order_record.event_id, order_record.status, event_record.status
  into order_event_id, order_status, event_status
  from public.order_items item
  join public.orders order_record on order_record.id = item.order_id
  join public.events event_record on event_record.id = order_record.event_id
  where item.id = new.order_item_id
  for update of order_record, event_record, item;

  if order_event_id is null then
    raise exception using errcode = '23503', message = 'Order item not found';
  end if;

  if order_status <> 'confirmed' then
    raise exception using errcode = '23514', message = 'Tickets require a confirmed order';
  end if;

  if event_status <> 'vendas_abertas' then
    raise exception using errcode = '23514', message = 'Tickets require an event open for sales';
  end if;

  return new;
end;
$$;

drop trigger if exists a_tickets_guard_lifecycle on public.tickets;
create trigger a_tickets_guard_lifecycle
  before insert or update of order_item_id on public.tickets
  for each row execute function public.guard_ticket_issuance_lifecycle();

revoke all on function public.guard_ticket_issuance_lifecycle() from public;

create or replace function public.guard_check_in_eligibility()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  ticket_event_id bigint;
  ticket_order_id bigint;
  order_status public.order_status;
  event_status public.event_status;
begin
  select ticket.event_id, item.order_id
  into ticket_event_id, ticket_order_id
  from public.tickets ticket
  join public.order_items item on item.id = ticket.order_item_id
  where ticket.id = new.ticket_id;

  if ticket_event_id is null or new.event_id <> ticket_event_id then
    raise exception using errcode = '23514', message = 'Check-in event does not match ticket event';
  end if;

  select status
  into order_status
  from public.orders
  where id = ticket_order_id
  for update;

  select status
  into event_status
  from public.events
  where id = ticket_event_id
  for update;

  if order_status <> 'confirmed' then
    raise exception using errcode = '23514', message = 'Check-in requires a confirmed order';
  end if;

  if event_status <> 'vendas_abertas' then
    raise exception using errcode = '23514', message = 'Check-in requires an event open for sales';
  end if;

  return new;
end;
$$;

drop trigger if exists check_ins_guard_eligibility on public.check_ins;
create trigger check_ins_guard_eligibility
  before insert on public.check_ins
  for each row execute function public.guard_check_in_eligibility();

revoke all on function public.guard_check_in_eligibility() from public;

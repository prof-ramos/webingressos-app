-- Close the remaining direct-write paths around orders, finance and check-in.

drop policy if exists orders_insert_operator on public.orders;
create policy orders_insert_operator
  on public.orders for insert to authenticated
  with check (
    public.has_event_role(event_id, array['owner', 'ops']::public.organization_role[])
    and created_by = (select auth.uid())
    and status = 'pending'
  );

drop policy if exists order_items_insert_operator on public.order_items;
create policy order_items_insert_operator
  on public.order_items for insert to authenticated
  with check (
    exists (
      select 1
      from public.orders order_record
      join public.lots lot on lot.id = lot_id
      where order_record.id = order_id
        and order_record.status = 'pending'
        and order_record.event_id = lot.event_id
        and public.has_event_role(order_record.event_id, array['owner', 'ops']::public.organization_role[])
    )
  );

revoke update, delete on public.order_items from authenticated;

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
  where id = new.order_id;

  if current_order_status is distinct from 'pending' then
    raise exception using errcode = '23514', message = 'Order items require a pending order';
  end if;

  return new;
end;
$$;

drop trigger if exists order_items_require_pending_order on public.order_items;
create trigger order_items_require_pending_order
  before insert or update on public.order_items
  for each row execute function public.prevent_order_item_write_after_confirmation();

revoke all on function public.prevent_order_item_write_after_confirmation() from public;

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
  );

create or replace function public.transition_order_status(
  target_order_id bigint,
  requested_status public.order_status,
  transition_reason text default null
)
returns public.orders
language plpgsql
security definer
set search_path = public
as $$
declare
  current_order public.orders;
  changed_order public.orders;
  order_items_total bigint;
  target_lot_id bigint;
  lot_capacity integer;
  current_order_lot_quantity bigint;
  confirmed_lot_quantity bigint;
begin
  if (select auth.uid()) is null then
    raise exception using errcode = '42501', message = 'Authentication required';
  end if;

  select *
  into current_order
  from public.orders
  where id = target_order_id
  for update;

  if not found then
    raise exception using errcode = 'P0002', message = 'Order not found';
  end if;

  if not public.has_event_role(
    current_order.event_id,
    array['owner', 'ops']::public.organization_role[]
  ) then
    raise exception using errcode = '42501', message = 'Not authorized to change this order';
  end if;

  if current_order.status = requested_status then
    return current_order;
  end if;

  if requested_status in ('cancelled', 'refunded')
    and nullif(trim(transition_reason), '') is null then
    raise exception using errcode = '22023', message = 'Cancellation requires a reason';
  end if;

  if not (
    (current_order.status = 'pending' and requested_status in ('confirmed', 'cancelled'))
    or (current_order.status = 'confirmed' and requested_status in ('cancelled', 'refunded'))
  ) then
    raise exception using errcode = '22023', message = 'Invalid order status transition';
  end if;

  if requested_status = 'confirmed' then
    select coalesce(sum(item.subtotal_cents), 0)
    into order_items_total
    from public.order_items item
    where item.order_id = current_order.id;

    if order_items_total <> current_order.total_cents then
      raise exception using errcode = '23514', message = 'Order total does not match its items';
    end if;

    for target_lot_id in
      select distinct item.lot_id
      from public.order_items item
      where item.order_id = current_order.id
      order by item.lot_id
    loop
      select lot.capacity
      into lot_capacity
      from public.lots lot
      where lot.id = target_lot_id
      for update;

      if lot_capacity is null then
        continue;
      end if;

      select coalesce(sum(item.quantity), 0)
      into current_order_lot_quantity
      from public.order_items item
      where item.order_id = current_order.id
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
  end if;

  update public.orders
  set status = requested_status
  where id = current_order.id
  returning * into changed_order;

  insert into public.audit_logs (
    organization_id,
    event_id,
    actor_user_id,
    entity_type,
    entity_public_id,
    action,
    reason,
    metadata
  )
  select
    event_record.organization_id,
    changed_order.event_id,
    (select auth.uid()),
    'order',
    changed_order.public_id::text,
    'order.status_changed',
    nullif(trim(transition_reason), ''),
    jsonb_build_object('from', current_order.status, 'to', changed_order.status)
  from public.events event_record
  where event_record.id = changed_order.event_id;

  return changed_order;
end;
$$;

create or replace function public.transition_ledger_entry_status(
  target_ledger_entry_id bigint,
  requested_status public.ledger_entry_status,
  transition_reason text default null
)
returns public.ledger_entries
language plpgsql
security definer
set search_path = public
as $$
declare
  current_entry public.ledger_entries;
  changed_entry public.ledger_entries;
begin
  if (select auth.uid()) is null then
    raise exception using errcode = '42501', message = 'Authentication required';
  end if;

  select *
  into current_entry
  from public.ledger_entries
  where id = target_ledger_entry_id
  for update;

  if not found then
    raise exception using errcode = 'P0002', message = 'Ledger entry not found';
  end if;

  if not public.has_event_role(
    current_entry.event_id,
    array['owner', 'finance']::public.organization_role[]
  ) then
    raise exception using errcode = '42501', message = 'Not authorized to change this ledger entry';
  end if;

  if current_entry.status = requested_status then
    return current_entry;
  end if;

  if not (
    (current_entry.status = 'previsto' and requested_status = 'aprovado')
    or (current_entry.status = 'aprovado' and requested_status = 'pago')
  ) then
    raise exception using errcode = '22023', message = 'Invalid ledger status transition';
  end if;

  update public.ledger_entries
  set
    status = requested_status,
    approved_by = case
      when requested_status in ('aprovado', 'pago') then coalesce(approved_by, (select auth.uid()))
      else approved_by
    end,
    paid_at = case
      when requested_status = 'pago' then coalesce(paid_at, now())
      else paid_at
    end
  where id = current_entry.id
  returning * into changed_entry;

  insert into public.audit_logs (
    organization_id,
    event_id,
    actor_user_id,
    entity_type,
    entity_public_id,
    action,
    reason,
    metadata
  )
  values (
    changed_entry.organization_id,
    changed_entry.event_id,
    (select auth.uid()),
    'ledger_entry',
    changed_entry.public_id::text,
    'ledger.status_changed',
    nullif(trim(transition_reason), ''),
    jsonb_build_object('from', current_entry.status, 'to', changed_entry.status)
  );

  return changed_entry;
end;
$$;

revoke all on function public.transition_ledger_entry_status(bigint, public.ledger_entry_status, text) from public;
grant execute on function public.transition_ledger_entry_status(bigint, public.ledger_entry_status, text) to authenticated;

create or replace function public.validate_ticket_issuance()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  item_event_id bigint;
  order_event_id bigint;
  lot_event_id bigint;
  item_quantity integer;
  current_order_status public.order_status;
  issued_quantity bigint;
  excluded_ticket_id bigint;
begin
  if tg_op = 'INSERT' then
    new.public_code := replace(gen_random_uuid()::text, '-', '');
  else
    excluded_ticket_id := old.id;
  end if;

  select
    item.quantity,
    order_record.event_id,
    order_record.status,
    lot.event_id
  into
    item_quantity,
    order_event_id,
    current_order_status,
    lot_event_id
  from public.order_items item
  join public.orders order_record on order_record.id = item.order_id
  join public.lots lot on lot.id = item.lot_id
  where item.id = new.order_item_id
  for update of item;

  if not found then
    raise exception using errcode = '23503', message = 'Order item not found';
  end if;

  select event_record.id
  into item_event_id
  from public.events event_record
  where event_record.id = new.event_id;

  if item_event_id is null
    or new.event_id <> order_event_id
    or new.event_id <> lot_event_id then
    raise exception using errcode = '23514', message = 'Ticket event does not match its order item';
  end if;

  if current_order_status <> 'confirmed' then
    raise exception using errcode = '23514', message = 'Tickets require a confirmed order';
  end if;

  select count(*)
  into issued_quantity
  from public.tickets ticket
  where ticket.order_item_id = new.order_item_id
    and (excluded_ticket_id is null or ticket.id <> excluded_ticket_id);

  if issued_quantity >= item_quantity then
    raise exception using errcode = '23514', message = 'Ticket quantity exceeds the order item quantity';
  end if;

  return new;
end;
$$;

revoke all on function public.validate_ticket_issuance() from public;

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

  if ticket_record.event_status <> 'vendas_abertas' then
    return query select 'invalid', 'event_not_open', ticket_record.public_id, null::timestamptz;
    return;
  end if;

  if ticket_record.order_status <> 'confirmed' then
    return query select 'invalid', 'order_not_confirmed', ticket_record.public_id, null::timestamptz;
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

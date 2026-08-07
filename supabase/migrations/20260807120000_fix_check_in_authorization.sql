-- Apply the check-in privacy fix to databases that already ran the UUID migration.
-- Keeping this as a new migration ensures deployed environments receive the change.

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
set search_path = ''
as $$
declare
  ticket_record record;
  existing_check_in timestamptz;
  inserted_check_in timestamptz;
begin
  select
    ticket.id,
    ticket.event_id,
    ticket.organization_id,
    event_record.id as event_public_id,
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
    -- Keep inaccessible and nonexistent codes indistinguishable. In particular,
    -- do not reveal a ticket UUID before the scanner is authorized for its event.
    return query select 'invalid', 'not_found', null::uuid, null::timestamptz;
    return;
  end if;

  if ticket_record.event_public_id is distinct from target_event_public_id then
    return query select 'invalid', 'wrong_event', null::uuid, null::timestamptz;
    return;
  end if;

  if ticket_record.event_status = 'cancelado'
    or ticket_record.order_status in ('cancelled', 'refunded') then
    return query select 'invalid', 'cancelled', ticket_record.id, null::timestamptz;
    return;
  end if;

  if ticket_record.order_status <> 'confirmed' then
    return query select 'invalid', 'not_confirmed', ticket_record.id, null::timestamptz;
    return;
  end if;

  select check_in.checked_in_at
  into existing_check_in
  from public.check_ins check_in
  where check_in.ticket_id = ticket_record.id
  for update;

  if existing_check_in is not null then
    return query select 'already_checked_in', null, ticket_record.id, existing_check_in;
    return;
  end if;

  insert into public.check_ins (ticket_id, event_id, organization_id, checked_by, device_label)
  values (
    ticket_record.id,
    ticket_record.event_id,
    ticket_record.organization_id,
    (select auth.uid()),
    scanner_device_label
  )
  on conflict (ticket_id) do nothing
  returning check_ins.checked_in_at into inserted_check_in;

  if inserted_check_in is not null then
    return query select 'accepted', null, ticket_record.id, inserted_check_in;
    return;
  end if;

  select check_in.checked_in_at
  into existing_check_in
  from public.check_ins check_in
  where check_in.ticket_id = ticket_record.id;

  return query select 'already_checked_in', null, ticket_record.id, existing_check_in;
end;
$$;

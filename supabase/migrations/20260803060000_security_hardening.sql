-- Security hardening for authorization boundaries, ticket integrity and audit writes.

-- SECURITY DEFINER functions must not inherit a caller-controlled search_path.
alter function public.is_org_member(bigint) set search_path = '';
alter function public.has_org_role(bigint, public.organization_role[]) set search_path = '';
alter function public.can_access_event(bigint) set search_path = '';
alter function public.create_organization(text) set search_path = '';

-- Owners of collaborator organizations may operate only through an explicit
-- collaborator role; ownership of the event remains with events.organization_id.
create or replace function public.has_event_role(
  target_event_id bigint,
  allowed_roles public.organization_role[]
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.events event_record
    join public.organization_memberships membership
      on membership.organization_id = event_record.organization_id
    where event_record.id = target_event_id
      and membership.user_id = (select auth.uid())
      and membership.role = any (allowed_roles)
  )
  or exists (
    select 1
    from public.event_organizations event_organization
    join public.organization_memberships membership
      on membership.organization_id = event_organization.organization_id
    where event_organization.event_id = target_event_id
      and membership.user_id = (select auth.uid())
      and membership.role <> 'owner'
      and membership.role = any (allowed_roles)
  );
$$;

revoke all on function public.has_event_role(bigint, public.organization_role[]) from public;
grant execute on function public.has_event_role(bigint, public.organization_role[]) to authenticated;

create or replace function public.prevent_event_ownership_change()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.organization_id is distinct from old.organization_id
    or new.created_by is distinct from old.created_by then
    raise exception using
      errcode = '42501',
      message = 'Event ownership fields are immutable';
  end if;

  return new;
end;
$$;

drop trigger if exists events_ownership_immutable on public.events;
create trigger events_ownership_immutable
  before update on public.events
  for each row
  execute function public.prevent_event_ownership_change();

create or replace function public.validate_ticket_event()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (
    select 1
    from public.order_items item
    join public.orders order_record on order_record.id = item.order_id
    where item.id = new.order_item_id
      and order_record.event_id = new.event_id
  ) then
    raise exception using
      errcode = '23514',
      message = 'Ticket event must match order item event';
  end if;

  return new;
end;
$$;

revoke all on function public.validate_ticket_event() from public;
drop trigger if exists tickets_event_consistency on public.tickets;
create trigger tickets_event_consistency
  before insert or update of order_item_id, event_id on public.tickets
  for each row
  execute function public.validate_ticket_event();

-- There is no update policy for tickets; keep the table read-only to clients.
revoke update on public.tickets from authenticated;

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

  if ticket_record.event_public_id <> target_event_public_id then
    return query select 'invalid', 'wrong_event', ticket_record.public_id, null::timestamptz;
    return;
  end if;

  if not public.has_event_role(ticket_record.event_id, array['owner', 'ops', 'gate']::public.organization_role[]) then
    return query select 'invalid', 'not_authorized', null::uuid, null::timestamptz;
    return;
  end if;

  if ticket_record.event_status = 'cancelado'
    or ticket_record.order_status in ('cancelled', 'refunded') then
    return query select 'invalid', 'cancelled', ticket_record.public_id, null::timestamptz;
    return;
  end if;

  if ticket_record.order_status <> 'confirmed' then
    return query select 'invalid', 'not_confirmed', ticket_record.public_id, null::timestamptz;
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

-- Audit records are created by the database so actor and timestamp cannot be forged.
drop policy if exists audit_logs_insert_member on public.audit_logs;
revoke insert on public.audit_logs from authenticated;

create or replace function public.record_audit_log(
  target_organization_id bigint,
  target_event_id bigint,
  target_entity_type text,
  target_entity_public_id text,
  target_action text,
  target_reason text default null,
  target_metadata jsonb default '{}'::jsonb
)
returns public.audit_logs
language plpgsql
security definer
set search_path = ''
as $$
declare
  created_log public.audit_logs;
  event_organization_id bigint;
begin
  if (select auth.uid()) is null then
    raise exception using errcode = '42501', message = 'Authentication required';
  end if;

  if target_event_id is null then
    if not public.is_org_member(target_organization_id) then
      raise exception using errcode = '42501', message = 'Not authorized to audit organization';
    end if;
  else
    select event_record.organization_id
    into event_organization_id
    from public.events event_record
    where event_record.id = target_event_id;

    if event_organization_id is null
      or not public.can_access_event(target_event_id)
      or event_organization_id <> target_organization_id then
      raise exception using errcode = '42501', message = 'Not authorized to audit event';
    end if;
  end if;

  insert into public.audit_logs (
    organization_id,
    event_id,
    actor_user_id,
    entity_type,
    entity_public_id,
    action,
    reason,
    metadata,
    occurred_at
  )
  values (
    target_organization_id,
    target_event_id,
    (select auth.uid()),
    target_entity_type,
    target_entity_public_id,
    target_action,
    target_reason,
    coalesce(target_metadata, '{}'::jsonb),
    now()
  )
  returning * into created_log;

  return created_log;
end;
$$;

revoke all on function public.record_audit_log(bigint, bigint, text, text, text, text, jsonb) from public;
grant execute on function public.record_audit_log(bigint, bigint, text, text, text, text, jsonb) to authenticated;

-- Keep identity inserts working while avoiding access to arbitrary future sequences.
revoke usage on all sequences in schema public from authenticated;
grant usage on sequence
  public.organizations_id_seq,
  public.organization_memberships_id_seq,
  public.events_id_seq,
  public.event_organizations_id_seq,
  public.event_status_history_id_seq,
  public.lots_id_seq,
  public.promoters_id_seq,
  public.orders_id_seq,
  public.order_items_id_seq,
  public.tickets_id_seq,
  public.check_ins_id_seq,
  public.ledger_entries_id_seq,
  public.audit_logs_id_seq
  to authenticated;

create index if not exists ledger_entries_created_by_idx
  on public.ledger_entries (created_by);
create index if not exists ledger_entries_approved_by_idx
  on public.ledger_entries (approved_by);
create index if not exists audit_logs_actor_user_id_idx
  on public.audit_logs (actor_user_id);

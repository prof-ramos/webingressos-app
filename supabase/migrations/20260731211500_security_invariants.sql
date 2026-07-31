-- Harden tenant ownership, lifecycle transitions, ticket issuance and audit boundaries.

create or replace function public.has_event_role(
  target_event_id bigint,
  allowed_roles public.organization_role[]
)
returns boolean
language sql
stable
security definer
set search_path = public
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
      and event_organization.role = 'collaborator'
      and membership.user_id = (select auth.uid())
      and membership.role = any (allowed_roles)
      and membership.role <> 'owner'
  );
$$;

create or replace function public.prevent_event_organization_change()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.organization_id is distinct from old.organization_id then
    raise exception using
      errcode = '23001',
      message = 'Event organization cannot be changed';
  end if;

  return new;
end;
$$;

create trigger events_organization_immutable
  before update on public.events
  for each row execute function public.prevent_event_organization_change();

drop policy if exists events_insert_operator on public.events;
create policy events_insert_operator
  on public.events for insert to authenticated
  with check (
    public.has_org_role(organization_id, array['owner', 'ops']::public.organization_role[])
    and created_by = (select auth.uid())
    and status = 'rascunho'
  );

drop policy if exists events_update_operator on public.events;
revoke update on public.events from authenticated;

create or replace function public.record_event_creation_status()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.event_status_history (
    event_id,
    from_status,
    to_status,
    actor_user_id,
    reason
  )
  values (new.id, null, new.status, new.created_by, 'event_created');

  return new;
end;
$$;

create trigger events_status_history_on_create
  after insert on public.events
  for each row execute function public.record_event_creation_status();

drop policy if exists event_status_history_insert_operator on public.event_status_history;
revoke insert, update, delete on public.event_status_history from authenticated;

create or replace function public.transition_event_status(
  target_event_id bigint,
  requested_status public.event_status,
  transition_reason text default null
)
returns public.events
language plpgsql
security definer
set search_path = public
as $$
declare
  current_event public.events;
  changed_event public.events;
begin
  if (select auth.uid()) is null then
    raise exception using errcode = '42501', message = 'Authentication required';
  end if;

  select *
  into current_event
  from public.events
  where id = target_event_id
  for update;

  if not found then
    raise exception using errcode = 'P0002', message = 'Event not found';
  end if;

  if not public.has_event_role(
    current_event.id,
    array['owner', 'ops']::public.organization_role[]
  ) then
    raise exception using errcode = '42501', message = 'Not authorized to change this event';
  end if;

  if current_event.status = requested_status then
    return current_event;
  end if;

  if requested_status = 'cancelado'
    and nullif(trim(transition_reason), '') is null then
    raise exception using errcode = '22023', message = 'Cancellation requires a reason';
  end if;

  if not (
    (current_event.status = 'rascunho' and requested_status in ('planejado', 'cancelado'))
    or (current_event.status = 'planejado' and requested_status in ('vendas_abertas', 'cancelado'))
    or (current_event.status = 'vendas_abertas' and requested_status in ('encerrado', 'cancelado'))
    or (current_event.status = 'encerrado' and requested_status = 'prestacao_contas_fechada')
  ) then
    raise exception using
      errcode = '22023',
      message = 'Invalid event status transition';
  end if;

  update public.events
  set status = requested_status
  where id = current_event.id
  returning * into changed_event;

  insert into public.event_status_history (
    event_id,
    from_status,
    to_status,
    actor_user_id,
    reason
  )
  values (
    changed_event.id,
    current_event.status,
    changed_event.status,
    (select auth.uid()),
    nullif(trim(transition_reason), '')
  );

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
    changed_event.organization_id,
    changed_event.id,
    (select auth.uid()),
    'event',
    changed_event.public_id::text,
    'event.status_changed',
    nullif(trim(transition_reason), ''),
    jsonb_build_object('from', current_event.status, 'to', changed_event.status)
  );

  return changed_event;
end;
$$;

revoke all on function public.transition_event_status(bigint, public.event_status, text) from public;
grant execute on function public.transition_event_status(bigint, public.event_status, text) to authenticated;

drop policy if exists orders_select_member on public.orders;
create policy orders_select_operator
  on public.orders for select to authenticated
  using (
    public.has_event_role(event_id, array['owner', 'ops', 'finance']::public.organization_role[])
  );

drop policy if exists order_items_select_member on public.order_items;
create policy order_items_select_operator
  on public.order_items for select to authenticated
  using (
    exists (
      select 1
      from public.orders order_record
      where order_record.id = order_id
        and public.has_event_role(
          order_record.event_id,
          array['owner', 'ops', 'finance']::public.organization_role[]
        )
    )
  );

drop policy if exists orders_update_operator on public.orders;
revoke update, delete on public.orders from authenticated;

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

revoke all on function public.transition_order_status(bigint, public.order_status, text) from public;
grant execute on function public.transition_order_status(bigint, public.order_status, text) to authenticated;

alter table public.promoters
  add constraint promoters_id_event_key unique (id, event_id);

alter table public.orders
  add constraint orders_promoter_event_fkey
  foreign key (promoter_id, event_id)
  references public.promoters (id, event_id);

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
  if tg_op = 'UPDATE' then
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

create trigger tickets_validate_issuance
  before insert or update of order_item_id, event_id on public.tickets
  for each row execute function public.validate_ticket_issuance();

revoke update, delete on public.tickets from authenticated;

alter table public.events
  add constraint events_id_organization_key unique (id, organization_id);

alter table public.ledger_entries
  add constraint ledger_entries_event_organization_fkey
  foreign key (event_id, organization_id)
  references public.events (id, organization_id);

alter table public.ledger_entries
  add constraint ledger_entries_approved_status_fields_check
  check (status = 'previsto' or approved_by is not null);

alter table public.ledger_entries
  add constraint ledger_entries_paid_status_fields_check
  check (status <> 'pago' or (approved_by is not null and paid_at is not null));

drop policy if exists audit_logs_insert_member on public.audit_logs;
revoke insert, update, delete on public.audit_logs from authenticated;

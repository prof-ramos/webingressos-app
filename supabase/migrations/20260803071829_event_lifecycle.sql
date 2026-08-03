-- Keep event status changes and their history in one trusted transaction.

create or replace function public.is_event_status_transition_allowed(
  current_status public.event_status,
  target_status public.event_status
)
returns boolean
language sql
immutable
security definer
set search_path = ''
as $$
  select case current_status
    when 'rascunho' then target_status = any (array['planejado', 'cancelado']::public.event_status[])
    when 'planejado' then target_status = any (array['vendas_abertas', 'cancelado']::public.event_status[])
    when 'vendas_abertas' then target_status = any (array['encerrado', 'cancelado']::public.event_status[])
    when 'encerrado' then target_status = any (array['prestacao_contas_fechada', 'cancelado']::public.event_status[])
    when 'prestacao_contas_fechada' then false
    when 'cancelado' then false
    else false
  end;
$$;

revoke all on function public.is_event_status_transition_allowed(
  public.event_status,
  public.event_status
) from public, authenticated;

create or replace function public.transition_event(
  target_event_public_id uuid,
  target_to_status public.event_status,
  target_reason text default null
)
returns table (
  public_id uuid,
  status public.event_status
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  locked_event public.events%rowtype;
  previous_status public.event_status;
  transition_reason text;
  transition_at timestamptz;
  returned_public_id uuid;
  returned_status public.event_status;
begin
  if (select auth.uid()) is null then
    raise exception using
      errcode = '42501',
      message = 'Authentication required';
  end if;

  select event_row.*
  into locked_event
  from public.events as event_row
  where event_row.public_id = target_event_public_id
  for update;

  if not found then
    raise exception using
      errcode = '42501',
      message = 'Not authorized to transition event';
  end if;

  if not public.has_event_role(
    locked_event.id,
    array['owner', 'ops']::public.organization_role[]
  ) then
    raise exception using
      errcode = '42501',
      message = 'Not authorized to transition event';
  end if;

  if target_to_status is null
    or not public.is_event_status_transition_allowed(locked_event.status, target_to_status) then
    raise exception using
      errcode = '22023',
      message = 'Invalid event status transition';
  end if;

  transition_reason := nullif(trim(coalesce(target_reason, '')), '');

  if target_to_status in ('cancelado', 'prestacao_contas_fechada')
    and transition_reason is null then
    raise exception using
      errcode = '22023',
      message = 'Reason required for event status transition';
  end if;

  previous_status := locked_event.status;
  transition_at := now();

  update public.events as event_row
  set status = target_to_status
  where id = locked_event.id
  returning event_row.public_id, event_row.status into returned_public_id, returned_status;

  insert into public.event_status_history (
    event_id,
    from_status,
    to_status,
    actor_user_id,
    reason,
    occurred_at
  )
  values (
    locked_event.id,
    previous_status,
    target_to_status,
    (select auth.uid()),
    transition_reason,
    transition_at
  );

  return query select returned_public_id, returned_status;
end;
$$;

revoke all on function public.transition_event(uuid, public.event_status, text) from public;
grant execute on function public.transition_event(uuid, public.event_status, text) to authenticated;

create or replace function public.record_event_initial_history()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.event_status_history (
    event_id,
    from_status,
    to_status,
    actor_user_id,
    occurred_at
  )
  values (
    new.id,
    null,
    new.status,
    new.created_by,
    new.created_at
  );

  return new;
end;
$$;

revoke all on function public.record_event_initial_history() from public, authenticated;

drop trigger if exists events_initial_status_history on public.events;
create trigger events_initial_status_history
  after insert on public.events
  for each row
  execute function public.record_event_initial_history();

drop policy if exists events_insert_operator on public.events;
create policy events_insert_operator
  on public.events for insert to authenticated
  with check (
    public.has_org_role(organization_id, array['owner', 'ops']::public.organization_role[])
    and created_by = (select auth.uid())
    and status = 'rascunho'
  );

drop policy if exists event_status_history_insert_operator on public.event_status_history;
revoke insert, update, delete on table public.event_status_history from public, authenticated;

revoke update on table public.events from public, authenticated;
grant update (name, starts_at, ends_at) on table public.events to authenticated;

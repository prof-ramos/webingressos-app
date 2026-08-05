-- Close lifecycle gaps identified by the application foundation specification.

create or replace function public.guard_event_complete_ticket_issuance()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  has_incomplete_issuance boolean;
begin
  if old.status <> 'vendas_abertas'
    or new.status not in ('encerrado', 'cancelado') then
    return new;
  end if;

  select exists (
    select 1
    from public.order_items item
    join public.orders order_record on order_record.id = item.order_id
    left join public.tickets ticket on ticket.order_item_id = item.id
    where order_record.event_id = new.id
      and order_record.status = 'confirmed'
    group by item.id, item.quantity
    having count(ticket.id) < item.quantity
  )
  into has_incomplete_issuance;

  if has_incomplete_issuance then
    raise exception using
      errcode = '23514',
      message = 'Confirmed orders require complete ticket issuance';
  end if;

  return new;
end;
$$;

drop trigger if exists events_require_complete_ticket_issuance on public.events;
create trigger events_require_complete_ticket_issuance
  before update of status on public.events
  for each row execute function public.guard_event_complete_ticket_issuance();

revoke all on function public.guard_event_complete_ticket_issuance() from public;
revoke all on function public.guard_event_complete_ticket_issuance() from anon;
revoke all on function public.guard_event_complete_ticket_issuance() from authenticated;

create or replace function public.guard_order_status_after_settlement()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  event_status public.event_status;
begin
  if new.status = old.status then
    return new;
  end if;

  select status
  into event_status
  from public.events
  where id = new.event_id
  for update;

  if event_status = 'prestacao_contas_fechada' then
    raise exception using
      errcode = '23514',
      message = 'Order status is locked after settlement';
  end if;

  return new;
end;
$$;

drop trigger if exists a_orders_guard_settlement on public.orders;
create trigger a_orders_guard_settlement
  before update of status on public.orders
  for each row execute function public.guard_order_status_after_settlement();

revoke all on function public.guard_order_status_after_settlement() from public;
revoke all on function public.guard_order_status_after_settlement() from anon;
revoke all on function public.guard_order_status_after_settlement() from authenticated;

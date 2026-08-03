-- Keep customer details out of the general operational order surface.

create view public.orders_operational
with (security_invoker = true)
as
select
  order_record.id,
  order_record.public_id,
  order_record.event_id,
  order_record.promoter_id,
  order_record.status,
  order_record.total_cents,
  order_record.currency,
  order_record.created_by,
  order_record.created_at
from public.orders as order_record;

revoke select on table public.orders from public, authenticated;
grant select (
  id,
  public_id,
  event_id,
  promoter_id,
  status,
  total_cents,
  currency,
  created_by,
  created_at
) on table public.orders to authenticated;
grant select on table public.orders_operational to authenticated;

create or replace function public.get_order_customer(target_order_public_id uuid)
returns table (
  order_public_id uuid,
  buyer_name text,
  buyer_email text,
  buyer_phone text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  order_record public.orders%rowtype;
begin
  if (select auth.uid()) is null then
    raise exception using
      errcode = '42501',
      message = 'Not authorized to access order';
  end if;

  select source_order.*
  into order_record
  from public.orders as source_order
  where source_order.public_id = target_order_public_id;

  if not found then
    raise exception using
      errcode = '42501',
      message = 'Not authorized to access order';
  end if;

  if not public.has_event_role(
    order_record.event_id,
    array['owner', 'ops', 'finance']::public.organization_role[]
  ) then
    raise exception using
      errcode = '42501',
      message = 'Not authorized to access order';
  end if;

  return query
  select
    order_record.public_id,
    order_record.buyer_name,
    order_record.buyer_email,
    order_record.buyer_phone;
end;
$$;

revoke all on function public.get_order_customer(uuid) from public;
grant execute on function public.get_order_customer(uuid) to authenticated;

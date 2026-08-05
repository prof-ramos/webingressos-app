begin;

set local role postgres;
set local search_path = extensions, public;

create extension if not exists pgtap with schema extensions;

select extensions.plan(4);

insert into auth.users (id, email)
values ('00000000-0000-4000-8000-0000000000a5', 'foundation-blockers@example.invalid');

insert into public.organizations (name)
values ('Foundation Blockers Test');

insert into public.organization_memberships (organization_id, user_id, role)
select id, '00000000-0000-4000-8000-0000000000a5', 'owner'
from public.organizations
where name = 'Foundation Blockers Test';

select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-0000000000a5',
  true
);

insert into public.events (organization_id, name, status, created_by)
select id, 'Emissão incompleta', 'vendas_abertas', '00000000-0000-4000-8000-0000000000a5'
from public.organizations
where name = 'Foundation Blockers Test';

insert into public.lots (event_id, name, price_cents, capacity)
select id, 'Lote único', 1000, 10
from public.events
where name = 'Emissão incompleta';

insert into public.orders (event_id, total_cents, created_by)
select id, 2000, '00000000-0000-4000-8000-0000000000a5'
from public.events
where name = 'Emissão incompleta';

insert into public.order_items (order_id, lot_id, quantity, unit_price_cents, subtotal_cents)
select order_record.id, lot.id, 2, 1000, 2000
from public.orders order_record
join public.events event_record on event_record.id = order_record.event_id
join public.lots lot on lot.event_id = event_record.id
where event_record.name = 'Emissão incompleta';

update public.orders
set status = 'confirmed'
where id in (
  select order_record.id
  from public.orders order_record
  join public.events event_record on event_record.id = order_record.event_id
  where event_record.name = 'Emissão incompleta'
);

insert into public.tickets (order_item_id, event_id)
select item.id, event_record.id
from public.order_items item
join public.orders order_record on order_record.id = item.order_id
join public.events event_record on event_record.id = order_record.event_id
where event_record.name = 'Emissão incompleta';

select extensions.throws_ok(
  format(
    'select * from public.transition_event(''%s''::uuid, ''encerrado'', null)',
    event_record.public_id
  ),
  '23514',
  'Confirmed orders require complete ticket issuance',
  'evento não encerra com emissão incompleta'
)
from public.events event_record
where event_record.name = 'Emissão incompleta';

insert into public.tickets (order_item_id, event_id)
select item.id, event_record.id
from public.order_items item
join public.orders order_record on order_record.id = item.order_id
join public.events event_record on event_record.id = order_record.event_id
where event_record.name = 'Emissão incompleta';

select extensions.lives_ok(
  format(
    'select * from public.transition_event(''%s''::uuid, ''encerrado'', null)',
    event_record.public_id
  ),
  'evento encerra após a emissão completa'
)
from public.events event_record
where event_record.name = 'Emissão incompleta';

insert into public.events (organization_id, name, status, created_by)
select id, 'Prestação fechada', 'prestacao_contas_fechada', '00000000-0000-4000-8000-0000000000a5'
from public.organizations
where name = 'Foundation Blockers Test';

insert into public.orders (event_id, total_cents, created_by)
select id, 0, '00000000-0000-4000-8000-0000000000a5'
from public.events
where name = 'Prestação fechada';

select extensions.throws_ok(
  format(
    'update public.orders set status = ''cancelled'' where id = %s',
    order_record.id
  ),
  '23514',
  'Order status is locked after settlement',
  'pedido não muda após o fechamento da prestação de contas'
)
from public.orders order_record
join public.events event_record on event_record.id = order_record.event_id
where event_record.name = 'Prestação fechada';

insert into public.events (organization_id, name, status, created_by)
select id, 'Prestação aberta', 'vendas_abertas', '00000000-0000-4000-8000-0000000000a5'
from public.organizations
where name = 'Foundation Blockers Test';

insert into public.orders (event_id, total_cents, created_by)
select id, 0, '00000000-0000-4000-8000-0000000000a5'
from public.events
where name = 'Prestação aberta';

select extensions.lives_ok(
  format(
    'update public.orders set status = ''cancelled'' where id = %s',
    order_record.id
  ),
  'pedido ainda pode ser cancelado antes da prestação de contas fechar'
)
from public.orders order_record
join public.events event_record on event_record.id = order_record.event_id
where event_record.name = 'Prestação aberta';

select * from extensions.finish();
rollback;

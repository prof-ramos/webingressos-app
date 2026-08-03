begin;

select plan(12);

-- The fixtures are rolled back at the end of the test so this suite is safe to run
-- against a disposable local database.
insert into auth.users (id, aud, role, email, email_confirmed_at)
values
  ('00000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'owner-a@example.test', now()),
  ('00000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'owner-b@example.test', now()),
  ('00000000-0000-0000-0000-000000000003', 'authenticated', 'authenticated', 'gate-a@example.test', now()),
  ('00000000-0000-0000-0000-000000000004', 'authenticated', 'authenticated', 'finance-a@example.test', now());

insert into public.organizations (public_id, name)
values
  ('10000000-0000-0000-0000-000000000001', 'Organização A'),
  ('10000000-0000-0000-0000-000000000002', 'Organização B');

insert into public.organization_memberships (organization_id, user_id, role)
select id, '00000000-0000-0000-0000-000000000001', 'owner'
from public.organizations
where public_id = '10000000-0000-0000-0000-000000000001';

insert into public.organization_memberships (organization_id, user_id, role)
select id, '00000000-0000-0000-0000-000000000003', 'gate'
from public.organizations
where public_id = '10000000-0000-0000-0000-000000000001';

insert into public.organization_memberships (organization_id, user_id, role)
select id, '00000000-0000-0000-0000-000000000004', 'finance'
from public.organizations
where public_id = '10000000-0000-0000-0000-000000000001';

insert into public.organization_memberships (organization_id, user_id, role)
select id, '00000000-0000-0000-0000-000000000002', 'owner'
from public.organizations
where public_id = '10000000-0000-0000-0000-000000000002';

insert into public.events (public_id, organization_id, name, status, created_by)
select
  '20000000-0000-0000-0000-000000000001',
  id,
  'Evento A',
  'vendas_abertas',
  '00000000-0000-0000-0000-000000000001'
from public.organizations
where public_id = '10000000-0000-0000-0000-000000000001';

insert into public.events (public_id, organization_id, name, status, created_by)
select
  '20000000-0000-0000-0000-000000000002',
  id,
  'Evento B',
  'vendas_abertas',
  '00000000-0000-0000-0000-000000000002'
from public.organizations
where public_id = '10000000-0000-0000-0000-000000000002';

insert into public.lots (public_id, event_id, name, price_cents)
select '30000000-0000-0000-0000-000000000001', id, 'Lote A', 2500
from public.events
where public_id = '20000000-0000-0000-0000-000000000001';

insert into public.orders (public_id, event_id, status, total_cents, created_by)
select
  '40000000-0000-0000-0000-000000000001',
  id,
  'confirmed',
  2500,
  '00000000-0000-0000-0000-000000000001'
from public.events
where public_id = '20000000-0000-0000-0000-000000000001';

insert into public.order_items (order_id, lot_id, quantity, unit_price_cents, subtotal_cents)
select order_record.id, lot.id, 1, 2500, 2500
from public.orders order_record
join public.lots lot on lot.event_id = order_record.event_id
where order_record.public_id = '40000000-0000-0000-0000-000000000001';

insert into public.tickets (public_id, order_item_id, event_id, public_code)
select
  '50000000-0000-0000-0000-000000000001',
  item.id,
  order_record.event_id,
  'ticket-a-001'
from public.order_items item
join public.orders order_record on order_record.id = item.order_id
where order_record.public_id = '40000000-0000-0000-0000-000000000001';

insert into public.ledger_entries (
  organization_id,
  event_id,
  kind,
  amount_cents,
  description,
  created_by
)
select
  event_record.organization_id,
  event_record.id,
  'revenue',
  2500,
  'Venda de teste',
  '00000000-0000-0000-0000-000000000001'
from public.events event_record
where event_record.public_id = '20000000-0000-0000-0000-000000000001';

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000001', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

select is(
  (select count(*)::int from public.organizations),
  1,
  'membro vê apenas a própria organização'
);

select is(
  (select count(*)::int from public.events),
  1,
  'membro vê apenas eventos da própria organização'
);

select is(
  (select count(*)::int from public.tickets),
  1,
  'owner consegue consultar ingressos do próprio evento'
);

select is(
  (select count(*)::int from public.ledger_entries),
  1,
  'owner consegue consultar lançamentos financeiros do próprio evento'
);

select is(
  (select status from public.check_in_ticket(
    'ticket-a-001',
    '20000000-0000-0000-0000-000000000001',
    'device-a'
  )),
  'accepted',
  'check-in válido é aceito'
);

select is(
  (select status from public.check_in_ticket(
    'ticket-a-001',
    '20000000-0000-0000-0000-000000000001',
    'device-a'
  )),
  'already_checked_in',
  'check-in repetido é idempotente'
);

select is(
  (select count(*)::int from public.check_ins),
  1,
  'check-in repetido não cria uma segunda entrada'
);

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000003', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-000000000003","role":"authenticated"}',
  true
);

select is(
  (select count(*)::int from public.tickets),
  1,
  'gate consegue consultar ingressos do evento'
);

select is(
  (select count(*)::int from public.check_ins),
  1,
  'gate consegue consultar check-ins do evento'
);

select is(
  (select count(*)::int from public.ledger_entries),
  0,
  'gate não consegue consultar lançamentos financeiros'
);

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000002', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-000000000002","role":"authenticated"}',
  true
);

select is(
  (select count(*)::int from public.organizations),
  1,
  'membro de outra organização não vê a organização A'
);

select is(
  (select count(*)::int from public.events),
  1,
  'membro de outra organização vê somente o próprio evento'
);

reset role;
select * from finish();
rollback;

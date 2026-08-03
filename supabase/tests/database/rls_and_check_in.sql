begin;

select plan(34);

-- The fixtures are rolled back at the end of the test so this suite is safe to run
-- against a disposable local database.
insert into auth.users (id, aud, role, email, email_confirmed_at)
values
  ('00000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'owner-a@example.test', now()),
  ('00000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'owner-b@example.test', now()),
  ('00000000-0000-0000-0000-000000000003', 'authenticated', 'authenticated', 'gate-a@example.test', now()),
  ('00000000-0000-0000-0000-000000000004', 'authenticated', 'authenticated', 'finance-a@example.test', now()),
  ('00000000-0000-0000-0000-000000000005', 'authenticated', 'authenticated', 'collaborator-owner@example.test', now());

insert into public.organizations (public_id, name)
values
  ('10000000-0000-0000-0000-000000000001', 'Organização A'),
  ('10000000-0000-0000-0000-000000000002', 'Organização B'),
  ('10000000-0000-0000-0000-000000000003', 'Organização colaboradora');

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

insert into public.organization_memberships (organization_id, user_id, role)
select id, '00000000-0000-0000-0000-000000000005', 'owner'
from public.organizations
where public_id = '10000000-0000-0000-0000-000000000003';

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

insert into public.event_organizations (event_id, organization_id, role)
select event_record.id, organization_record.id, 'collaborator'
from public.events event_record
join public.organizations organization_record
  on organization_record.public_id = '10000000-0000-0000-0000-000000000003'
where event_record.public_id = '20000000-0000-0000-0000-000000000001';

insert into public.lots (public_id, event_id, name, price_cents)
select '30000000-0000-0000-0000-000000000001', id, 'Lote A', 2500
from public.events
where public_id = '20000000-0000-0000-0000-000000000001';

insert into public.lots (public_id, event_id, name, price_cents)
select '30000000-0000-0000-0000-000000000002', id, 'Lote B', 3000
from public.events
where public_id = '20000000-0000-0000-0000-000000000002';

insert into public.orders (
  public_id,
  event_id,
  status,
  total_cents,
  buyer_name,
  buyer_email,
  buyer_phone,
  created_by
)
select
  '40000000-0000-0000-0000-000000000001',
  id,
  'confirmed',
  2500,
  'Cliente de teste A',
  'buyer-a@example.test',
  'phone-a-fixture',
  '00000000-0000-0000-0000-000000000001'
from public.events
where public_id = '20000000-0000-0000-0000-000000000001';

insert into public.orders (public_id, event_id, status, total_cents, created_by)
select
  '40000000-0000-0000-0000-000000000002',
  id,
  'confirmed',
  3000,
  '00000000-0000-0000-0000-000000000002'
from public.events
where public_id = '20000000-0000-0000-0000-000000000002';

insert into public.order_items (order_id, lot_id, quantity, unit_price_cents, subtotal_cents)
select order_record.id, lot.id, 1, 2500, 2500
from public.orders order_record
join public.lots lot on lot.event_id = order_record.event_id
where order_record.public_id = '40000000-0000-0000-0000-000000000001';

insert into public.order_items (order_id, lot_id, quantity, unit_price_cents, subtotal_cents)
select order_record.id, lot.id, 1, 3000, 3000
from public.orders order_record
join public.lots lot on lot.event_id = order_record.event_id
where order_record.public_id = '40000000-0000-0000-0000-000000000002';

insert into public.tickets (public_id, order_item_id, event_id, public_code)
select
  '50000000-0000-0000-0000-000000000001',
  item.id,
  order_record.event_id,
  'ticket-a-001'
from public.order_items item
join public.orders order_record on order_record.id = item.order_id
where order_record.public_id = '40000000-0000-0000-0000-000000000001';

insert into public.orders (public_id, event_id, status, total_cents, created_by)
select
  '40000000-0000-0000-0000-000000000003',
  id,
  'pending',
  2500,
  '00000000-0000-0000-0000-000000000001'
from public.events
where public_id = '20000000-0000-0000-0000-000000000001';

insert into public.order_items (order_id, lot_id, quantity, unit_price_cents, subtotal_cents)
select order_record.id, lot.id, 1, 2500, 2500
from public.orders order_record
join public.lots lot on lot.event_id = order_record.event_id
where order_record.public_id = '40000000-0000-0000-0000-000000000003';

insert into public.tickets (order_item_id, event_id, public_code)
select item.id, order_record.event_id, 'ticket-pending-001'
from public.order_items item
join public.orders order_record on order_record.id = item.order_id
where order_record.public_id = '40000000-0000-0000-0000-000000000003';

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
  2,
  'owner consegue consultar ingressos do próprio evento'
);

select is(
  (select count(*)::int from public.ledger_entries),
  1,
  'owner consegue consultar lançamentos financeiros do próprio evento'
);

select is(
  (select count(*)::int
   from public.orders_operational
   where public_id = '40000000-0000-0000-0000-000000000001'),
  1,
  'owner consegue consultar o pedido pela visão operacional'
);

select is(
  (select concat(status::text, ':', total_cents::text, ':', currency)
   from public.orders_operational
   where public_id = '40000000-0000-0000-0000-000000000001'),
  'confirmed:2500:BRL',
  'visão operacional retorna apenas os campos comerciais necessários'
);

select results_eq(
  $$
    select order_public_id, buyer_name, buyer_email, buyer_phone
    from public.get_order_customer('40000000-0000-0000-0000-000000000001')
  $$,
  $$
    values (
      '40000000-0000-0000-0000-000000000001'::uuid,
      'Cliente de teste A'::text,
      'buyer-a@example.test'::text,
      'phone-a-fixture'::text
    )
  $$,
  'owner consegue consultar detalhes do cliente pela função privilegiada'
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
  (select status from public.check_in_ticket(
    'ticket-inexistente',
    '20000000-0000-0000-0000-000000000001',
    'device-a'
  )),
  'invalid',
  'código inexistente é recusado'
);

select is(
  (select reason from public.check_in_ticket(
    'ticket-a-001',
    '20000000-0000-0000-0000-000000000002',
    'device-a'
  )),
  'wrong_event',
  'ingresso de outro evento é recusado'
);

select is(
  (select reason from public.check_in_ticket(
    'ticket-pending-001',
    '20000000-0000-0000-0000-000000000001',
    'device-a'
  )),
  'not_confirmed',
  'ingresso de pedido pendente é recusado'
);

select is(
  (select count(*)::int from public.check_ins),
  1,
  'check-in repetido não cria uma segunda entrada'
);

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000002', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-000000000002","role":"authenticated"}',
  true
);

select is(
  (select reason from public.check_in_ticket(
    'ticket-a-001',
    '20000000-0000-0000-0000-000000000001',
    'device-b'
  )),
  'not_authorized',
  'ator sem papel no evento recebe recusa discriminada'
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

select is(
  (select count(*)::int
   from public.orders_operational
   where public_id = '40000000-0000-0000-0000-000000000001'),
  0,
  'organização B não vê pedido do evento A na visão operacional'
);

select throws_ok(
  $$
    select *
    from public.get_order_customer('40000000-0000-0000-0000-000000000001');
  $$,
  '42501',
  'Not authorized to access order',
  'organização B não consulta detalhes do pedido A'
);

select set_config(
  'test.order_b_item_id',
  (select item.id::text
   from public.order_items item
   join public.orders order_record on order_record.id = item.order_id
   where order_record.public_id = '40000000-0000-0000-0000-000000000002'),
  true
);

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000005', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-000000000005","role":"authenticated"}',
  true
);

select is(
  (select public.has_event_role(
    event_record.id,
    array['owner']::public.organization_role[]
  )
  from public.events event_record
  where event_record.public_id = '20000000-0000-0000-0000-000000000001'),
  false,
  'owner de organização colaboradora não recebe papel de owner do evento'
);

update public.events
set name = 'Evento invadido'
where public_id = '20000000-0000-0000-0000-000000000001';

select is(
  (select count(*)::int from public.events where name = 'Evento invadido'),
  0,
  'organização colaboradora não altera o evento'
);

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000001', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

select throws_ok(
  $$
    update public.events
    set created_by = '00000000-0000-0000-0000-000000000002'
    where public_id = '20000000-0000-0000-0000-000000000001';
  $$,
  '42501',
  'Event ownership fields are immutable',
  'proprietário do evento não pode transferir a posse por update'
);

select throws_ok(
  $$
    insert into public.tickets (order_item_id, event_id, public_code)
    values (
      current_setting('test.order_b_item_id')::bigint,
      (select id from public.events where public_id = '20000000-0000-0000-0000-000000000001'),
      'ticket-cross-event'
    );
  $$,
  '23514',
  'Ticket event must match order item event',
  'ingresso não pode apontar para item de outro evento'
);

select throws_ok(
  $$
    select public.record_audit_log(
      (select organization_id from public.events where public_id = '20000000-0000-0000-0000-000000000001'),
      (select id from public.events where public_id = '20000000-0000-0000-0000-000000000001'),
      'ticket',
      '50000000-0000-0000-0000-000000000001',
      'checked_in',
      null,
      '{}'::jsonb
    );
  $$,
  '42501',
  'permission denied for function record_audit_log',
  'owner não executa o RPC genérico de auditoria'
);

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000003', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-000000000003","role":"authenticated"}',
  true
);

select is(
  (select count(*)::int
   from public.orders_operational
   where public_id = '40000000-0000-0000-0000-000000000001'),
  1,
  'gate consulta pedidos do evento sem dados de cliente'
);

select throws_ok(
  $$
    select * from public.orders;
  $$,
  '42501',
  'permission denied for table orders',
  'gate não consulta a tabela bruta de pedidos'
);

select throws_ok(
  $$
    select *
    from public.get_order_customer('40000000-0000-0000-0000-000000000001');
  $$,
  '42501',
  'Not authorized to access order',
  'gate não consulta dados pessoais do comprador'
);

select throws_ok(
  $$
    insert into public.audit_logs (
      organization_id, entity_type, entity_public_id, action, actor_user_id
    )
    values (
      (select id from public.organizations where public_id = '10000000-0000-0000-0000-000000000001'),
      'ticket', '50000000-0000-0000-0000-000000000001', 'forged',
      '00000000-0000-0000-0000-000000000003'
    );
  $$,
  '42501',
  'permission denied for table audit_logs',
  'cliente não escreve auditoria diretamente'
);

select throws_ok(
  $$
    select public.record_audit_log(
      (select organization_id from public.events where public_id = '20000000-0000-0000-0000-000000000001'),
      (select id from public.events where public_id = '20000000-0000-0000-0000-000000000001'),
      'ticket',
      '50000000-0000-0000-0000-000000000001',
      'forged',
      null,
      '{}'::jsonb
    );
  $$,
  '42501',
  'permission denied for function record_audit_log',
  'gate não executa o RPC genérico de auditoria'
);

select is(
  (select count(*)::int from public.audit_logs),
  0,
  'tentativas negadas não criam entradas de auditoria'
);

select is(
  (select count(*)::int from public.tickets),
  2,
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

select is(
  (select count(*)::int
   from information_schema.columns
   where table_schema = 'public'
     and table_name = 'orders_operational'
     and column_name in ('buyer_name', 'buyer_email', 'buyer_phone')),
  0,
  'visão operacional não possui colunas de dados pessoais'
);

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000004', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-000000000004","role":"authenticated"}',
  true
);

select results_eq(
  $$
    select order_public_id, buyer_name, buyer_email, buyer_phone
    from public.get_order_customer('40000000-0000-0000-0000-000000000001')
  $$,
  $$
    values (
      '40000000-0000-0000-0000-000000000001'::uuid,
      'Cliente de teste A'::text,
      'buyer-a@example.test'::text,
      'phone-a-fixture'::text
    )
  $$,
  'finance consulta detalhes do cliente pela função privilegiada'
);

reset role;
select * from finish();
rollback;

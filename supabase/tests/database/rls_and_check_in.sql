begin;

select plan(96);

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

select set_config(
  'test.event_a_id',
  (select id::text from public.events where public_id = '20000000-0000-0000-0000-000000000001'),
  true
);
select set_config(
  'test.organization_a_id',
  (select id::text from public.organizations where public_id = '10000000-0000-0000-0000-000000000001'),
  true
);
select set_config(
  'test.organization_b_id',
  (select id::text from public.organizations where public_id = '10000000-0000-0000-0000-000000000002'),
  true
);

select throws_ok(
  $$
    insert into public.ledger_entries (
      public_id, organization_id, event_id, kind, status,
      amount_cents, description, created_by
    )
    select
      '60000000-0000-0000-0000-000000000101',
      event_record.organization_id,
      event_record.id,
      'expense',
      'aprovado',
      100,
      'Estado inválido aprovado',
      '00000000-0000-0000-0000-000000000001'
    from public.events event_record
    where event_record.public_id = '20000000-0000-0000-0000-000000000001';
  $$,
  '23514',
  'new row for relation "ledger_entries" violates check constraint "ledger_entries_status_fields_check"',
  'aprovado exige aprovador'
);

select throws_ok(
  $$
    insert into public.ledger_entries (
      public_id, organization_id, event_id, kind, status,
      amount_cents, description, created_by
    )
    select
      '60000000-0000-0000-0000-000000000102',
      event_record.organization_id,
      event_record.id,
      'expense',
      'pago',
      100,
      'Estado inválido pago',
      '00000000-0000-0000-0000-000000000001'
    from public.events event_record
    where event_record.public_id = '20000000-0000-0000-0000-000000000001';
  $$,
  '23514',
  'new row for relation "ledger_entries" violates check constraint "ledger_entries_status_fields_check"',
  'pago exige aprovador e data de pagamento'
);

select throws_ok(
  $$
    insert into public.ledger_entries (
      public_id, organization_id, event_id, kind, status,
      amount_cents, description, created_by, paid_at
    )
    select
      '60000000-0000-0000-0000-000000000103',
      event_record.organization_id,
      event_record.id,
      'expense',
      'previsto',
      100,
      'Estado inválido previsto',
      '00000000-0000-0000-0000-000000000001',
      now()
    from public.events event_record
    where event_record.public_id = '20000000-0000-0000-0000-000000000001';
  $$,
  '23514',
  'new row for relation "ledger_entries" violates check constraint "ledger_entries_check1"',
  'previsto não aceita data de pagamento'
);

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
  'permission denied for table events',
  'proprietário do evento não transfere a posse por update'
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

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000001', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

select throws_ok(
  $$
    insert into public.events (public_id, organization_id, name, status, created_by)
    select
      '20000000-0000-0000-0000-000000000099',
      organization.id,
      'Evento status forjado',
      'vendas_abertas',
      (select auth.uid())
    from public.organizations organization
    where organization.public_id = '10000000-0000-0000-0000-000000000001';
  $$,
  '42501',
  'new row violates row-level security policy for table "events"',
  'novo evento não escolhe status fora de rascunho'
);

insert into public.events (public_id, organization_id, name, status, created_by)
select
  draft.public_id,
  organization.id,
  draft.name,
  'rascunho',
  (select auth.uid())
from (
  values
    ('20000000-0000-0000-0000-000000000003'::uuid, 'Evento ciclo C'::text),
    ('20000000-0000-0000-0000-000000000004'::uuid, 'Evento ciclo D'::text),
    ('20000000-0000-0000-0000-000000000005'::uuid, 'Evento ciclo E'::text),
    ('20000000-0000-0000-0000-000000000006'::uuid, 'Evento ciclo F'::text),
    ('20000000-0000-0000-0000-000000000007'::uuid, 'Evento ciclo G'::text),
    ('20000000-0000-0000-0000-000000000008'::uuid, 'Evento ciclo H'::text),
    ('20000000-0000-0000-0000-000000000009'::uuid, 'Evento ciclo I'::text)
) as draft(public_id, name)
cross join public.organizations organization
where organization.public_id = '10000000-0000-0000-0000-000000000001';

select is(
  (select count(*)::int
   from public.event_status_history history
   join public.events event_record on event_record.id = history.event_id
   where event_record.public_id = '20000000-0000-0000-0000-000000000003'),
  1,
  'novo evento cria uma entrada inicial de histórico'
);

select is(
  (select concat(
     coalesce(history.from_status::text, 'null'),
     '>',
     history.to_status::text,
     '|',
     history.actor_user_id::text
   )
   from public.event_status_history history
   join public.events event_record on event_record.id = history.event_id
   where event_record.public_id = '20000000-0000-0000-0000-000000000003'),
  'null>rascunho|00000000-0000-0000-0000-000000000001',
  'histórico inicial deriva status e ator da criação confiável'
);

update public.events
set name = 'Evento ciclo C atualizado'
where public_id = '20000000-0000-0000-0000-000000000003';

select is(
  (select name from public.events where public_id = '20000000-0000-0000-0000-000000000003'),
  'Evento ciclo C atualizado',
  'owner ainda edita detalhes não relacionados ao status'
);

select throws_ok(
  $$
    update public.events
    set status = 'planejado'
    where public_id = '20000000-0000-0000-0000-000000000003';
  $$,
  '42501',
  'permission denied for table events',
  'cliente não atualiza status diretamente'
);

select throws_ok(
  $$
    insert into public.event_status_history (
      event_id, from_status, to_status, actor_user_id, reason
    )
    values (
      (select id from public.events where public_id = '20000000-0000-0000-0000-000000000003'),
      'rascunho',
      'planejado',
      (select auth.uid()),
      'histórico forjado'
    );
  $$,
  '42501',
  'permission denied for table event_status_history',
  'cliente não insere histórico diretamente'
);

select is(
  (select status::text
   from public.transition_event('20000000-0000-0000-0000-000000000003', 'planejado')),
  'planejado',
  'rascunho avança para planejado'
);

select is(
  (select status::text
   from public.transition_event('20000000-0000-0000-0000-000000000003', 'vendas_abertas')),
  'vendas_abertas',
  'planejado avança para vendas abertas'
);

select is(
  (select status::text
   from public.transition_event('20000000-0000-0000-0000-000000000003', 'encerrado')),
  'encerrado',
  'vendas abertas avança para encerrado'
);

select is(
  (select status::text
   from public.transition_event(
     '20000000-0000-0000-0000-000000000003',
     'prestacao_contas_fechada',
     'prestação conferida'
   )),
  'prestacao_contas_fechada',
  'encerrado avança para prestação de contas fechada'
);

select is(
  (select count(*)::int
   from public.event_status_history history
   join public.events event_record on event_record.id = history.event_id
   where event_record.public_id = '20000000-0000-0000-0000-000000000003'),
  5,
  'cada transição válida cria exatamente um histórico'
);

select is(
  (select concat(
     history.from_status::text,
     '>',
     history.to_status::text,
     '|',
     history.actor_user_id::text,
     '|',
     history.reason
   )
   from public.event_status_history history
   join public.events event_record on event_record.id = history.event_id
   where event_record.public_id = '20000000-0000-0000-0000-000000000003'
   order by history.id desc
   limit 1),
  'encerrado>prestacao_contas_fechada|00000000-0000-0000-0000-000000000001|prestação conferida',
  'histórico registra origem, destino, ator e motivo da transição'
);

select is(
  (select status::text
   from public.transition_event(
     '20000000-0000-0000-0000-000000000004',
     'cancelado',
     'cancelamento em rascunho'
   )),
  'cancelado',
  'rascunho pode ser cancelado com motivo'
);

select is(
  (select reason
   from public.event_status_history history
   join public.events event_record on event_record.id = history.event_id
   where event_record.public_id = '20000000-0000-0000-0000-000000000004'
     and history.to_status = 'cancelado'),
  'cancelamento em rascunho',
  'cancelamento em rascunho preserva o motivo'
);

select is(
  (select status::text
   from public.transition_event('20000000-0000-0000-0000-000000000005', 'planejado')),
  'planejado',
  'evento planejado inicia sua transição a partir de rascunho'
);

select is(
  (select status::text
   from public.transition_event(
     '20000000-0000-0000-0000-000000000005',
     'cancelado',
     'cancelamento em planejamento'
   )),
  'cancelado',
  'planejado pode ser cancelado com motivo'
);

select is(
  (select status::text
   from public.transition_event('20000000-0000-0000-0000-000000000006', 'planejado')),
  'planejado',
  'evento em vendas inicia sua transição a partir de rascunho'
);

select is(
  (select status::text
   from public.transition_event('20000000-0000-0000-0000-000000000006', 'vendas_abertas')),
  'vendas_abertas',
  'evento em vendas alcança vendas abertas'
);

select is(
  (select status::text
   from public.transition_event(
     '20000000-0000-0000-0000-000000000006',
     'cancelado',
     'cancelamento em vendas'
   )),
  'cancelado',
  'vendas abertas pode ser cancelado com motivo'
);

select is(
  (select status::text
   from public.transition_event('20000000-0000-0000-0000-000000000007', 'planejado')),
  'planejado',
  'evento encerrado inicia sua transição a partir de rascunho'
);

select is(
  (select status::text
   from public.transition_event('20000000-0000-0000-0000-000000000007', 'vendas_abertas')),
  'vendas_abertas',
  'evento encerrado alcança vendas abertas'
);

select is(
  (select status::text
   from public.transition_event('20000000-0000-0000-0000-000000000007', 'encerrado')),
  'encerrado',
  'evento cancelável alcança encerrado'
);

select is(
  (select status::text
   from public.transition_event(
     '20000000-0000-0000-0000-000000000007',
     'cancelado',
     'cancelamento antes da prestação'
   )),
  'cancelado',
  'encerrado pode ser cancelado com motivo'
);

select throws_ok(
  $$
    select *
    from public.transition_event('20000000-0000-0000-0000-000000000008', 'vendas_abertas');
  $$,
  '22023',
  'Invalid event status transition',
  'transição não pode pular etapas'
);

select throws_ok(
  $$
    select *
    from public.transition_event('20000000-0000-0000-0000-000000000009', 'cancelado');
  $$,
  '22023',
  'Reason required for event status transition',
  'cancelamento exige motivo não vazio'
);

select is(
  (select status::text from public.events where public_id = '20000000-0000-0000-0000-000000000009'),
  'rascunho',
  'transição recusada não altera o status'
);

select is(
  (select status::text
   from public.transition_event('20000000-0000-0000-0000-000000000008', 'planejado')),
  'planejado',
  'evento usado para transições inválidas pode avançar validamente'
);

select throws_ok(
  $$
    select *
    from public.transition_event('20000000-0000-0000-0000-000000000008', 'planejado');
  $$,
  '22023',
  'Invalid event status transition',
  'transição para o mesmo status é recusada'
);

select throws_ok(
  $$
    select *
    from public.transition_event('20000000-0000-0000-0000-000000000008', 'rascunho');
  $$,
  '22023',
  'Invalid event status transition',
  'transição para trás é recusada'
);

select is(
  (select count(*)::int
   from public.event_status_history history
   join public.events event_record on event_record.id = history.event_id
   where event_record.public_id = '20000000-0000-0000-0000-000000000008'),
  2,
  'transições inválidas não duplicam o histórico'
);

select throws_ok(
  $$
    select *
    from public.transition_event(
      '20000000-0000-0000-0000-000000000004',
      'planejado'
    );
  $$,
  '22023',
  'Invalid event status transition',
  'evento cancelado não pode voltar ao fluxo'
);

select throws_ok(
  $$
    select *
    from public.transition_event(
      '20000000-0000-0000-0000-000000000003',
      'cancelado',
      'cancelamento posterior'
    );
  $$,
  '22023',
  'Invalid event status transition',
  'prestação de contas fechada não pode mudar de status'
);

select is(
  (select count(*)::int
   from public.event_status_history history
   join public.events event_record on event_record.id = history.event_id
   where event_record.public_id = '20000000-0000-0000-0000-000000000003'),
  5,
  'transição inválida não cria histórico adicional'
);

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000003', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-000000000003","role":"authenticated"}',
  true
);

select throws_ok(
  $$
    select *
    from public.transition_event(
      '20000000-0000-0000-0000-000000000001',
      'encerrado',
      'tentativa gate'
    );
  $$,
  '42501',
  'Not authorized to transition event',
  'gate não transiciona eventos'
);

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000005', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-000000000005","role":"authenticated"}',
  true
);

select throws_ok(
  $$
    select *
    from public.transition_event(
      '20000000-0000-0000-0000-000000000001',
      'encerrado',
      'tentativa colaborador'
    );
  $$,
  '42501',
  'Not authorized to transition event',
  'colaborador não transiciona eventos'
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

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000004', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-000000000004","role":"authenticated"}',
  true
);

insert into public.ledger_entries (
  public_id,
  organization_id,
  event_id,
  kind,
  amount_cents,
  description,
  created_by
)
values (
  '60000000-0000-0000-0000-000000000001',
  current_setting('test.organization_a_id')::bigint,
  current_setting('test.event_a_id')::bigint,
  'expense',
  1200,
  'Lançamento de teste finance',
  (select auth.uid())
);

select is(
  (select count(*)::int
   from public.ledger_entries
   where public_id = '60000000-0000-0000-0000-000000000001'
     and status = 'previsto'
     and approved_by is null
     and paid_at is null),
  1,
  'finance cria lançamento apenas como previsto'
);

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000001', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

insert into public.ledger_entries (
  public_id,
  organization_id,
  event_id,
  kind,
  amount_cents,
  description,
  created_by
)
values (
  '60000000-0000-0000-0000-000000000002',
  current_setting('test.organization_a_id')::bigint,
  current_setting('test.event_a_id')::bigint,
  'expense',
  800,
  'Lançamento de teste owner',
  (select auth.uid())
);

select is(
  (select count(*)::int
   from public.ledger_entries
   where public_id = '60000000-0000-0000-0000-000000000002'
     and status = 'previsto'),
  1,
  'owner também cria lançamento previsto'
);

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000002', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-000000000002","role":"authenticated"}',
  true
);

select throws_ok(
  $$
    insert into public.ledger_entries (
      public_id, organization_id, event_id, kind,
      amount_cents, description, created_by
    )
    values (
      '60000000-0000-0000-0000-000000000003',
      current_setting('test.organization_b_id')::bigint,
      current_setting('test.event_a_id')::bigint,
      'expense',
      500,
      'Organização incompatível',
      (select auth.uid())
    );
  $$,
  '23514',
  'Ledger organization must match event owner organization',
  'organização B não anexa seu lançamento ao evento A'
);

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000003', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-000000000003","role":"authenticated"}',
  true
);

select throws_ok(
  $$
    insert into public.ledger_entries (
      public_id, organization_id, event_id, kind,
      amount_cents, description, created_by
    )
    values (
      '60000000-0000-0000-0000-000000000004',
      current_setting('test.organization_a_id')::bigint,
      current_setting('test.event_a_id')::bigint,
      'expense',
      500,
      'Lançamento gate',
      (select auth.uid())
    );
  $$,
  '42501',
  'new row violates row-level security policy for table "ledger_entries"',
  'gate não cria lançamentos financeiros'
);

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000004', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-000000000004","role":"authenticated"}',
  true
);

select throws_ok(
  $$
    update public.ledger_entries
    set description = 'alteração direta'
    where public_id = '60000000-0000-0000-0000-000000000001';
  $$,
  '42501',
  'permission denied for table ledger_entries',
  'finance não atualiza lançamento diretamente'
);

select throws_ok(
  $$
    delete from public.ledger_entries
    where public_id = '60000000-0000-0000-0000-000000000001';
  $$,
  '42501',
  'permission denied for table ledger_entries',
  'finance não apaga lançamento diretamente'
);

select throws_ok(
  $$
    select *
    from public.approve_ledger_entry('60000000-0000-0000-0000-000000000001'::uuid, '   '::text);
  $$,
  '22023',
  'Reason required for ledger entry transition',
  'aprovação exige motivo não vazio'
);

select is(
  (select concat(status::text, '|', approved_by::text, '|', (paid_at is null)::text)
   from public.ledger_entries
   where public_id = '60000000-0000-0000-0000-000000000001'),
  'previsto||true',
  'aprovação sem motivo não altera o lançamento'
);

select is(
  (select status::text
   from public.approve_ledger_entry(
     '60000000-0000-0000-0000-000000000001'::uuid,
     'aprovação conferida'::text
   )),
  'aprovado',
  'finance aprova lançamento previsto com motivo'
);

select is(
  (select concat(status::text, '|', approved_by::text, '|', (paid_at is null)::text)
   from public.ledger_entries
   where public_id = '60000000-0000-0000-0000-000000000001'),
  'aprovado|00000000-0000-0000-0000-000000000004|true',
  'aprovação deriva ator e mantém pagamento vazio'
);

select is(
  (select concat(
     action,
     '|',
     actor_user_id::text,
     '|',
     entity_type,
     '|',
     entity_public_id,
     '|',
     reason
   )
   from public.audit_logs
   where entity_public_id = '60000000-0000-0000-0000-000000000001'
     and action = 'approved'),
  'approved|00000000-0000-0000-0000-000000000004|ledger_entry|60000000-0000-0000-0000-000000000001|aprovação conferida',
  'auditoria de aprovação deriva evento, entidade, motivo e ator'
);

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000003', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-000000000003","role":"authenticated"}',
  true
);

select throws_ok(
  $$
    select *
    from public.approve_ledger_entry('60000000-0000-0000-0000-000000000001'::uuid, 'tentativa gate'::text);
  $$,
  '42501',
  'Not authorized to transition ledger entry',
  'gate não aprova lançamentos'
);

select throws_ok(
  $$
    select *
    from public.pay_ledger_entry('60000000-0000-0000-0000-000000000001'::uuid, 'tentativa gate'::text);
  $$,
  '42501',
  'Not authorized to transition ledger entry',
  'gate não paga lançamentos'
);

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000004', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-000000000004","role":"authenticated"}',
  true
);

select throws_ok(
  $$
    select *
    from public.pay_ledger_entry('60000000-0000-0000-0000-000000000001'::uuid, '   '::text);
  $$,
  '22023',
  'Reason required for ledger entry transition',
  'pagamento exige motivo não vazio'
);

select is(
  (select status::text from public.ledger_entries where public_id = '60000000-0000-0000-0000-000000000001'),
  'aprovado',
  'pagamento sem motivo não altera o status aprovado'
);

select is(
  (select status::text
   from public.pay_ledger_entry(
     '60000000-0000-0000-0000-000000000001'::uuid,
     'pagamento conferido'::text
   )),
  'pago',
  'finance paga lançamento aprovado com motivo'
);

select is(
  (select concat(status::text, '|', approved_by::text, '|', (paid_at is not null)::text)
   from public.ledger_entries
   where public_id = '60000000-0000-0000-0000-000000000001'),
  'pago|00000000-0000-0000-0000-000000000004|true',
  'pagamento define data e preserva o aprovador'
);

select is(
  (select concat(
     action,
     '|',
     actor_user_id::text,
     '|',
     entity_type,
     '|',
     entity_public_id,
     '|',
     reason
   )
   from public.audit_logs
   where entity_public_id = '60000000-0000-0000-0000-000000000001'
     and action = 'paid'),
  'paid|00000000-0000-0000-0000-000000000004|ledger_entry|60000000-0000-0000-0000-000000000001|pagamento conferido',
  'auditoria de pagamento deriva ator e motivo da operação'
);

select throws_ok(
  $$
    select *
    from public.approve_ledger_entry('60000000-0000-0000-0000-000000000001'::uuid, 'segunda aprovação'::text);
  $$,
  '22023',
  'Invalid ledger entry status transition',
  'aprovação repetida é recusada'
);

select is(
  (select count(*)::int
   from public.audit_logs
   where entity_public_id = '60000000-0000-0000-0000-000000000001'),
  2,
  'aprovação repetida não cria auditoria'
);

select throws_ok(
  $$
    select *
    from public.pay_ledger_entry('60000000-0000-0000-0000-000000000001'::uuid, 'segundo pagamento'::text);
  $$,
  '22023',
  'Invalid ledger entry status transition',
  'pagamento repetido é recusado'
);

select is(
  (select count(*)::int
   from public.audit_logs
   where entity_public_id = '60000000-0000-0000-0000-000000000001'),
  2,
  'pagamento repetido não cria auditoria'
);

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000001', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

select throws_ok(
  $$
    select *
    from public.pay_ledger_entry('60000000-0000-0000-0000-000000000002'::uuid, 'pagamento sem aprovação'::text);
  $$,
  '22023',
  'Invalid ledger entry status transition',
  'pagamento direto de previsto é recusado'
);

select is(
  (select concat(status::text, '|', (approved_by is null)::text, '|', (paid_at is null)::text)
   from public.ledger_entries
   where public_id = '60000000-0000-0000-0000-000000000002'),
  'previsto|true|true',
  'pagamento direto não altera lançamento previsto'
);

reset role;
select * from finish();
rollback;

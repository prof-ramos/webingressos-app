-- Promote the existing public UUIDs to primary keys and use UUIDv7 for all
-- domain records that previously had only an internal bigint identity.
-- organization_id is the explicit tenant boundary in this domain; the product
-- vocabulary calls the tenant an Organization.

create or replace function public.uuidv7()
returns uuid
language plpgsql
volatile
set search_path = public, extensions
as $$
declare
  uuid_bytes bytea := uuid_send(gen_random_uuid());
  epoch_milliseconds bigint := floor(extract(epoch from clock_timestamp()) * 1000);
begin
  uuid_bytes := set_byte(uuid_bytes, 0, ((epoch_milliseconds >> 40) & 255)::integer);
  uuid_bytes := set_byte(uuid_bytes, 1, ((epoch_milliseconds >> 32) & 255)::integer);
  uuid_bytes := set_byte(uuid_bytes, 2, ((epoch_milliseconds >> 24) & 255)::integer);
  uuid_bytes := set_byte(uuid_bytes, 3, ((epoch_milliseconds >> 16) & 255)::integer);
  uuid_bytes := set_byte(uuid_bytes, 4, ((epoch_milliseconds >> 8) & 255)::integer);
  uuid_bytes := set_byte(uuid_bytes, 5, (epoch_milliseconds & 255)::integer);
  uuid_bytes := set_byte(uuid_bytes, 6, (get_byte(uuid_bytes, 6) & 15) | 112);
  uuid_bytes := set_byte(uuid_bytes, 8, (get_byte(uuid_bytes, 8) & 63) | 128);

  return encode(uuid_bytes, 'hex')::uuid;
end;
$$;

revoke all on function public.uuidv7() from public;
grant execute on function public.uuidv7() to authenticated, service_role;

-- Policies depend on the old bigint helper signatures. Remove them before
-- replacing the functions and changing the referenced columns.
drop policy if exists organizations_select_member on public.organizations;
drop policy if exists memberships_select_member on public.organization_memberships;
drop policy if exists events_select_member on public.events;
drop policy if exists events_insert_operator on public.events;
drop policy if exists events_update_operator on public.events;
drop policy if exists event_organizations_select_member on public.event_organizations;
drop policy if exists event_organizations_insert_owner on public.event_organizations;
drop policy if exists event_status_history_select_member on public.event_status_history;
drop policy if exists event_status_history_insert_operator on public.event_status_history;
drop policy if exists lots_select_member on public.lots;
drop policy if exists lots_insert_operator on public.lots;
drop policy if exists lots_update_operator on public.lots;
drop policy if exists promoters_select_member on public.promoters;
drop policy if exists promoters_insert_operator on public.promoters;
drop policy if exists promoters_update_operator on public.promoters;
drop policy if exists orders_select_member on public.orders;
drop policy if exists orders_insert_operator on public.orders;
drop policy if exists orders_update_operator on public.orders;
drop policy if exists order_items_select_member on public.order_items;
drop policy if exists order_items_insert_operator on public.order_items;
drop policy if exists tickets_select_gate on public.tickets;
drop policy if exists tickets_insert_operator on public.tickets;
drop policy if exists check_ins_select_gate on public.check_ins;
drop policy if exists ledger_entries_select_finance on public.ledger_entries;
drop policy if exists ledger_entries_insert_finance on public.ledger_entries;
drop policy if exists audit_logs_select_member on public.audit_logs;

drop function if exists public.record_audit_log(bigint, bigint, text, text, text, text, jsonb);
drop function if exists public.check_in_ticket(text, uuid, text);
drop function if exists public.has_event_role(bigint, public.organization_role[]);
drop function if exists public.can_access_event(bigint);
drop function if exists public.has_org_role(bigint, public.organization_role[]);
drop function if exists public.create_organization(text);
drop function if exists public.is_org_member(bigint);

-- Keep a mapping for every former bigint identity. Public UUIDs are preserved;
-- records that never had a public UUID receive a new UUIDv7.
create temporary table _uuid_id_map (
  relation_name text not null,
  old_id bigint not null,
  new_id uuid not null,
  primary key (relation_name, old_id),
  unique (relation_name, new_id)
) on commit drop;

insert into _uuid_id_map (relation_name, old_id, new_id)
select 'organizations', id, public_id from public.organizations;
insert into _uuid_id_map (relation_name, old_id, new_id)
select 'events', id, public_id from public.events;
insert into _uuid_id_map (relation_name, old_id, new_id)
select 'lots', id, public_id from public.lots;
insert into _uuid_id_map (relation_name, old_id, new_id)
select 'promoters', id, public_id from public.promoters;
insert into _uuid_id_map (relation_name, old_id, new_id)
select 'orders', id, public_id from public.orders;
insert into _uuid_id_map (relation_name, old_id, new_id)
select 'tickets', id, public_id from public.tickets;
insert into _uuid_id_map (relation_name, old_id, new_id)
select 'check_ins', id, public_id from public.check_ins;
insert into _uuid_id_map (relation_name, old_id, new_id)
select 'ledger_entries', id, public_id from public.ledger_entries;

alter table public.organization_memberships
  add column _uuid_id uuid not null default public.uuidv7();
insert into _uuid_id_map (relation_name, old_id, new_id)
select 'organization_memberships', id, _uuid_id from public.organization_memberships;

alter table public.event_organizations
  add column _uuid_id uuid not null default public.uuidv7();
insert into _uuid_id_map (relation_name, old_id, new_id)
select 'event_organizations', id, _uuid_id from public.event_organizations;

alter table public.event_status_history
  add column _uuid_id uuid not null default public.uuidv7();
insert into _uuid_id_map (relation_name, old_id, new_id)
select 'event_status_history', id, _uuid_id from public.event_status_history;

alter table public.order_items
  add column _uuid_id uuid not null default public.uuidv7();
insert into _uuid_id_map (relation_name, old_id, new_id)
select 'order_items', id, _uuid_id from public.order_items;

-- Capture all foreign keys before parent IDs are changed.
alter table public.organization_memberships add column _organization_id_uuid uuid;
update public.organization_memberships child
set _organization_id_uuid = map.new_id
from _uuid_id_map map
where map.relation_name = 'organizations'
  and map.old_id = child.organization_id;

alter table public.events add column _organization_id_uuid uuid;
update public.events child
set _organization_id_uuid = map.new_id
from _uuid_id_map map
where map.relation_name = 'organizations'
  and map.old_id = child.organization_id;

alter table public.event_organizations
  add column _event_id_uuid uuid,
  add column _organization_id_uuid uuid;
update public.event_organizations child
set
  _event_id_uuid = event_map.new_id,
  _organization_id_uuid = organization_map.new_id
from _uuid_id_map event_map
join _uuid_id_map organization_map
  on organization_map.relation_name = 'organizations'
where event_map.relation_name = 'events'
  and event_map.old_id = child.event_id
  and organization_map.old_id = child.organization_id;

alter table public.event_status_history add column _event_id_uuid uuid;
update public.event_status_history child
set _event_id_uuid = map.new_id
from _uuid_id_map map
where map.relation_name = 'events'
  and map.old_id = child.event_id;

alter table public.lots add column _event_id_uuid uuid;
update public.lots child
set _event_id_uuid = map.new_id
from _uuid_id_map map
where map.relation_name = 'events'
  and map.old_id = child.event_id;

alter table public.promoters add column _event_id_uuid uuid;
update public.promoters child
set _event_id_uuid = map.new_id
from _uuid_id_map map
where map.relation_name = 'events'
  and map.old_id = child.event_id;

alter table public.orders
  add column _event_id_uuid uuid,
  add column _promoter_id_uuid uuid;
update public.orders child
set _event_id_uuid = event_map.new_id
from _uuid_id_map event_map
where event_map.relation_name = 'events'
  and event_map.old_id = child.event_id;
update public.orders child
set _promoter_id_uuid = map.new_id
from _uuid_id_map map
where map.relation_name = 'promoters'
  and map.old_id = child.promoter_id;

alter table public.order_items
  add column _order_id_uuid uuid,
  add column _lot_id_uuid uuid;
update public.order_items child
set
  _order_id_uuid = order_map.new_id,
  _lot_id_uuid = lot_map.new_id
from _uuid_id_map order_map
join _uuid_id_map lot_map
  on lot_map.relation_name = 'lots'
where order_map.relation_name = 'orders'
  and order_map.old_id = child.order_id
  and lot_map.old_id = child.lot_id;

alter table public.tickets
  add column _order_item_id_uuid uuid,
  add column _event_id_uuid uuid;
update public.tickets child
set
  _order_item_id_uuid = item_map.new_id,
  _event_id_uuid = event_map.new_id
from _uuid_id_map item_map
join _uuid_id_map event_map
  on event_map.relation_name = 'events'
where item_map.relation_name = 'order_items'
  and item_map.old_id = child.order_item_id
  and event_map.old_id = child.event_id;

alter table public.check_ins
  add column _ticket_id_uuid uuid,
  add column _event_id_uuid uuid;
update public.check_ins child
set
  _ticket_id_uuid = ticket_map.new_id,
  _event_id_uuid = event_map.new_id
from _uuid_id_map ticket_map
join _uuid_id_map event_map
  on event_map.relation_name = 'events'
where ticket_map.relation_name = 'tickets'
  and ticket_map.old_id = child.ticket_id
  and event_map.old_id = child.event_id;

alter table public.ledger_entries
  add column _organization_id_uuid uuid,
  add column _event_id_uuid uuid;
update public.ledger_entries child
set
  _organization_id_uuid = organization_map.new_id,
  _event_id_uuid = event_map.new_id
from _uuid_id_map organization_map
join _uuid_id_map event_map
  on event_map.relation_name = 'events'
where organization_map.relation_name = 'organizations'
  and organization_map.old_id = child.organization_id
  and event_map.old_id = child.event_id;

alter table public.audit_logs
  add column _organization_id_uuid uuid,
  add column _event_id_uuid uuid;
update public.audit_logs child
set _organization_id_uuid = map.new_id
from _uuid_id_map map
where map.relation_name = 'organizations'
  and map.old_id = child.organization_id;
update public.audit_logs child
set _event_id_uuid = map.new_id
from _uuid_id_map map
where map.relation_name = 'events'
  and map.old_id = child.event_id;

alter table public.organization_memberships alter column _organization_id_uuid set not null;
alter table public.events alter column _organization_id_uuid set not null;
alter table public.event_organizations
  alter column _event_id_uuid set not null,
  alter column _organization_id_uuid set not null;
alter table public.event_status_history alter column _event_id_uuid set not null;
alter table public.lots alter column _event_id_uuid set not null;
alter table public.promoters alter column _event_id_uuid set not null;
alter table public.orders alter column _event_id_uuid set not null;
alter table public.order_items
  alter column _order_id_uuid set not null,
  alter column _lot_id_uuid set not null;
alter table public.tickets
  alter column _order_item_id_uuid set not null,
  alter column _event_id_uuid set not null;
alter table public.check_ins
  alter column _ticket_id_uuid set not null,
  alter column _event_id_uuid set not null;
alter table public.ledger_entries
  alter column _organization_id_uuid set not null,
  alter column _event_id_uuid set not null;
alter table public.audit_logs alter column _organization_id_uuid set not null;

-- Drop only foreign keys that point at the identifiers being migrated. Auth
-- user foreign keys remain untouched.
do $$
declare
  foreign_key record;
begin
  for foreign_key in
    select
      child_namespace.nspname as child_schema,
      child_table.relname as child_table,
      constraint_record.conname as constraint_name
    from pg_constraint constraint_record
    join pg_class child_table on child_table.oid = constraint_record.conrelid
    join pg_namespace child_namespace on child_namespace.oid = child_table.relnamespace
    where constraint_record.contype = 'f'
      and child_namespace.nspname = 'public'
      and constraint_record.confrelid in (
        'public.organizations'::regclass,
        'public.events'::regclass,
        'public.event_organizations'::regclass,
        'public.lots'::regclass,
        'public.promoters'::regclass,
        'public.orders'::regclass,
        'public.order_items'::regclass,
        'public.tickets'::regclass
      )
  loop
    execute format(
      'alter table %I.%I drop constraint %I',
      foreign_key.child_schema,
      foreign_key.child_table,
      foreign_key.constraint_name
    );
  end loop;
end;
$$;

-- Existing public UUIDs become the primary key value without changing any
-- externally stored references. Internal-only records get a generated UUIDv7.
alter table public.organizations alter column id drop identity if exists;
alter table public.organizations alter column id type uuid using public_id;
alter table public.organizations alter column id set default public.uuidv7();
alter table public.organizations drop column public_id;

alter table public.events alter column id drop identity if exists;
alter table public.events alter column id type uuid using public_id;
alter table public.events alter column id set default public.uuidv7();
alter table public.events drop column public_id;

alter table public.lots alter column id drop identity if exists;
alter table public.lots alter column id type uuid using public_id;
alter table public.lots alter column id set default public.uuidv7();
alter table public.lots drop column public_id;

alter table public.promoters alter column id drop identity if exists;
alter table public.promoters alter column id type uuid using public_id;
alter table public.promoters alter column id set default public.uuidv7();
alter table public.promoters drop column public_id;

alter table public.orders alter column id drop identity if exists;
alter table public.orders alter column id type uuid using public_id;
alter table public.orders alter column id set default public.uuidv7();
alter table public.orders drop column public_id;

alter table public.tickets alter column id drop identity if exists;
alter table public.tickets alter column id type uuid using public_id;
alter table public.tickets alter column id set default public.uuidv7();
alter table public.tickets drop column public_id;

alter table public.check_ins alter column id drop identity if exists;
alter table public.check_ins alter column id type uuid using public_id;
alter table public.check_ins alter column id set default public.uuidv7();
alter table public.check_ins drop column public_id;

alter table public.ledger_entries alter column id drop identity if exists;
alter table public.ledger_entries alter column id type uuid using public_id;
alter table public.ledger_entries alter column id set default public.uuidv7();
alter table public.ledger_entries drop column public_id;

alter table public.organization_memberships drop constraint organization_memberships_pkey;
alter table public.organization_memberships drop column id;
alter table public.organization_memberships rename column _uuid_id to id;
alter table public.organization_memberships alter column id set default public.uuidv7();
alter table public.organization_memberships add primary key (id);

alter table public.event_organizations drop constraint event_organizations_pkey;
alter table public.event_organizations drop column id;
alter table public.event_organizations rename column _uuid_id to id;
alter table public.event_organizations alter column id set default public.uuidv7();
alter table public.event_organizations add primary key (id);

alter table public.event_status_history drop constraint event_status_history_pkey;
alter table public.event_status_history drop column id;
alter table public.event_status_history rename column _uuid_id to id;
alter table public.event_status_history alter column id set default public.uuidv7();
alter table public.event_status_history add primary key (id);

alter table public.order_items drop constraint order_items_pkey;
alter table public.order_items drop column id;
alter table public.order_items rename column _uuid_id to id;
alter table public.order_items alter column id set default public.uuidv7();
alter table public.order_items add primary key (id);

-- Replace the old bigint foreign-key columns with their mapped UUID values.
drop trigger if exists tickets_event_consistency on public.tickets;

alter table public.organization_memberships drop column organization_id;
alter table public.organization_memberships rename column _organization_id_uuid to organization_id;

alter table public.events drop column organization_id;
alter table public.events rename column _organization_id_uuid to organization_id;

alter table public.event_organizations
  drop column event_id,
  drop column organization_id;
alter table public.event_organizations
  rename column _event_id_uuid to event_id;
alter table public.event_organizations
  rename column _organization_id_uuid to organization_id;

alter table public.event_status_history drop column event_id;
alter table public.event_status_history rename column _event_id_uuid to event_id;

alter table public.lots drop column event_id;
alter table public.lots rename column _event_id_uuid to event_id;

alter table public.promoters drop column event_id;
alter table public.promoters rename column _event_id_uuid to event_id;

alter table public.orders drop column event_id;
alter table public.orders drop column promoter_id;
alter table public.orders rename column _event_id_uuid to event_id;
alter table public.orders rename column _promoter_id_uuid to promoter_id;

alter table public.order_items
  drop column order_id,
  drop column lot_id;
alter table public.order_items
  rename column _order_id_uuid to order_id;
alter table public.order_items rename column _lot_id_uuid to lot_id;

alter table public.tickets
  drop column order_item_id,
  drop column event_id;
alter table public.tickets
  rename column _order_item_id_uuid to order_item_id;
alter table public.tickets rename column _event_id_uuid to event_id;

alter table public.check_ins
  drop column ticket_id,
  drop column event_id;
alter table public.check_ins
  rename column _ticket_id_uuid to ticket_id;
alter table public.check_ins rename column _event_id_uuid to event_id;

alter table public.ledger_entries
  drop column organization_id,
  drop column event_id;
alter table public.ledger_entries
  rename column _organization_id_uuid to organization_id;
alter table public.ledger_entries rename column _event_id_uuid to event_id;

alter table public.audit_logs
  drop column organization_id,
  drop column event_id;
alter table public.audit_logs
  rename column _organization_id_uuid to organization_id;
alter table public.audit_logs rename column _event_id_uuid to event_id;

-- Materialize the tenant boundary on child records. The composite foreign keys
-- below prevent a valid event ID from being paired with another organization.
alter table public.event_status_history add column organization_id uuid;
update public.event_status_history history
set organization_id = event_record.organization_id
from public.events event_record
where event_record.id = history.event_id;

alter table public.lots add column organization_id uuid;
update public.lots lot
set organization_id = event_record.organization_id
from public.events event_record
where event_record.id = lot.event_id;

alter table public.promoters add column organization_id uuid;
update public.promoters promoter
set organization_id = event_record.organization_id
from public.events event_record
where event_record.id = promoter.event_id;

alter table public.orders add column organization_id uuid;
update public.orders order_record
set organization_id = event_record.organization_id
from public.events event_record
where event_record.id = order_record.event_id;

alter table public.order_items add column organization_id uuid;
update public.order_items item
set organization_id = order_record.organization_id
from public.orders order_record
where order_record.id = item.order_id;

alter table public.tickets add column organization_id uuid;
update public.tickets ticket
set organization_id = event_record.organization_id
from public.events event_record
where event_record.id = ticket.event_id;

alter table public.check_ins add column organization_id uuid;
update public.check_ins check_in
set organization_id = event_record.organization_id
from public.events event_record
where event_record.id = check_in.event_id;

alter table public.event_status_history alter column organization_id set not null;
alter table public.lots alter column organization_id set not null;
alter table public.promoters alter column organization_id set not null;
alter table public.orders alter column organization_id set not null;
alter table public.order_items alter column organization_id set not null;
alter table public.tickets alter column organization_id set not null;
alter table public.check_ins alter column organization_id set not null;

-- The old schema allowed these pairs independently. Do not silently discard
-- promoter attribution or move financial/audit ownership during a key migration:
-- refuse the upgrade and require an explicit data correction if legacy rows do
-- not agree with the event tenant.
do $$
declare
  mismatched_order_promoters bigint;
  mismatched_ledger_entries bigint;
  mismatched_audit_logs bigint;
begin
  select count(*)
  into mismatched_order_promoters
  from public.orders order_record
  where order_record.promoter_id is not null
    and not exists (
      select 1
      from public.promoters promoter_record
      where promoter_record.id = order_record.promoter_id
        and promoter_record.event_id = order_record.event_id
        and promoter_record.organization_id = order_record.organization_id
    );

  select count(*)
  into mismatched_ledger_entries
  from public.ledger_entries ledger_entry
  join public.events event_record on event_record.id = ledger_entry.event_id
  where ledger_entry.organization_id is distinct from event_record.organization_id;

  select count(*)
  into mismatched_audit_logs
  from public.audit_logs audit_log
  join public.events event_record on event_record.id = audit_log.event_id
  where audit_log.organization_id is distinct from event_record.organization_id;

  if mismatched_order_promoters > 0
    or mismatched_ledger_entries > 0
    or mismatched_audit_logs > 0 then
    raise exception using
      errcode = '23514',
      message = format(
        'UUIDv7 migration refused: %s order/promoter links, %s ledger tenant/event pairs, %s audit tenant/event pairs require explicit correction',
        mismatched_order_promoters,
        mismatched_ledger_entries,
        mismatched_audit_logs
      );
  end if;
end;
$$;

-- Recreate uniqueness and foreign-key constraints using UUIDs.
alter table public.events
  add constraint events_id_organization_id_key unique (id, organization_id);
alter table public.lots
  add constraint lots_id_organization_id_key unique (id, organization_id);
alter table public.orders
  add constraint orders_id_organization_id_key unique (id, organization_id);
alter table public.order_items
  add constraint order_items_id_organization_id_key unique (id, organization_id);
alter table public.tickets
  add constraint tickets_id_organization_id_key unique (id, organization_id);

alter table public.organization_memberships
  add constraint organization_memberships_organization_id_fkey
    foreign key (organization_id) references public.organizations (id) on delete cascade,
  add constraint organization_memberships_organization_id_user_id_key
    unique (organization_id, user_id);

alter table public.events
  add constraint events_organization_id_fkey
    foreign key (organization_id) references public.organizations (id) on delete restrict;

alter table public.event_organizations
  add constraint event_organizations_event_id_fkey
    foreign key (event_id) references public.events (id) on delete restrict,
  add constraint event_organizations_organization_id_fkey
    foreign key (organization_id) references public.organizations (id) on delete restrict,
  add constraint event_organizations_event_id_organization_id_key
    unique (event_id, organization_id);

alter table public.event_status_history
  add constraint event_status_history_event_id_fkey
    foreign key (event_id, organization_id)
    references public.events (id, organization_id) on delete restrict,
  add constraint event_status_history_organization_id_fkey
    foreign key (organization_id) references public.organizations (id) on delete restrict;

alter table public.lots
  add constraint lots_event_id_fkey
    foreign key (event_id, organization_id)
    references public.events (id, organization_id) on delete restrict,
  add constraint lots_organization_id_fkey
    foreign key (organization_id) references public.organizations (id) on delete restrict;

alter table public.promoters
  add constraint promoters_id_event_id_organization_id_key
    unique (id, event_id, organization_id),
  add constraint promoters_event_id_fkey
    foreign key (event_id, organization_id)
    references public.events (id, organization_id) on delete restrict,
  add constraint promoters_organization_id_fkey
    foreign key (organization_id) references public.organizations (id) on delete restrict;

alter table public.orders
  add constraint orders_event_id_fkey
    foreign key (event_id, organization_id)
    references public.events (id, organization_id) on delete restrict,
  add constraint orders_organization_id_fkey
    foreign key (organization_id) references public.organizations (id) on delete restrict,
  add constraint orders_promoter_id_fkey
    foreign key (promoter_id, event_id, organization_id)
    references public.promoters (id, event_id, organization_id) on delete restrict;

alter table public.order_items
  add constraint order_items_order_id_fkey
    foreign key (order_id, organization_id)
    references public.orders (id, organization_id) on delete restrict,
  add constraint order_items_lot_id_fkey
    foreign key (lot_id, organization_id)
    references public.lots (id, organization_id) on delete restrict,
  add constraint order_items_organization_id_fkey
    foreign key (organization_id) references public.organizations (id) on delete restrict;

alter table public.tickets
  add constraint tickets_order_item_id_fkey
    foreign key (order_item_id, organization_id)
    references public.order_items (id, organization_id) on delete restrict,
  add constraint tickets_event_id_fkey
    foreign key (event_id, organization_id)
    references public.events (id, organization_id) on delete restrict,
  add constraint tickets_organization_id_fkey
    foreign key (organization_id) references public.organizations (id) on delete restrict;

alter table public.check_ins
  add constraint check_ins_ticket_id_fkey
    foreign key (ticket_id, organization_id)
    references public.tickets (id, organization_id) on delete restrict,
  add constraint check_ins_event_id_fkey
    foreign key (event_id, organization_id)
    references public.events (id, organization_id) on delete restrict,
  add constraint check_ins_organization_id_fkey
    foreign key (organization_id) references public.organizations (id) on delete restrict,
  add constraint check_ins_ticket_id_organization_id_key
    unique (ticket_id, organization_id),
  add constraint check_ins_ticket_id_key
    unique (ticket_id);

alter table public.ledger_entries
  add constraint ledger_entries_organization_id_fkey
    foreign key (organization_id) references public.organizations (id) on delete restrict,
  add constraint ledger_entries_event_id_fkey
    foreign key (event_id, organization_id)
    references public.events (id, organization_id) on delete restrict;

alter table public.audit_logs
  add constraint audit_logs_organization_id_fkey
    foreign key (organization_id) references public.organizations (id) on delete restrict,
  add constraint audit_logs_event_id_fkey
    foreign key (event_id, organization_id)
    references public.events (id, organization_id) on delete restrict;

create trigger tickets_event_consistency
  before insert or update of order_item_id, event_id on public.tickets
  for each row
  execute function public.validate_ticket_event();

-- Recreate indexes lost when bigint foreign-key columns were replaced.
create index if not exists organization_memberships_user_org_idx
  on public.organization_memberships (user_id, organization_id);
create index if not exists events_organization_id_idx on public.events (organization_id);
create index if not exists events_status_idx on public.events (status);
create index if not exists event_organizations_event_id_idx on public.event_organizations (event_id);
create index if not exists event_organizations_organization_id_idx on public.event_organizations (organization_id);
create index if not exists event_status_history_event_id_occurred_at_idx
  on public.event_status_history (event_id, occurred_at desc);
create index if not exists event_status_history_organization_id_event_id_idx
  on public.event_status_history (organization_id, event_id);
create index if not exists lots_event_id_idx on public.lots (event_id);
create index if not exists lots_organization_id_event_id_idx
  on public.lots (organization_id, event_id);
create index if not exists promoters_event_id_idx on public.promoters (event_id);
create index if not exists promoters_organization_id_event_id_idx
  on public.promoters (organization_id, event_id);
create index if not exists orders_event_id_idx on public.orders (event_id);
create index if not exists orders_organization_id_event_id_idx
  on public.orders (organization_id, event_id);
create index if not exists orders_promoter_id_idx on public.orders (promoter_id);
create index if not exists orders_promoter_event_organization_idx
  on public.orders (promoter_id, event_id, organization_id);
create index if not exists orders_status_idx on public.orders (event_id, status);
create index if not exists order_items_order_id_idx on public.order_items (order_id);
create index if not exists order_items_organization_id_order_id_idx
  on public.order_items (organization_id, order_id);
create index if not exists order_items_lot_id_idx on public.order_items (lot_id);
create index if not exists tickets_order_item_id_idx on public.tickets (order_item_id);
create index if not exists tickets_event_id_idx on public.tickets (event_id);
create index if not exists tickets_organization_id_event_id_idx
  on public.tickets (organization_id, event_id);
create index if not exists check_ins_event_id_checked_in_at_idx
  on public.check_ins (event_id, checked_in_at desc);
create index if not exists check_ins_organization_id_event_id_idx
  on public.check_ins (organization_id, event_id);
create index if not exists check_ins_checked_by_idx on public.check_ins (checked_by);
create index if not exists ledger_entries_organization_id_idx on public.ledger_entries (organization_id);
create index if not exists ledger_entries_event_id_status_idx on public.ledger_entries (event_id, status);
create index if not exists ledger_entries_event_id_occurred_at_idx
  on public.ledger_entries (event_id, occurred_at desc);
create index if not exists audit_logs_organization_id_occurred_at_idx
  on public.audit_logs (organization_id, occurred_at desc);
create index if not exists audit_logs_event_id_occurred_at_idx
  on public.audit_logs (event_id, occurred_at desc);
create index if not exists audit_logs_entity_idx
  on public.audit_logs (entity_type, entity_public_id);
create index if not exists ledger_entries_created_by_idx on public.ledger_entries (created_by);
create index if not exists ledger_entries_approved_by_idx on public.ledger_entries (approved_by);
create index if not exists audit_logs_actor_user_id_idx on public.audit_logs (actor_user_id);

-- UUID-aware authorization helpers.
create or replace function public.is_org_member(target_organization_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.organization_memberships membership
    where membership.organization_id = target_organization_id
      and membership.user_id = (select auth.uid())
  );
$$;

create or replace function public.has_org_role(
  target_organization_id uuid,
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
    from public.organization_memberships membership
    where membership.organization_id = target_organization_id
      and membership.user_id = (select auth.uid())
      and membership.role = any (allowed_roles)
  );
$$;

create or replace function public.can_access_event(target_event_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.events event_record
    where event_record.id = target_event_id
      and (
        public.is_org_member(event_record.organization_id)
        or exists (
          select 1
          from public.event_organizations event_organization
          where event_organization.event_id = event_record.id
            and public.is_org_member(event_organization.organization_id)
        )
      )
  );
$$;

create or replace function public.has_event_role(
  target_event_id uuid,
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

create or replace function public.create_organization(organization_name text)
returns public.organizations
language plpgsql
security definer
set search_path = ''
as $$
declare
  created_organization public.organizations;
begin
  if (select auth.uid()) is null then
    raise exception using errcode = '42501', message = 'Authentication required';
  end if;

  insert into public.organizations (name)
  values (organization_name)
  returning * into created_organization;

  insert into public.organization_memberships (organization_id, user_id, role)
  values (created_organization.id, (select auth.uid()), 'owner');

  return created_organization;
end;
$$;

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

-- Audit records are created by the database so actor and timestamp cannot be forged.
create or replace function public.record_audit_log(
  target_organization_id uuid,
  target_event_id uuid,
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
  event_organization_id uuid;
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

revoke all on function public.is_org_member(uuid) from public;
revoke all on function public.has_org_role(uuid, public.organization_role[]) from public;
revoke all on function public.can_access_event(uuid) from public;
revoke all on function public.has_event_role(uuid, public.organization_role[]) from public;
revoke all on function public.create_organization(text) from public;
revoke all on function public.check_in_ticket(text, uuid, text) from public;
revoke all on function public.record_audit_log(uuid, uuid, text, text, text, text, jsonb) from public;
grant execute on function public.is_org_member(uuid) to authenticated;
grant execute on function public.has_org_role(uuid, public.organization_role[]) to authenticated;
grant execute on function public.can_access_event(uuid) to authenticated;
grant execute on function public.has_event_role(uuid, public.organization_role[]) to authenticated;
grant execute on function public.create_organization(text) to authenticated;
grant execute on function public.check_in_ticket(text, uuid, text) to authenticated;
grant execute on function public.record_audit_log(uuid, uuid, text, text, text, text, jsonb) to authenticated;

-- RLS remains the authorization boundary after the key migration.
create policy organizations_select_member
  on public.organizations for select to authenticated
  using (public.is_org_member(id));

create policy memberships_select_member
  on public.organization_memberships for select to authenticated
  using (public.is_org_member(organization_id));

create policy events_select_member
  on public.events for select to authenticated
  using (public.can_access_event(id));

create policy events_insert_operator
  on public.events for insert to authenticated
  with check (
    public.has_org_role(organization_id, array['owner', 'ops']::public.organization_role[])
    and created_by = (select auth.uid())
  );

create policy events_update_operator
  on public.events for update to authenticated
  using (public.has_event_role(id, array['owner', 'ops']::public.organization_role[]))
  with check (public.has_event_role(id, array['owner', 'ops']::public.organization_role[]));

create policy event_organizations_select_member
  on public.event_organizations for select to authenticated
  using (public.can_access_event(event_id));

create policy event_organizations_insert_owner
  on public.event_organizations for insert to authenticated
  with check (
    public.has_event_role(event_id, array['owner']::public.organization_role[])
    and role = 'collaborator'
  );

create policy event_status_history_select_member
  on public.event_status_history for select to authenticated
  using (public.can_access_event(event_id));

create policy event_status_history_insert_operator
  on public.event_status_history for insert to authenticated
  with check (
    public.has_event_role(event_id, array['owner', 'ops']::public.organization_role[])
    and actor_user_id = (select auth.uid())
  );

create policy lots_select_member
  on public.lots for select to authenticated
  using (public.can_access_event(event_id));

create policy lots_insert_operator
  on public.lots for insert to authenticated
  with check (public.has_event_role(event_id, array['owner', 'ops']::public.organization_role[]));

create policy lots_update_operator
  on public.lots for update to authenticated
  using (public.has_event_role(event_id, array['owner', 'ops']::public.organization_role[]))
  with check (public.has_event_role(event_id, array['owner', 'ops']::public.organization_role[]));

create policy promoters_select_member
  on public.promoters for select to authenticated
  using (public.can_access_event(event_id));

create policy promoters_insert_operator
  on public.promoters for insert to authenticated
  with check (public.has_event_role(event_id, array['owner', 'ops']::public.organization_role[]));

create policy promoters_update_operator
  on public.promoters for update to authenticated
  using (public.has_event_role(event_id, array['owner', 'ops']::public.organization_role[]))
  with check (public.has_event_role(event_id, array['owner', 'ops']::public.organization_role[]));

create policy orders_select_member
  on public.orders for select to authenticated
  using (public.can_access_event(event_id));

create policy orders_insert_operator
  on public.orders for insert to authenticated
  with check (
    public.has_event_role(event_id, array['owner', 'ops']::public.organization_role[])
    and created_by = (select auth.uid())
  );

create policy orders_update_operator
  on public.orders for update to authenticated
  using (public.has_event_role(event_id, array['owner', 'ops']::public.organization_role[]))
  with check (public.has_event_role(event_id, array['owner', 'ops']::public.organization_role[]));

create policy order_items_select_member
  on public.order_items for select to authenticated
  using (
    exists (
      select 1
      from public.orders order_record
      where order_record.id = order_id
        and public.can_access_event(order_record.event_id)
    )
  );

create policy order_items_insert_operator
  on public.order_items for insert to authenticated
  with check (
    exists (
      select 1
      from public.orders order_record
      join public.lots lot on lot.id = lot_id
      where order_record.id = order_id
        and order_record.event_id = lot.event_id
        and public.has_event_role(order_record.event_id, array['owner', 'ops']::public.organization_role[])
    )
  );

create policy tickets_select_gate
  on public.tickets for select to authenticated
  using (public.has_event_role(event_id, array['owner', 'ops', 'gate']::public.organization_role[]));

create policy tickets_insert_operator
  on public.tickets for insert to authenticated
  with check (public.has_event_role(event_id, array['owner', 'ops']::public.organization_role[]));

create policy check_ins_select_gate
  on public.check_ins for select to authenticated
  using (public.has_event_role(event_id, array['owner', 'ops', 'gate']::public.organization_role[]));

create policy ledger_entries_select_finance
  on public.ledger_entries for select to authenticated
  using (public.has_event_role(event_id, array['owner', 'finance']::public.organization_role[]));

create policy ledger_entries_insert_finance
  on public.ledger_entries for insert to authenticated
  with check (
    public.has_event_role(event_id, array['owner', 'finance']::public.organization_role[])
    and public.is_org_member(organization_id)
    and created_by = (select auth.uid())
  );

create policy audit_logs_select_member
  on public.audit_logs for select to authenticated
  using (
    public.is_org_member(organization_id)
    and (event_id is null or public.can_access_event(event_id))
  );

grant select on public.organizations, public.organization_memberships, public.events,
  public.event_organizations, public.event_status_history, public.lots,
  public.promoters, public.orders, public.order_items, public.tickets, public.check_ins,
  public.ledger_entries, public.audit_logs to authenticated;
grant insert, update on public.events, public.event_organizations, public.event_status_history,
  public.lots, public.promoters, public.orders, public.order_items, public.tickets to authenticated;
grant insert on public.ledger_entries to authenticated;

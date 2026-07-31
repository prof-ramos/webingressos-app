-- Immutable financial ledger and append-only audit trail.

create type public.ledger_entry_kind as enum ('revenue', 'expense', 'commission', 'split', 'payout');
create type public.ledger_entry_status as enum ('previsto', 'aprovado', 'pago');

create table public.ledger_entries (
  id bigint generated always as identity primary key,
  public_id uuid not null default gen_random_uuid() unique,
  organization_id bigint not null references public.organizations (id) on delete restrict,
  event_id bigint not null references public.events (id) on delete restrict,
  kind public.ledger_entry_kind not null,
  status public.ledger_entry_status not null default 'previsto',
  amount_cents bigint not null check (amount_cents >= 0),
  currency text not null default 'BRL' check (currency = 'BRL'),
  description text not null check (char_length(trim(description)) between 1 and 300),
  created_by uuid not null references auth.users (id) on delete restrict,
  approved_by uuid references auth.users (id) on delete restrict,
  paid_at timestamptz,
  occurred_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  check (approved_by is null or status in ('aprovado', 'pago')),
  check (paid_at is null or status = 'pago')
);

create index ledger_entries_organization_id_idx on public.ledger_entries (organization_id);
create index ledger_entries_event_id_status_idx on public.ledger_entries (event_id, status);
create index ledger_entries_event_id_occurred_at_idx
  on public.ledger_entries (event_id, occurred_at desc);

create table public.audit_logs (
  id bigint generated always as identity primary key,
  organization_id bigint not null references public.organizations (id) on delete restrict,
  event_id bigint references public.events (id) on delete restrict,
  actor_user_id uuid references auth.users (id) on delete restrict,
  entity_type text not null check (char_length(trim(entity_type)) between 1 and 80),
  entity_public_id text not null check (char_length(trim(entity_public_id)) between 1 and 160),
  action text not null check (char_length(trim(action)) between 1 and 80),
  reason text,
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata) = 'object'),
  occurred_at timestamptz not null default now()
);

create index audit_logs_organization_id_occurred_at_idx
  on public.audit_logs (organization_id, occurred_at desc);
create index audit_logs_event_id_occurred_at_idx
  on public.audit_logs (event_id, occurred_at desc);
create index audit_logs_entity_idx
  on public.audit_logs (entity_type, entity_public_id);

alter table public.ledger_entries enable row level security;
alter table public.audit_logs enable row level security;

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

create policy audit_logs_insert_member
  on public.audit_logs for insert to authenticated
  with check (
    public.is_org_member(organization_id)
    and (event_id is null or public.can_access_event(event_id))
    and actor_user_id = (select auth.uid())
  );

grant usage on all sequences in schema public to authenticated;
grant select on public.ledger_entries, public.audit_logs to authenticated;
grant insert on public.ledger_entries, public.audit_logs to authenticated;

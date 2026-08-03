-- Ledger rows are created as drafts and advance only through trusted operations.

alter table public.ledger_entries
  add constraint ledger_entries_status_fields_check
  check (
    (status = 'previsto' and approved_by is null and paid_at is null)
    or (status = 'aprovado' and approved_by is not null and paid_at is null)
    or (status = 'pago' and approved_by is not null and paid_at is not null)
  );

create or replace function public.validate_ledger_event_organization()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  event_organization_id bigint;
begin
  select event_record.organization_id
  into event_organization_id
  from public.events as event_record
  where event_record.id = new.event_id;

  if event_organization_id is null
    or new.organization_id is distinct from event_organization_id then
    raise exception using
      errcode = '23514',
      message = 'Ledger organization must match event owner organization';
  end if;

  return new;
end;
$$;

revoke all on function public.validate_ledger_event_organization() from public, authenticated;

drop trigger if exists ledger_event_organization_consistency on public.ledger_entries;
create trigger ledger_event_organization_consistency
  before insert or update of organization_id, event_id on public.ledger_entries
  for each row
  execute function public.validate_ledger_event_organization();

drop policy if exists ledger_entries_insert_finance on public.ledger_entries;
create policy ledger_entries_insert_finance
  on public.ledger_entries for insert to authenticated
  with check (
    status = 'previsto'
    and approved_by is null
    and paid_at is null
    and public.has_event_role(event_id, array['owner', 'finance']::public.organization_role[])
    and public.is_org_member(organization_id)
    and created_by = (select auth.uid())
    and organization_id = (
      select event_record.organization_id
      from public.events as event_record
      where event_record.id = public.ledger_entries.event_id
    )
  );

revoke update, delete on table public.ledger_entries from public, authenticated;

create or replace function public.approve_ledger_entry(
  target_entry_public_id uuid,
  target_reason text
)
returns table (
  public_id uuid,
  status public.ledger_entry_status,
  approved_by uuid,
  paid_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  locked_entry public.ledger_entries%rowtype;
  transition_reason text;
  returned_public_id uuid;
  returned_status public.ledger_entry_status;
  returned_approved_by uuid;
  returned_paid_at timestamptz;
begin
  if (select auth.uid()) is null then
    raise exception using
      errcode = '42501',
      message = 'Authentication required';
  end if;

  select entry_row.*
  into locked_entry
  from public.ledger_entries as entry_row
  where entry_row.public_id = target_entry_public_id
  for update;

  if not found
    or not public.has_event_role(
      locked_entry.event_id,
      array['owner', 'finance']::public.organization_role[]
    ) then
    raise exception using
      errcode = '42501',
      message = 'Not authorized to transition ledger entry';
  end if;

  if locked_entry.status <> 'previsto' then
    raise exception using
      errcode = '22023',
      message = 'Invalid ledger entry status transition';
  end if;

  transition_reason := nullif(trim(coalesce(target_reason, '')), '');
  if transition_reason is null then
    raise exception using
      errcode = '22023',
      message = 'Reason required for ledger entry transition';
  end if;

  update public.ledger_entries as entry_row
  set status = 'aprovado',
      approved_by = (select auth.uid())
  where entry_row.id = locked_entry.id
  returning entry_row.public_id, entry_row.status, entry_row.approved_by, entry_row.paid_at
  into returned_public_id, returned_status, returned_approved_by, returned_paid_at;

  perform public.record_audit_log(
    locked_entry.organization_id,
    locked_entry.event_id,
    'ledger_entry',
    locked_entry.public_id::text,
    'approved',
    transition_reason,
    '{"status":"aprovado"}'::jsonb
  );

  return query
  select returned_public_id, returned_status, returned_approved_by, returned_paid_at;
end;
$$;

revoke all on function public.approve_ledger_entry(uuid, text) from public;
grant execute on function public.approve_ledger_entry(uuid, text) to authenticated;

create or replace function public.pay_ledger_entry(
  target_entry_public_id uuid,
  target_reason text
)
returns table (
  public_id uuid,
  status public.ledger_entry_status,
  approved_by uuid,
  paid_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  locked_entry public.ledger_entries%rowtype;
  transition_reason text;
  transition_at timestamptz;
  returned_public_id uuid;
  returned_status public.ledger_entry_status;
  returned_approved_by uuid;
  returned_paid_at timestamptz;
begin
  if (select auth.uid()) is null then
    raise exception using
      errcode = '42501',
      message = 'Authentication required';
  end if;

  select entry_row.*
  into locked_entry
  from public.ledger_entries as entry_row
  where entry_row.public_id = target_entry_public_id
  for update;

  if not found
    or not public.has_event_role(
      locked_entry.event_id,
      array['owner', 'finance']::public.organization_role[]
    ) then
    raise exception using
      errcode = '42501',
      message = 'Not authorized to transition ledger entry';
  end if;

  if locked_entry.status <> 'aprovado' then
    raise exception using
      errcode = '22023',
      message = 'Invalid ledger entry status transition';
  end if;

  transition_reason := nullif(trim(coalesce(target_reason, '')), '');
  if transition_reason is null then
    raise exception using
      errcode = '22023',
      message = 'Reason required for ledger entry transition';
  end if;

  transition_at := now();

  update public.ledger_entries as entry_row
  set status = 'pago',
      paid_at = transition_at
  where entry_row.id = locked_entry.id
  returning entry_row.public_id, entry_row.status, entry_row.approved_by, entry_row.paid_at
  into returned_public_id, returned_status, returned_approved_by, returned_paid_at;

  perform public.record_audit_log(
    locked_entry.organization_id,
    locked_entry.event_id,
    'ledger_entry',
    locked_entry.public_id::text,
    'paid',
    transition_reason,
    '{"status":"pago"}'::jsonb
  );

  return query
  select returned_public_id, returned_status, returned_approved_by, returned_paid_at;
end;
$$;

revoke all on function public.pay_ledger_entry(uuid, text) from public;
grant execute on function public.pay_ledger_entry(uuid, text) to authenticated;

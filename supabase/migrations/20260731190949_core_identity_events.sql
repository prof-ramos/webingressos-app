-- Core tenant, event, collaboration and lot model.
-- Internal identifiers are database-local identities. Public identifiers are opaque UUIDs.

create type public.organization_role as enum ('owner', 'finance', 'ops', 'gate');
create type public.event_status as enum (
  'rascunho',
  'planejado',
  'vendas_abertas',
  'encerrado',
  'prestacao_contas_fechada',
  'cancelado'
);
create type public.event_organization_role as enum ('owner', 'collaborator');

create table public.organizations (
  id bigint generated always as identity primary key,
  public_id uuid not null default gen_random_uuid() unique,
  name text not null check (char_length(trim(name)) between 2 and 160),
  created_at timestamptz not null default now()
);

create table public.organization_memberships (
  id bigint generated always as identity primary key,
  organization_id bigint not null references public.organizations (id) on delete restrict,
  user_id uuid not null references auth.users (id) on delete cascade,
  role public.organization_role not null,
  created_at timestamptz not null default now(),
  unique (organization_id, user_id)
);

create index organization_memberships_user_org_idx
  on public.organization_memberships (user_id, organization_id);

create table public.events (
  id bigint generated always as identity primary key,
  public_id uuid not null default gen_random_uuid() unique,
  organization_id bigint not null references public.organizations (id) on delete restrict,
  name text not null check (char_length(trim(name)) between 2 and 200),
  status public.event_status not null default 'rascunho',
  starts_at timestamptz,
  ends_at timestamptz,
  created_by uuid not null references auth.users (id) on delete restrict,
  created_at timestamptz not null default now(),
  check (ends_at is null or starts_at is null or ends_at >= starts_at)
);

create index events_organization_id_idx on public.events (organization_id);
create index events_status_idx on public.events (status);

create table public.event_organizations (
  id bigint generated always as identity primary key,
  event_id bigint not null references public.events (id) on delete restrict,
  organization_id bigint not null references public.organizations (id) on delete restrict,
  role public.event_organization_role not null default 'collaborator',
  created_at timestamptz not null default now(),
  unique (event_id, organization_id)
);

create index event_organizations_event_id_idx on public.event_organizations (event_id);
create index event_organizations_organization_id_idx on public.event_organizations (organization_id);

create table public.event_status_history (
  id bigint generated always as identity primary key,
  event_id bigint not null references public.events (id) on delete restrict,
  from_status public.event_status,
  to_status public.event_status not null,
  actor_user_id uuid not null references auth.users (id) on delete restrict,
  reason text,
  occurred_at timestamptz not null default now()
);

create index event_status_history_event_id_occurred_at_idx
  on public.event_status_history (event_id, occurred_at desc);

create table public.lots (
  id bigint generated always as identity primary key,
  public_id uuid not null default gen_random_uuid() unique,
  event_id bigint not null references public.events (id) on delete restrict,
  name text not null check (char_length(trim(name)) between 1 and 160),
  price_cents bigint not null check (price_cents >= 0),
  currency text not null default 'BRL' check (currency = 'BRL'),
  capacity integer check (capacity is null or capacity >= 0),
  sales_start_at timestamptz,
  sales_end_at timestamptz,
  created_at timestamptz not null default now(),
  check (sales_end_at is null or sales_start_at is null or sales_end_at >= sales_start_at)
);

create index lots_event_id_idx on public.lots (event_id);

create or replace function public.is_org_member(target_organization_id bigint)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.organization_memberships membership
    where membership.organization_id = target_organization_id
      and membership.user_id = (select auth.uid())
  );
$$;

create or replace function public.has_org_role(
  target_organization_id bigint,
  allowed_roles public.organization_role[]
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.organization_memberships membership
    where membership.organization_id = target_organization_id
      and membership.user_id = (select auth.uid())
      and membership.role = any (allowed_roles)
  );
$$;

create or replace function public.can_access_event(target_event_id bigint)
returns boolean
language sql
stable
security definer
set search_path = public
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
  target_event_id bigint,
  allowed_roles public.organization_role[]
)
returns boolean
language sql
stable
security definer
set search_path = public
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
      and membership.role = any (allowed_roles)
  );
$$;

create or replace function public.create_organization(organization_name text)
returns public.organizations
language plpgsql
security definer
set search_path = public
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

revoke all on function public.is_org_member(bigint) from public;
revoke all on function public.has_org_role(bigint, public.organization_role[]) from public;
revoke all on function public.can_access_event(bigint) from public;
revoke all on function public.has_event_role(bigint, public.organization_role[]) from public;
revoke all on function public.create_organization(text) from public;
grant execute on function public.is_org_member(bigint) to authenticated;
grant execute on function public.has_org_role(bigint, public.organization_role[]) to authenticated;
grant execute on function public.can_access_event(bigint) to authenticated;
grant execute on function public.has_event_role(bigint, public.organization_role[]) to authenticated;
grant execute on function public.create_organization(text) to authenticated;

alter table public.organizations enable row level security;
alter table public.organization_memberships enable row level security;
alter table public.events enable row level security;
alter table public.event_organizations enable row level security;
alter table public.event_status_history enable row level security;
alter table public.lots enable row level security;

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

-- The current Supabase project configuration does not auto-expose new tables.
-- Keep grants explicit and let RLS remain the authorization boundary.
grant usage on all sequences in schema public to authenticated;
grant select on public.organizations, public.organization_memberships, public.events,
  public.event_organizations, public.event_status_history, public.lots to authenticated;
grant insert, update on public.events, public.event_organizations, public.event_status_history,
  public.lots to authenticated;

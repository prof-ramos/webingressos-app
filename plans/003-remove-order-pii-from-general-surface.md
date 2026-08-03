# Plan 003: Remove order PII from the general authenticated surface

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the next
> step. If anything in the "STOP conditions" section occurs, stop and report —
> do not improvise. When done, update the status row for this plan in
> `plans/README.md`, unless a reviewer dispatched you and told you they maintain
> the index.
>
> **Drift check (run first)**: `git diff --stat 9a45666..HEAD -- supabase/migrations/20260803080000_orders_privacy.sql supabase/tests/database/rls_and_check_in.sql src/lib/supabase/database.types.ts supabase/README.md`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts with the live files. A mismatch is a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: `plans/001-establish-verification-baseline.md`
- **Category**: security
- **Planned at**: commit `9a45666`, 2026-08-03
- **Issue**: https://github.com/prof-ramos/webingressos-app/issues/7

## Why this matters

The `gate` role exists to operate entrance validation, not to inspect buyers'
personal data. The current `orders` table grant and select policy expose every
column to every member who can access the event, including `buyer_name`,
`buyer_email`, and `buyer_phone`. Because the database is intentionally the
authorization boundary, a direct Supabase client can bypass any future UI hiding
unless the table surface itself is changed.

## Current state

- `supabase/migrations/20260731190951_sales_operations.sql:18-35` defines
  `orders` with buyer name, e-mail, phone, total, currency, status, and audit
  ownership fields in one table.
- `:98-100` grants every event member the `orders_select_member` row policy using
  `can_access_event(event_id)`; that helper admits all organization roles for an
  accessible event.
- `:238-241` grants `select` on the complete `orders` table to the database role
  `authenticated`.
- The existing app has no real order reader (`README.md:26-29`), so this change
  can establish the safe database surface before a UI starts depending on the
  raw table.
- The existing pgTAP fixture creates order A and order B at
  `supabase/tests/database/rls_and_check_in.sql:83-101`; user 1 is owner of A,
  user 3 is gate in A, and user 4 is finance in A (`:7-13,21-34`).

The product vocabulary limits access by organization/event and assigns `gate` to
entry operation (`CONTEXT.md:4-18`). It does not say that gate staff need buyer
contact details.

The current table-level exposure is explicit:

```sql
-- supabase/migrations/20260731190951_sales_operations.sql:98-100,238-241
create policy orders_select_member
  on public.orders for select to authenticated
  using (public.can_access_event(event_id));

grant select on public.promoters, public.orders, public.order_items,
  public.tickets, public.check_ins to authenticated;
```

`can_access_event` is a row/tenant check, not a role-specific column filter. The
replacement must therefore change both the SQL privilege surface and the safe
read shape.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Local reset | `pnpm exec supabase db reset` | New migration applies to disposable local DB |
| Database tests | `pnpm supabase:test` | All RLS/privacy assertions pass |
| Type generation | `pnpm supabase:types` | Generated table/view/function types reflect schema; inspect diff |
| App verification | `pnpm check` | Exit 0 |
| Cleanup | `pnpm exec supabase stop` | Local stack stops; no remote mutation |
| Diff hygiene | `git diff --check` | No whitespace errors |

## Scope

**In scope** — only these files may be modified:

- `supabase/migrations/20260803080000_orders_privacy.sql` (create; if this
  filename exists, stop and choose a later migration name)
- `supabase/tests/database/rls_and_check_in.sql`
- `src/lib/supabase/database.types.ts` (generated only)
- `supabase/README.md`
- `plans/README.md` (status row only)

**Out of scope**:

- UI screens or application order queries; none exist yet.
- `buyer_*` schema deletion or irreversible data migration.
- Changes to tickets, check-in, ledger, or event status.
- Granting `service_role` or any secret to the browser.

## Git workflow

Use a topic branch such as `advisor/003-orders-privacy`; do not push or open a
PR unless instructed. Create a new migration and never edit the existing sales
migration.

## Steps

### Step 1: Replace direct table reads with a safe operational view

Create a `public.orders_operational` view containing only fields needed for
non-PII operational list work: `id`, `public_id`, `event_id`, `promoter_id`,
`status`, `total_cents`, `currency`, `created_by`, and `created_at`. Do not include
`buyer_name`, `buyer_email`, or `buyer_phone`. Define it with PostgreSQL's
`security_invoker = true` option so the caller's RLS context is used when the
view reads `public.orders`.

Revoke `select` on `public.orders` from `authenticated`, retain the existing
row policy for the underlying table, and grant `select` on the safe view to
`authenticated`. Do not grant the raw table back through a later statement. Keep
existing insert/update grants unchanged for now; no app path currently uses them.
If a future PostgREST mutation needs a returned row, it must use a minimal return
or an explicit safe RPC rather than restoring raw-table select.

**Verify**: `pnpm exec supabase db reset` → migration applies; as an authenticated
gate fixture, `select * from public.orders` → permission denied, while
`select public_id, status, total_cents from public.orders_operational` → only
event-A rows are returned.

### Step 2: Add an explicitly privileged customer-detail operation

Add a narrowly scoped `security definer` function named
`public.get_order_customer(target_order_public_id uuid)` returning only the
public order ID and the three customer fields. It must:

1. set `search_path = ''` and schema-qualify all references;
2. reject an unauthenticated caller;
3. locate the order by `public_id`, not internal ID;
4. require `has_event_role(order.event_id, array['owner','ops','finance'])`;
5. return no customer row for an unknown order or raise a controlled authorization
   error without disclosing whether a gate caller guessed a valid ID;
6. grant `execute` only to `authenticated` and never grant raw table select.

The function is for a future owner/ops/finance screen; the current app does not
need a caller. Do not permit `gate` or an arbitrary organization member to use it.
Do not log customer fields in errors or audit metadata.

**Verify**: in pgTAP, owner and finance can retrieve the fixture's customer fields
after adding non-sensitive fixture values; gate receives the chosen authorization
error and no PII; a user from organization B cannot retrieve order A.

### Step 3: Extend the RLS/privacy regression suite

Update the pgTAP plan count and add assertions using the existing five fixture
users:

- owner A can read order A through `orders_operational`;
- gate A can read safe operational fields but cannot select the raw table;
- gate A cannot execute `get_order_customer`;
- finance A can execute it and receives only the three intended customer fields;
- organization B cannot see event-A rows through the view or customer function;
- no query path available to `authenticated` returns `buyer_name`,
  `buyer_email`, or `buyer_phone` except the privileged function.

Use deterministic fixture values and do not add real-looking personal data beyond
the existing `.example` test convention. Preserve the existing check-in and RLS
assertions.

**Verify**: `pnpm supabase:test` → every privacy assertion and all prior assertions pass.

### Step 4: Regenerate types and document the access contract

Run `pnpm supabase:types`, inspect the generated view/function sections, and keep
the generated result without hand-editing it. Update `supabase/README.md` to state
that `orders` is not a general authenticated read surface, that
`orders_operational` omits customer PII, and that customer details require the
role-checked function.

**Verify**: `pnpm typecheck` and `pnpm check` → exit 0; `git diff --check` → no output.

## Test plan

- Model the tests after the fixture and role-switching pattern already used in
  `supabase/tests/database/rls_and_check_in.sql:165-171,253-296`.
- Test both positive safe-view access and negative raw-table/function access.
- Test a second organization to ensure the new view did not accidentally bypass
  the existing `can_access_event` RLS boundary.
- Verify column minimization by selecting the view's complete row and asserting
  only the documented safe columns exist in generated types/schema inspection.

## Done criteria

- [ ] `authenticated` has no `select` privilege on `public.orders`.
- [ ] `orders_operational` is security-invoker and contains no buyer columns.
- [ ] `get_order_customer` is the only authenticated customer-detail path and
      accepts only owner/ops/finance event roles.
- [ ] Gate and cross-organization negative cases pass in pgTAP.
- [ ] `pnpm supabase:test`, `pnpm typecheck`, and `pnpm check` exit 0.
- [ ] No PII appears in test failure messages, logs, or documentation.
- [ ] No files outside the in-scope list are modified; `plans/README.md` only has
      this plan's status update.
- [ ] `plans/README.md` status row is updated to `DONE`.

## STOP conditions

Stop and report if:

- PostgreSQL/Supabase does not support the requested security-invoker view syntax
  in the pinned local database version;
- a required current caller depends on raw `orders` select (there is no such
  caller at the planned SHA, but verify before revoking the grant);
- the product requires `gate` to see customer details; document the minimum
  fields and obtain a revised authorization decision instead of widening access;
- `organization_id`/event collaboration semantics require a different role matrix
  than owner/ops/finance;
- a generated type or test failure suggests the view bypasses RLS.

## Maintenance notes

Keep new customer fields out of general operational views by default. Any future
role that needs buyer data must receive an explicit, reviewed function or view and
an RLS regression test. Reviewers should check both SQL privileges and RLS: a safe
UI is not sufficient if the raw table remains selectable through PostgREST.

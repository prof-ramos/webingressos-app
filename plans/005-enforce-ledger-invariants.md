# Plan 005: Enforce ledger approval and payment invariants

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the next
> step. If anything in the "STOP conditions" section occurs, stop and report —
> do not improvise. When done, update the status row for this plan in
> `plans/README.md`, unless a reviewer dispatched you and told you they maintain
> the index.
>
> **Drift check (run first)**: `git diff --stat 9a45666..HEAD -- supabase/migrations/20260803100000_ledger_invariants.sql supabase/tests/database/rls_and_check_in.sql src/lib/supabase/database.types.ts supabase/README.md`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts with the live files. A mismatch is a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: HIGH
- **Depends on**: `plans/001-establish-verification-baseline.md`, `plans/002-restrict-audit-log-writes.md`
- **Category**: security / bug
- **Planned at**: commit `9a45666`, 2026-08-03
- **Issue**: https://github.com/prof-ramos/webingressos-app/issues/9

## Why this matters

The financial ledger is documented as an immutable, auditable operational book,
but its insert policy accepts the full status and approval columns. A finance
user can therefore create a row already marked `pago`, leave `approved_by` null,
or name another user as approver. The existing checks only establish that the
values are structurally compatible; they do not enforce the lifecycle or actor.
This undermines settlement reports before any UI exists.

## Current state

- `supabase/migrations/20260731190953_finance_audit.sql:6-23` defines
  `ledger_entries` with `status` (`previsto`, `aprovado`, `pago`),
  `approved_by`, `paid_at`, amount, event, organization, and creator.
- Its checks at `:21-22` allow `approved_by` to be null for `pago` and only
  require `paid_at` to be non-null-compatible with `pago`; they do not enforce
  who approved or paid the entry.
- `:53-63` permits owner/finance event roles to insert a row as long as
  `created_by = auth.uid()` and `organization_id` is any organization the actor
  belongs to. It does not require initial `status = 'previsto'`, null approval,
  or that the organization is the event's owning organization.
- `:80-82` grants select and insert but no update/delete to `authenticated`, so
  the primary current flaw is forged state at creation, not an update route.
- The test fixture inserts one revenue row at
  `supabase/tests/database/rls_and_check_in.sql:147-163` but never tests invalid
  initial states, cross-organization association, or approval/payment actors.

`CONTEXT.md:22-25` says financial records are immutable and corrections are new
records or auditable transitions. `finance/domain.ts:3-17` mirrors the three
statuses and BRL cent semantics. The schema's `organization_id` needs an explicit
decision: this plan assumes a ledger entry belongs to the event's owning
organization, because `events.organization_id` is the tenant owner. If the
product intends separate collaborator ledgers, stop before implementing the
constraint and model that relationship explicitly.

The current checks and policy are permissive in exactly the fields that need to
be trusted:

```sql
-- supabase/migrations/20260731190953_finance_audit.sql:21-22,57-63
check (approved_by is null or status in ('aprovado', 'pago')),
check (paid_at is null or status = 'pago')

create policy ledger_entries_insert_finance
  on public.ledger_entries for insert to authenticated
  with check (
    public.has_event_role(event_id, array['owner', 'finance']::public.organization_role[])
    and public.is_org_member(organization_id)
    and created_by = (select auth.uid())
  );
```

The new policy and operation-specific functions must derive approval/payment
actors and timestamps in the database rather than trusting insert fields.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Local reset | `pnpm exec supabase db reset` | New ledger migration applies cleanly |
| Database tests | `pnpm supabase:test` | Initial-state, role, transition, and audit assertions pass |
| Type generation | `pnpm supabase:types` | New RPC signatures are reflected in generated types |
| App verification | `pnpm check` | Exit 0 |
| Cleanup | `pnpm exec supabase stop` | Local stack stops; no remote mutation |
| Diff hygiene | `git diff --check` | No whitespace errors |

## Scope

**In scope** — only these files may be modified:

- `supabase/migrations/20260803100000_ledger_invariants.sql` (create; if this
  filename exists, stop and choose a later migration name)
- `supabase/tests/database/rls_and_check_in.sql`
- `src/lib/supabase/database.types.ts` (generated only)
- `supabase/README.md`
- `plans/README.md` (status row only)

**Out of scope**:

- Existing finance migration or any unrelated migration.
- UI, payment gateways, external payout integrations, or background jobs.
- A collaborator-ledger model unless the owner organization assumption is
  explicitly revised first.
- Direct use of a service-role key from application or browser code.

## Git workflow

Use a topic branch such as `advisor/005-ledger-invariants`; do not push or open a
PR unless instructed. Create a new migration and never edit applied history.

## Steps

### Step 1: Restrict direct ledger creation to a valid draft

In the new migration, replace the current broad insert surface with a policy and
constraints that require:

- `status = 'previsto'`;
- `approved_by is null`;
- `paid_at is null`;
- `created_by = (select auth.uid())`;
- the actor has owner/finance role for the event;
- `organization_id` equals `events.organization_id` for the referenced event;
- amount/currency/description remain governed by the existing checks.

Use a schema-qualified trigger or policy expression for the cross-row
organization invariant. A policy `with check` must not rely on an untrusted
client-supplied event/organization pair; resolve the event row in the database.
Do not grant update/delete to authenticated.

**Verify**: as finance user 4, a normal draft revenue insert succeeds; inserts
with `status = 'aprovado'`, `status = 'pago'`, non-null `approved_by`, or non-null
`paid_at` are denied; an organization-B/event-A mismatch is denied.

### Step 2: Add trusted approval and payment transitions

Add two operation-specific `security definer` functions, using public order-style
identifiers where a row leaves the database boundary:

- `approve_ledger_entry(target_entry_public_id uuid, target_reason text)` — locks
  the entry, requires an authenticated owner/finance event role, requires current
  status `previsto`, requires a non-empty reason, sets `status = 'aprovado'` and
  `approved_by = auth.uid()`, and records an audit row through the private trusted
  helper established in Plan 002.
- `pay_ledger_entry(target_entry_public_id uuid, target_reason text)` — locks the
  entry, requires current status `aprovado`, requires a non-empty reason, sets
  `status = 'pago'`, sets `paid_at = now()`, preserves `approved_by`, and records
  an audit row through the same trusted path.

Both functions must use `search_path = ''`, schema-qualified references, a short
transaction, and stable errors for missing/unauthorized/invalid-state cases. Do
not allow a caller to supply `approved_by`, `paid_at`, actor, or timestamp. Do not
create a generic status-update RPC.

If the private audit helper from Plan 002 is not callable from a trusted function,
stop and resolve that dependency; do not restore public audit execution.

**Verify**: a valid draft→approved→paid sequence returns the expected statuses,
actor, timestamp fields, and two audit rows; repeating either transition is
rejected without changing the row.

### Step 3: Add database constraints that make impossible rows unrepresentable

Add only constraints that are compatible with the transition functions:

- `status = 'previsto'` implies `approved_by is null` and `paid_at is null`;
- `status = 'aprovado'` implies `approved_by is not null` and `paid_at is null`;
- `status = 'pago'` implies `approved_by is not null` and `paid_at is not null`;
- `paid_at` cannot be present before `pago`;
- `approved_by` cannot be present before `aprovado`.

Use `is distinct from` where null semantics matter. Do not add a constraint that
requires `approved_by <> created_by`; the domain does not state that segregation
of duties is mandatory. If that policy is required, stop and ask for a separate
decision rather than silently enforcing it.

**Verify**: `pnpm exec supabase db reset` → migration succeeds on existing valid
fixtures; direct SQL attempts for each impossible combination fail with the
expected constraint or policy error.

### Step 4: Extend pgTAP for lifecycle, authorization, and audit

Update `select plan(n)` and add assertions covering:

- finance and owner can create only `previsto` rows for their event;
- gate cannot insert, approve, or pay;
- organization B cannot attach its organization ID to event A;
- direct table update/delete remain denied;
- approval sets the session user as `approved_by` and requires a reason;
- payment sets `paid_at` and preserves the approver;
- invalid or repeated transitions are atomic and create no audit row;
- audit rows contain the correct event/entity/action/actor and do not contain
  sensitive credentials or arbitrary caller-selected actor values.

Use the existing user 1 owner, user 3 gate, and user 4 finance fixtures. Keep the
existing check-in/RLS assertions and ensure the fixture's initial ledger row
remains valid under the new constraints.

**Verify**: `pnpm supabase:test` → all existing and new assertions pass.

### Step 5: Regenerate types and document the ledger contract

Run `pnpm supabase:types`, inspect the generated function signatures, and keep
the generated file without manual edits. Update `supabase/README.md` with the
draft-only insert rule, the approved/payment transition functions, required
reasons, and the assumption that `organization_id` matches the event owner.

**Verify**: `pnpm typecheck` and `pnpm check` → exit 0; `git diff --check` → no output.

## Test plan

Model SQL setup and role switching on
`supabase/tests/database/rls_and_check_in.sql:147-171,253-296`. Assert database
state after every rejected operation, not only the error code. Use a transaction
and deterministic timestamps only where the function contract permits; never
assert an exact wall-clock value.

## Done criteria

- [ ] Authenticated clients can insert only valid `previsto` ledger entries.
- [ ] Cross-organization event/ledger associations are denied under the stated
      owner-organization model.
- [ ] Approval and payment are operation-specific, locked, actor-derived, and
      reason-required.
- [ ] Impossible status/approval/payment combinations fail at the database layer.
- [ ] Gate and unauthorized organization cases are covered by pgTAP.
- [ ] Each successful sensitive transition creates a trusted audit row.
- [ ] `pnpm supabase:test`, `pnpm typecheck`, and `pnpm check` exit 0.
- [ ] No existing migration is edited and no remote push is performed.
- [ ] No files outside the in-scope list are modified; `plans/README.md` only has
      this plan's status update.
- [ ] `plans/README.md` status row is updated to `DONE`.

## STOP conditions

Stop and report if:

- the product requires ledger rows owned by collaborator organizations rather than
  the event's owning organization;
- the private audit helper from Plan 002 is still publicly executable or cannot be
  called safely by trusted transition functions;
- an existing valid row violates the proposed invariant and its correction would
  require deleting or rewriting financial history;
- payment needs external gateway confirmation, idempotency keys, or a queue;
  those are outside this plan;
- the domain requires segregation of duties or reversal entries beyond the three
  statuses currently documented.

## Maintenance notes

Treat `ledger_entries` as an append-only financial record. Future corrections must
be compensating entries or explicit transitions, never a broad update grant.
Reviewers should verify that all actor/time fields are assigned by the database,
that approval/payment operations lock the row, and that audit insertion cannot be
reached through a generic client RPC.

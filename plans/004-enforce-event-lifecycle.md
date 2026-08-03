# Plan 004: Enforce the event lifecycle and status history

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the next
> step. If anything in the "STOP conditions" section occurs, stop and report —
> do not improvise. When done, update the status row for this plan in
> `plans/README.md`, unless a reviewer dispatched you and told you they maintain
> the index.
>
> **Drift check (run first)**: `git diff --stat 9a45666..HEAD -- supabase/migrations/20260803090000_event_lifecycle.sql supabase/tests/database/rls_and_check_in.sql src/lib/supabase/database.types.ts supabase/README.md CONTEXT.md`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts with the live files. A mismatch is a STOP condition.

## Status

- **Priority**: P1
- **Effort**: L
- **Risk**: HIGH
- **Depends on**: `plans/001-establish-verification-baseline.md`
- **Category**: bug / tech-debt
- **Planned at**: commit `9a45666`, 2026-08-03
- **Issue**: https://github.com/prof-ramos/webingressos-app/issues/8

## Why this matters

`events.status` is the product's state machine, but the current RLS policy treats
it as an ordinary mutable column. An owner or operator can write any enum value,
skip required stages, move backward, and separately insert a fabricated status
history row. The database therefore accepts states that contradict
`CONTEXT.md`, and later operations cannot safely use status as an authorization or
workflow boundary.

## Current state

- `CONTEXT.md:20-25` defines the lifecycle as
  `rascunho → planejado → vendas abertas → encerrado → prestação de contas
  fechada`, with `cancelado` possible before closing.
- `supabase/migrations/20260731190949_core_identity_events.sql:34-45` stores the
  enum status but only validates event dates.
- `:228-242` gives members select access and gives owner/ops a general update
  policy with no transition check and no restriction on the status column.
- `:62-73` stores `event_status_history`, but `:255-264` lets owner/ops insert
  any `from_status` and `to_status` pair as long as `actor_user_id` equals the
  session user.
- `supabase/migrations/20260803060000_security_hardening.sql:45-66` protects
  event ownership fields only; it does not protect `status` or history.
- `:268-277` allows lot writes based on role alone; this plan will establish the
  event transition boundary but will not invent every future sales/check-in
  policy.

The existing test fixture creates events already in `vendas_abertas`
(`supabase/tests/database/rls_and_check_in.sql:46-64`), so new transition tests
must create a separate draft event or temporarily use explicit fixture rows.

The current policies leave both status and history caller-controlled:

```sql
-- supabase/migrations/20260731190949_core_identity_events.sql:239-242,259-264
create policy events_update_operator
  on public.events for update to authenticated
  using (public.has_event_role(id, array['owner', 'ops']::public.organization_role[]))
  with check (public.has_event_role(id, array['owner', 'ops']::public.organization_role[]));

create policy event_status_history_insert_operator
  on public.event_status_history for insert to authenticated
  with check (
    public.has_event_role(event_id, array['owner', 'ops']::public.organization_role[])
    and actor_user_id = (select auth.uid())
  );
```

The replacement must retain organization/event authorization while moving status
mutation and history creation into one atomic operation.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Local reset | `pnpm exec supabase db reset` | New lifecycle migration applies cleanly |
| Database tests | `pnpm supabase:test` | Valid/invalid transitions and history assertions pass |
| Type generation | `pnpm supabase:types` | New RPC types match the migration |
| App verification | `pnpm check` | Exit 0 |
| Cleanup | `pnpm exec supabase stop` | Local stack stops; no remote mutation |
| Diff hygiene | `git diff --check` | No whitespace errors |

## Scope

**In scope** — only these files may be modified:

- `supabase/migrations/20260803090000_event_lifecycle.sql` (create; if this
  filename exists, stop and choose a later migration name)
- `supabase/tests/database/rls_and_check_in.sql`
- `src/lib/supabase/database.types.ts` (generated only)
- `supabase/README.md`
- `CONTEXT.md` only if the executor discovers that the documented transition
  matrix must be clarified; do not silently change product vocabulary.
- `plans/README.md` (status row only)

**Out of scope**:

- Existing migrations and unrelated order, ticket, ledger, or PII policies.
- UI routes, forms, or event data fetching.
- Offline check-in behavior; ADR 0003 explicitly keeps that for later.
- A broad rewrite of all event business rules.

## Git workflow

Use a topic branch such as `advisor/004-event-lifecycle`; do not push or open a
PR unless instructed. Create a new migration and never edit applied history.

## Steps

### Step 1: Encode the documented transition matrix in a trusted helper

In the new migration, add a private SQL/plpgsql helper that answers whether a
transition is allowed. Use this default matrix, directly derived from
`CONTEXT.md`:

| Current | Allowed next states |
|---|---|
| `rascunho` | `planejado`, `cancelado` |
| `planejado` | `vendas_abertas`, `cancelado` |
| `vendas_abertas` | `encerrado`, `cancelado` |
| `encerrado` | `prestacao_contas_fechada`, `cancelado` |
| `prestacao_contas_fechada` | none |
| `cancelado` | none |

Use the exact enum values, not display labels. Make the helper schema-qualified,
`search_path = ''`, and unavailable to `anon`/`authenticated` callers unless it
needs to be invoked only by the public transition function.

**Verify**: `pnpm exec supabase db reset` → enum/helper creation succeeds; add
temporary or permanent pgTAP assertions for every allowed and denied matrix edge.

### Step 2: Add an atomic `transition_event` RPC

Create `public.transition_event(target_event_public_id uuid,
target_to_status public.event_status, target_reason text default null)` as a
`security definer` function with `search_path = ''`. It must:

1. reject unauthenticated callers;
2. locate and lock the event row by public ID (`FOR UPDATE`);
3. require `has_event_role(event_id, array['owner','ops'])`;
4. reject same-state and non-matrix transitions with a stable controlled error;
5. require a trimmed non-empty reason for both `cancelado` and
   `prestacao_contas_fechada`, because `CONTEXT.md` makes reasons mandatory for
   sensitive changes including closing;
6. update only `events.status`;
7. insert one history row with the locked prior status, target status, session
   actor, reason, and one database timestamp;
8. return the updated event or a small typed result without exposing internal IDs
   unnecessarily.

The row lock and update/history write must be in the same function transaction.
Revoke `EXECUTE` from public and grant it only to `authenticated`.

**Verify**: `pnpm supabase:test` → a valid transition changes exactly one event
and creates exactly one matching history row; an invalid transition changes
nothing and creates no history row.

### Step 3: Remove direct client control over status and history

Revoke table-level update on `events` and insert on `event_status_history` from
`authenticated`. There is no current application caller that needs direct event
detail updates at the planned SHA, so do not restore column-level update grants in
this plan; a future event-detail RPC can be designed separately.

Change the event insert policy so clients can create only `status = 'rascunho'`
with `created_by = auth.uid()`. Add an `after insert` security-definer trigger
function for the initial history row; it must write
`from_status = null`, `to_status = 'rascunho'`, and actor equal to `created_by`.
The trigger must use `search_path = ''`, schema-qualified objects, and must not be
callable by authenticated clients. If the trigger cannot be made safe, stop
instead of leaving event creation without trusted history.

Remove or disable the direct `event_status_history` insert policy after the
transition function and initial creation path are in place. Do not leave a broad
grant that makes the policy ineffective.

**Verify**: as an authenticated owner, direct `update events set status = ...`
and direct history insert → permission denied; updating permitted detail columns
still succeeds; `transition_event` remains callable.

### Step 4: Add complete lifecycle regression tests

Extend the existing pgTAP suite and update `select plan(n)` exactly. Cover:

- valid forward transitions from draft through closed;
- cancellation from each pre-close state, with required reason;
- invalid skips, backward moves, same-state moves, and transitions out of
  `cancelado` or `prestacao_contas_fechada`;
- gate and collaborator roles cannot transition the event;
- direct status updates and history inserts are denied;
- `from_status`, `to_status`, `actor_user_id`, and reason in history match the
  actual trusted transition;
- two sequential calls cannot create duplicate history for one transition.

Use a dedicated draft event fixture and keep existing event A/B check-in fixtures
unchanged unless a test needs a local copy.

**Verify**: `pnpm supabase:test` → all prior RLS/check-in tests plus lifecycle
tests pass; no test performs a linked or remote migration.

### Step 5: Regenerate types and document the write boundary

Run `pnpm supabase:types` and inspect the generated `transition_event` function
signature. Update `supabase/README.md` with the lifecycle matrix, the RPC as the
only status-transition path, and the rule that applied migrations are never
edited.

**Verify**: `pnpm typecheck` and `pnpm check` → exit 0; `git diff --check` → no output.

## Test plan

Follow the role-switching and fixture style in
`supabase/tests/database/rls_and_check_in.sql:165-171,253-324`. Assertions must
check both returned errors and persisted state, because an error after a partial
update would still be a bug. Include a reason test for cancellation and closure,
and verify the audit/history row is not written on rejected transitions.

## Done criteria

- [ ] The documented lifecycle matrix is encoded in one trusted helper.
- [ ] `transition_event` locks, validates, updates, and records history atomically.
- [ ] Clients cannot update `events.status` or insert arbitrary history rows.
- [ ] New events start only in `rascunho` and cannot choose a forged status.
- [ ] All lifecycle and existing pgTAP assertions pass.
- [ ] `pnpm supabase:test`, `pnpm typecheck`, and `pnpm check` exit 0.
- [ ] No existing migration is edited and no remote push is performed.
- [ ] No files outside the in-scope list are modified; `plans/README.md` only has
      this plan's status update.
- [ ] `plans/README.md` status row is updated to `DONE`.

## STOP conditions

Stop and report if:

- product owners intend a transition matrix different from the table above;
- `encerrado -> cancelado` or the required-reason rule is disputed;
- existing application code depends on direct status updates (none exists at the
  planned SHA, but verify before revoking privileges);
- column-level grants cannot preserve event detail editing without restoring
  status mutation;
- a trigger or helper would need to call a future audit API not covered by Plan 002;
- a failed test indicates an unrelated RLS or check-in regression.

## Maintenance notes

Every new event operation must declare which event states it accepts; do not
assume that a role check alone is sufficient. Reviewers should verify that status
changes and history rows are inseparable, that reasons are not silently trimmed
to empty strings, and that no new direct update grant includes `status`.

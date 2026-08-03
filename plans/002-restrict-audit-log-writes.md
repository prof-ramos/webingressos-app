# Plan 002: Restrict audit-log creation to trusted database operations

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the next
> step. If anything in the "STOP conditions" section occurs, stop and report —
> do not improvise. When done, update the status row for this plan in
> `plans/README.md`, unless a reviewer dispatched you and told you they maintain
> the index.
>
> **Drift check (run first)**: `git diff --stat 9a45666..HEAD -- supabase/migrations/20260803070351_audit_integrity.sql supabase/tests/database/rls_and_check_in.sql src/lib/supabase/database.types.ts supabase/README.md`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts with the live files. A mismatch is a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: HIGH
- **Depends on**: `plans/001-establish-verification-baseline.md`
- **Category**: security
- **Planned at**: commit `9a45666`, 2026-08-03
- **Issue**: https://github.com/prof-ramos/webingressos-app/issues/6

## Why this matters

The audit table is intended to be append-only and to preserve the authenticated
actor for relevant actions. The current public `record_audit_log` RPC is a generic
`security definer` function callable by every authenticated member who can see an
organization or event. It lets a low-privilege member choose arbitrary entity,
action, reason, and metadata values, so the resulting row is actor-authenticated
but not action-authenticated. This makes the audit trail unsuitable as evidence
of who actually performed a business operation.

## Current state

- `supabase/migrations/20260731190953_finance_audit.sql:30-40` defines
  `audit_logs` with actor, organization, optional event, entity, action, reason,
  metadata, and timestamp.
- `supabase/migrations/20260731190953_finance_audit.sql:65-78` originally gives
  every organization member an insert policy as long as `actor_user_id` equals
  `auth.uid()`.
- `supabase/migrations/20260803060000_security_hardening.sql:194-196` removes
  that direct policy and revokes table insert, but
  `:198-266` then exposes `record_audit_log(...)` to `authenticated`.
- The function checks authentication and event/organization access at
  `:216-235`, derives the actor at `:248-257`, and inserts caller-provided
  `target_entity_type`, `target_entity_public_id`, `target_action`,
  `target_reason`, and `target_metadata` without checking that an operation
  actually occurred.
- `supabase/tests/database/rls_and_check_in.sql:351-363` currently calls the
  public RPC as the owner and treats a successful arbitrary audit insert as the
  expected behavior. The existing test at `:372-386` only proves direct table
  inserts are denied.
- No current application operation calls this RPC; the app still has no real
  business-data mutation path (`README.md:26-29`).

The repository's documented vocabulary requires audit records to be append-only,
with actor, organization, entity, action, and a reason when applicable
(`CONTEXT.md:27-30`). It does not require a generic client-side audit API.

The vulnerable boundary is visible in this current excerpt:

```sql
-- supabase/migrations/20260803060000_security_hardening.sql:198-205,265-266
create or replace function public.record_audit_log(
  target_organization_id bigint,
  target_event_id bigint,
  target_entity_type text,
  target_entity_public_id text,
  target_action text,
  target_reason text default null,
  target_metadata jsonb default '{}'::jsonb
)
returns public.audit_logs
language plpgsql
security definer
set search_path = '';

grant execute on function public.record_audit_log(
  bigint, bigint, text, text, text, text, jsonb
) to authenticated;
```

The executor must preserve the secure function conventions (`security definer`,
empty search path, fully qualified objects) while removing the untrusted execute
grant.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Drift/type baseline | `pnpm check` | Exit 0 |
| Local database | `pnpm exec supabase start` | Disposable local stack starts |
| pgTAP | `pnpm supabase:test` | All assertions pass, including new audit-denial cases |
| Generated types | `pnpm supabase:types` | `src/lib/supabase/database.types.ts` matches the local schema; inspect diff before keeping it |
| Cleanup | `pnpm exec supabase stop` | Local stack stops; no remote mutation |
| Diff hygiene | `git diff --check` | No whitespace errors |

## Scope

**In scope** — only these files may be modified:

- `supabase/migrations/20260803070351_audit_integrity.sql` (create; if this
  filename already exists, stop and choose a later migration name)
- `supabase/tests/database/rls_and_check_in.sql`
- `src/lib/supabase/database.types.ts` (generated only through the documented
  command, if the schema change changes its function surface)
- `supabase/README.md`
- `plans/README.md` (status row only)

**Out of scope**:

- Existing migrations; never rewrite applied history.
- Application components, route handlers, or a generic server-side logging API.
- Any change that adds a service-role key or bypasses RLS from the browser.
- Inventing audit rows for operations that do not yet exist.

## Git workflow

Use a topic branch such as `advisor/002-audit-integrity`; do not push or open a
PR unless instructed. Create the migration as a new file. Do not run
`supabase db push --linked`.

## Steps

### Step 1: Add a migration that removes the public generic write surface

Create the new migration and explicitly revoke `EXECUTE` on the exact
`record_audit_log(bigint, bigint, text, text, text, text, jsonb)` signature from
both `public` and `authenticated`. Keep direct table insert revoked. Preserve
the function only as an internal helper if future trusted database functions
need it; its owner must retain the ability to call it from a security-definer
operation. Keep `search_path = ''`, schema-qualify every relation/type, and
retain the authenticated actor derivation and event/organization consistency
checks inside the helper.

Do not replace this with a new generic RPC under another name. The security goal
is that a client cannot choose an arbitrary audit action. Future operations must
write their own audit row inside the same trusted transaction, or call this
private helper from a narrowly authorized operation-specific function.

**Verify**: `pnpm exec supabase db reset` → local migrations apply without errors.
Do not run the full pgTAP suite until Step 2: the current suite intentionally
expects the owner to execute this RPC, so it must first be updated to assert the
new denial behavior.

### Step 2: Update pgTAP to prove client audit forgery is denied

Change the test suite's plan count to match the final assertion count. Replace
the owner success assertion at `:351-363` with a `throws_ok` assertion for the
same public RPC signature, using SQLSTATE `42501` or the exact permission error
observed from the local database. Add denial assertions for:

1. an owner attempting the RPC;
2. a `gate` member attempting the RPC for an event they can access;
3. a member attempting a direct `audit_logs` insert;
4. the audit row count remaining unchanged after all denied attempts.

Keep the existing positive read assertion for audit rows if useful. Do not test
the removed behavior as a success, and do not use a superuser call as evidence
that the public API is safe.

**Verify**: `pnpm supabase:test` → all assertions pass and the suite reports no
unexpected audit row created by an authenticated client.

### Step 3: Regenerate types and document the trust boundary

Run `pnpm supabase:types` after the migration is applied to the local database.
Inspect the generated diff; do not hand-edit generated sections. If the revoked
function remains present in generated types, that is acceptable because type
generation describes schema shape, not privileges. If it is absent or its
signature changes, keep the generated result and ensure no application caller
is added.

Update `supabase/README.md` to state that audit rows are created only by trusted
database operations, direct table inserts and generic authenticated RPC calls
are denied, and future mutations must record audit data in the same transaction.

**Verify**: `pnpm typecheck` → exit 0; `rg -n "record_audit_log|audit" supabase/README.md supabase/migrations/20260803070351_audit_integrity.sql` → documentation and migration agree; `git diff --check` → no output.

## Test plan

- Use the existing fixtures in `rls_and_check_in.sql`: user 1 is the owner of
  organization A, user 3 is `gate` in A, and event A is shared with a
  collaborator organization.
- Prove direct table insert remains denied.
- Prove the generic RPC is denied for both owner and gate after the new revoke.
- Prove no row is created by denied calls.
- Run the full existing suite; do not reduce its assertion coverage to make the
  new tests pass.

## Done criteria

- [ ] Authenticated clients cannot execute the generic audit RPC.
- [ ] Authenticated clients cannot insert directly into `audit_logs`.
- [ ] `search_path = ''` and schema qualification remain on the helper.
- [ ] pgTAP covers owner and gate denial plus unchanged audit count.
- [ ] `pnpm supabase:test`, `pnpm typecheck`, and `pnpm check` exit 0.
- [ ] No existing migration is edited and no remote push is performed.
- [ ] No files outside the in-scope list are modified; `plans/README.md` only has
      this plan's status update.
- [ ] `plans/README.md` status row is updated to `DONE`.

## STOP conditions

Stop and report if:

- a current application or migration caller depends on the public generic RPC;
- revoking `EXECUTE` would require granting a broad new client privilege;
- the local database shows that `record_audit_log` is needed by an existing
  trusted function but cannot be called by it after the revoke;
- the intended product behavior is that a browser client may create arbitrary
  audit actions; that requires a redesigned, action-specific API rather than
  weakening this plan;
- the test suite cannot distinguish permission denial from an unrelated migration
  failure.

## Maintenance notes

When a future event, check-in, refund, or ledger operation is implemented, review
that operation's transaction for an audit insert before exposing it to the app.
The audit row must derive actor and timestamp from the session/database, validate
the target entity inside the same transaction, and never accept a generic action
from an untrusted client. Reviewers should pay special attention to newly granted
function execution privileges.

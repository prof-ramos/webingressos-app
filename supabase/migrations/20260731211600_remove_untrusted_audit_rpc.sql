-- The audit trail is written by trusted lifecycle functions, not by a generic client RPC.

drop function if exists public.append_audit_log(
  bigint,
  bigint,
  text,
  text,
  text,
  text,
  jsonb
);

revoke all on function public.record_event_creation_status() from public;
revoke all on function public.prevent_event_organization_change() from public;
revoke all on function public.validate_ticket_issuance() from public;

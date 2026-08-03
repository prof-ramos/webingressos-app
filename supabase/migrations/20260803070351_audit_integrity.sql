-- Generic audit writes are trusted database operations, not a browser API.

revoke insert on table public.audit_logs from public, authenticated;

revoke execute on function public.record_audit_log(
  bigint,
  bigint,
  text,
  text,
  text,
  text,
  jsonb
) from public;

revoke execute on function public.record_audit_log(
  bigint,
  bigint,
  text,
  text,
  text,
  text,
  jsonb
) from authenticated;

import type { OrganizationId, UserId } from "@/modules/identity/domain"

export type AuditAction =
  | "accessed"
  | "created"
  | "updated"
  | "transitioned"
  | "checked_in"
  | "approved"
  | "closed"

export type AuditEntry = {
  organizationId: OrganizationId
  actorUserId: UserId | null
  entityType: string
  entityPublicId: string
  action: AuditAction
  reason: string | null
  occurredAt: string
}

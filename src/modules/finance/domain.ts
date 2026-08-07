import type { EventId } from "@/modules/events/domain"
import type { OrganizationId } from "@/modules/identity/domain"

export type LedgerEntryId = string & { readonly __brand: "LedgerEntryId" }
export type LedgerEntryStatus = "previsto" | "aprovado" | "pago"
export type LedgerEntryKind = "revenue" | "expense" | "commission" | "split" | "payout"

export type Money = {
  cents: bigint
  currency: "BRL"
}

export type LedgerEntry = {
  id: LedgerEntryId
  organizationId: OrganizationId
  eventId: EventId
  kind: LedgerEntryKind
  status: LedgerEntryStatus
  amount: Money
  description: string
}

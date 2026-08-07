import type { EventId } from "@/modules/events/domain"
import type { OrganizationId } from "@/modules/identity/domain"

export type PromoterId = string & { readonly __brand: "PromoterId" }

export type Promoter = {
  id: PromoterId
  organizationId: OrganizationId
  eventId: EventId
  displayName: string
  contact: string | null
  commissionRateBasisPoints: number
}

import type { EventId } from "@/modules/events/domain"

export type PromoterId = string & { readonly __brand: "PromoterId" }

export type Promoter = {
  id: PromoterId
  eventId: EventId
  displayName: string
  contact: string | null
  commissionRateBasisPoints: number
}

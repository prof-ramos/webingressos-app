import type { EventId } from "@/modules/events/domain"
import type { PromoterId } from "@/modules/promoters/domain"

export type OrderId = string & { readonly __brand: "OrderId" }
export type TicketId = string & { readonly __brand: "TicketId" }

export type OrderStatus = "pending" | "confirmed" | "cancelled" | "refunded"

export type Order = {
  id: OrderId
  publicId: string
  eventId: EventId
  promoterId: PromoterId | null
  status: OrderStatus
  totalCents: bigint
  currency: "BRL"
}

export type Ticket = {
  id: TicketId
  publicCode: string
  orderId: OrderId
  checkedInAt: string | null
}

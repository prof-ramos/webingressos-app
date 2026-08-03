import type { TicketId } from "@/modules/sales/domain"
import type { UserId } from "@/modules/identity/domain"

export type CheckInResult =
  | { status: "accepted"; ticketId: TicketId; checkedInAt: string }
  | { status: "already_checked_in"; ticketId: TicketId; checkedInAt: string }
  | {
      status: "invalid"
      reason: "not_found" | "wrong_event" | "not_authorized" | "not_confirmed" | "cancelled"
    }

export type CheckInActor = {
  userId: UserId
  deviceLabel: string | null
}

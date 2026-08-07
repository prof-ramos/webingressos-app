import type { OrganizationId } from "@/modules/identity/domain"

export type EventId = string & { readonly __brand: "EventId" }

export type EventStatus =
  | "rascunho"
  | "planejado"
  | "vendas_abertas"
  | "encerrado"
  | "prestacao_contas_fechada"
  | "cancelado"

export type Event = {
  id: EventId
  organizationId: OrganizationId
  name: string
  status: EventStatus
  startsAt: string
  endsAt: string
}

export type EventOrganizationRole = "owner" | "collaborator"

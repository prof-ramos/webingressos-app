export type OrganizationId = string & { readonly __brand: "OrganizationId" }
export type UserId = string & { readonly __brand: "UserId" }

export type OrganizationRole = "owner" | "finance" | "ops" | "gate"

export type Organization = {
  id: OrganizationId
  name: string
}

export type OrganizationMembership = {
  organizationId: OrganizationId
  userId: UserId
  role: OrganizationRole
}

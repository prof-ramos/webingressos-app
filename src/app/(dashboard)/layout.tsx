import { AppShell, type AccountSummary } from "@/components/layout/app-shell"
import { createClient } from "@/lib/supabase/server"

const anonymousAccount: AccountSummary = {
  displayName: "Conta autenticada",
  initials: "CA",
  roleLabel: "Conta autenticada",
}

function getInitials(displayName: string) {
  const initials = displayName
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0])
    .join("")
    .toUpperCase()

  return initials || anonymousAccount.initials
}

async function getAccountSummary(): Promise<AccountSummary> {
  try {
    const supabase = await createClient()
    const { data } = await supabase.auth.getClaims()
    const claims = data?.claims
    const metadata = claims?.user_metadata
    const metadataName =
      metadata && typeof metadata === "object"
        ? [metadata.full_name, metadata.name].find(
            (value): value is string => typeof value === "string" && Boolean(value.trim()),
          )
        : undefined
    const displayName = metadataName?.trim() || claims?.email || anonymousAccount.displayName

    return {
      displayName,
      initials: getInitials(displayName),
      roleLabel: "Conta autenticada",
    }
  } catch {
    return anonymousAccount
  }
}

export default async function DashboardLayout({ children }: { children: React.ReactNode }) {
  const account = await getAccountSummary()

  return <AppShell account={account}>{children}</AppShell>
}

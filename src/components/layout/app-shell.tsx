import type { ReactNode } from "react"

import { AccountMenu } from "@/components/layout/account-menu"
import { BrandMark } from "@/components/layout/brand-mark"
import { MobileNavigation } from "@/components/layout/mobile-navigation"
import { NavigationLinks } from "@/components/layout/navigation-links"
import { WorkspaceSelector } from "@/components/layout/workspace-selector"
import { Separator } from "@/components/ui/separator"

export type AccountSummary = {
  displayName: string
  initials: string
  roleLabel: string
}

export function AppShell({
  children,
  account,
}: {
  children: ReactNode
  account: AccountSummary
}) {
  return (
    <div className="min-h-screen bg-background">
      <a
        href="#conteudo"
        className="sr-only focus:not-sr-only focus:fixed focus:left-3 focus:top-3 focus:z-50 focus:rounded-lg focus:bg-card focus:px-4 focus:py-3 focus:text-sm focus:font-bold focus:text-ink-900 focus:shadow-panel focus:outline-2 focus:outline-offset-2 focus:outline-ring"
      >
        Ir para o conteúdo
      </a>

      <aside className="fixed inset-y-0 left-0 z-30 hidden w-64 flex-col border-r border-border bg-card lg:flex">
        <div className="flex h-20 items-center px-6">
          <BrandMark />
        </div>
        <div className="px-4">
          <WorkspaceSelector />
        </div>
        <Separator className="my-5" />
        <div className="flex-1 px-4">
          <NavigationLinks />
        </div>
        <div className="p-4">
          <NavigationLinks section="utility" />
        </div>
      </aside>

      <div className="lg:pl-64">
        <header className="sticky top-0 z-20 flex h-16 items-center justify-between gap-3 border-b border-border bg-background/95 px-4 backdrop-blur-sm sm:px-6 lg:px-8">
          <div className="flex min-w-0 items-center gap-3 lg:hidden">
            <MobileNavigation />
            <BrandMark compact />
            <span className="min-w-0 truncate text-sm font-bold text-ink-900">
              Organização ativa
            </span>
          </div>

          <div className="hidden items-center gap-2 text-sm text-ink-500 lg:flex">
            <span>Operação</span>
            <span className="text-ink-300" aria-hidden="true">
              /
            </span>
            <span className="font-semibold text-ink-800">Organização ativa</span>
          </div>

          <AccountMenu {...account} />
        </header>

        <main id="conteudo" className="min-h-[calc(100vh-4rem)] px-4 py-6 sm:px-6 lg:px-8 lg:py-8">
          <div className="mx-auto max-w-[1440px]">{children}</div>
        </main>
      </div>
    </div>
  )
}

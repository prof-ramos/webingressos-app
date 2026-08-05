import { ChevronDown } from "lucide-react"
import type { ReactNode } from "react"

import { AccountMenu } from "@/components/layout/account-menu"
import { BrandMark } from "@/components/layout/brand-mark"
import { MobileNavigation } from "@/components/layout/mobile-navigation"
import { NavigationLinks } from "@/components/layout/navigation-links"
import { WorkspaceSelector } from "@/components/layout/workspace-selector"
import { Separator } from "@/components/ui/separator"

export function AppShell({ children }: { children: ReactNode }) {
  return (
    <div className="min-h-screen bg-background">
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
        <header className="sticky top-0 z-20 flex h-16 items-center justify-between border-b border-border bg-background/95 px-4 backdrop-blur-sm sm:px-6 lg:px-8">
          <div className="flex items-center gap-3 lg:hidden">
            <MobileNavigation />
            <BrandMark compact />
          </div>

          <div className="hidden items-center gap-2 text-sm text-ink-500 lg:flex">
            <span>Operação</span>
            <ChevronDown className="size-4" aria-hidden="true" />
            <span className="font-semibold text-ink-800">Campus Ledger</span>
          </div>

          <AccountMenu />
        </header>

        <main className="min-h-[calc(100vh-4rem)] px-4 py-6 sm:px-6 lg:px-8 lg:py-8">
          <div className="mx-auto max-w-[1440px]">{children}</div>
        </main>
      </div>
    </div>
  )
}

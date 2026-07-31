"use client"

import Link from "next/link"
import { usePathname, useRouter } from "next/navigation"
import { useState } from "react"
import {
  BarChart3,
  CalendarDays,
  ChevronDown,
  ClipboardCheck,
  LayoutDashboard,
  Menu,
  Settings2,
  Ticket,
  UsersRound,
} from "lucide-react"

import { BrandMark } from "@/components/layout/brand-mark"
import { Avatar, AvatarFallback } from "@/components/ui/avatar"
import { Button } from "@/components/ui/button"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Separator } from "@/components/ui/separator"
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle,
  SheetTrigger,
} from "@/components/ui/sheet"
import { createClient } from "@/lib/supabase/client"
import { cn } from "@/lib/utils"

const navigation = [
  { href: "/dashboard", label: "Visão geral", icon: LayoutDashboard },
  { href: "/eventos", label: "Eventos", icon: CalendarDays },
  { href: "/ingressos", label: "Ingressos", icon: Ticket },
  { href: "/check-in", label: "Check-in", icon: ClipboardCheck },
  { href: "/promoters", label: "Promoters", icon: UsersRound },
  { href: "/relatorios", label: "Relatórios", icon: BarChart3 },
]

function NavigationLinks({ onNavigate }: { onNavigate?: () => void }) {
  const pathname = usePathname()

  return (
    <nav className="space-y-1" aria-label="Navegação principal">
      {navigation.map((item) => {
        const Icon = item.icon
        const active = pathname === item.href || pathname.startsWith(`${item.href}/`)

        return (
          <Link
            key={item.href}
            href={item.href}
            onClick={onNavigate}
            className={cn(
              "flex h-11 items-center gap-3 rounded-lg px-3 text-sm font-semibold transition-colors",
              active
                ? "bg-brand-100 text-brand-800"
                : "text-ink-600 hover:bg-ink-100 hover:text-ink-900"
            )}
          >
            <Icon className="size-[18px]" aria-hidden="true" />
            {item.label}
          </Link>
        )
      })}
    </nav>
  )
}

function WorkspaceSelector() {
  return (
    <Select defaultValue="campus-ledger">
      <SelectTrigger className="h-10 w-full border-transparent bg-ink-50 text-ink-800 shadow-none hover:bg-brand-50">
        <SelectValue />
      </SelectTrigger>
      <SelectContent>
        <SelectItem value="campus-ledger">Campus Ledger</SelectItem>
        <SelectItem value="nova-organizacao">Nova organização</SelectItem>
      </SelectContent>
    </Select>
  )
}

export function AppShell({ children }: { children: React.ReactNode }) {
  const router = useRouter()
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false)

  async function handleSignOut() {
    const supabase = createClient()
    await supabase.auth.signOut()
    router.replace("/login")
    router.refresh()
  }

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
          <Link
            href="/configuracoes"
            className="flex h-11 items-center gap-3 rounded-lg px-3 text-sm font-semibold text-ink-600 transition-colors hover:bg-ink-100 hover:text-ink-900"
          >
            <Settings2 className="size-[18px]" aria-hidden="true" />
            Configurações
          </Link>
        </div>
      </aside>

      <div className="lg:pl-64">
        <header className="sticky top-0 z-20 flex h-16 items-center justify-between border-b border-border bg-background/95 px-4 backdrop-blur-sm sm:px-6 lg:px-8">
          <div className="flex items-center gap-3 lg:hidden">
            <Sheet open={mobileMenuOpen} onOpenChange={setMobileMenuOpen}>
              <SheetTrigger render={<Button variant="outline" size="icon" aria-label="Abrir menu" />}>
                <Menu aria-hidden="true" />
              </SheetTrigger>
              <SheetContent side="left" className="w-[min(20rem,85vw)] bg-card">
                <SheetHeader className="border-b border-border pb-5">
                  <BrandMark />
                  <SheetTitle className="sr-only">Menu principal</SheetTitle>
                  <SheetDescription className="sr-only">
                    Navegue pelas áreas da operação.
                  </SheetDescription>
                </SheetHeader>
                <div className="px-4">
                  <WorkspaceSelector />
                </div>
                <NavigationLinks onNavigate={() => setMobileMenuOpen(false)} />
              </SheetContent>
            </Sheet>
            <BrandMark compact />
          </div>

          <div className="hidden items-center gap-2 text-sm text-ink-500 lg:flex">
            <span>Operação</span>
            <ChevronDown className="size-4" aria-hidden="true" />
            <span className="font-semibold text-ink-800">Campus Ledger</span>
          </div>

          <DropdownMenu>
            <DropdownMenuTrigger
              render={
                <Button variant="ghost" className="h-10 gap-2 px-2 hover:bg-ink-100" aria-label="Abrir menu da conta" />
              }
            >
              <Avatar className="size-8">
                <AvatarFallback className="bg-brand-100 text-xs font-bold text-brand-800">GR</AvatarFallback>
              </Avatar>
              <span className="hidden text-left sm:block">
                <span className="block text-xs font-bold text-ink-900">Gabriel Ramos</span>
                <span className="block text-[11px] text-ink-500">Administrador</span>
              </span>
              <ChevronDown className="size-4 text-ink-500" aria-hidden="true" />
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end" className="w-52">
              <DropdownMenuLabel>Minha conta</DropdownMenuLabel>
              <DropdownMenuSeparator />
              <DropdownMenuItem>Perfil</DropdownMenuItem>
              <DropdownMenuItem>Preferências</DropdownMenuItem>
              <DropdownMenuItem onClick={handleSignOut}>Encerrar sessão</DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        </header>

        <main className="min-h-[calc(100vh-4rem)] px-4 py-6 sm:px-6 lg:px-8 lg:py-8">
          <div className="mx-auto max-w-[1440px]">{children}</div>
        </main>
      </div>
    </div>
  )
}

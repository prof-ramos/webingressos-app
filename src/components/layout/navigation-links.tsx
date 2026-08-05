"use client"

import Link from "next/link"
import { usePathname } from "next/navigation"
import {
  BarChart3,
  CalendarDays,
  ClipboardCheck,
  LayoutDashboard,
  Settings2,
  Ticket,
  UsersRound,
} from "lucide-react"

import { cn } from "@/lib/utils"

const navigation = [
  { href: "/dashboard", label: "Visão geral", icon: LayoutDashboard, section: "primary" },
  { href: "/eventos", label: "Eventos", icon: CalendarDays, section: "primary" },
  { href: "/ingressos", label: "Ingressos", icon: Ticket, section: "primary" },
  { href: "/check-in", label: "Check-in", icon: ClipboardCheck, section: "primary" },
  { href: "/promoters", label: "Promoters", icon: UsersRound, section: "primary" },
  { href: "/relatorios", label: "Relatórios", icon: BarChart3, section: "primary" },
  { href: "/configuracoes", label: "Configurações", icon: Settings2, section: "utility" },
]

type NavigationSection = "primary" | "utility" | "all"

export function NavigationLinks({
  onNavigate,
  section = "primary",
}: {
  onNavigate?: () => void
  section?: NavigationSection
}) {
  const pathname = usePathname()
  const items = navigation.filter((item) => section === "all" || item.section === section)
  const navigationLabel =
    section === "utility" ? "Navegação utilitária" : "Navegação principal"

  return (
    <nav className="space-y-1" aria-label={navigationLabel}>
      {items.map((item) => {
        const Icon = item.icon
        const active = pathname === item.href || pathname.startsWith(`${item.href}/`)

        return (
          <Link
            key={item.href}
            href={item.href}
            onClick={onNavigate}
            className={cn(
              "flex h-11 items-center gap-3 rounded-lg px-3 text-sm font-semibold transition-colors",
              section === "all" && item.section === "utility" && "mt-4 border-t border-border pt-4",
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

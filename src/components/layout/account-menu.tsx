"use client"

import { useState } from "react"
import { useRouter } from "next/navigation"
import { ChevronDown } from "lucide-react"

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
import { createClient } from "@/lib/supabase/client"

export function AccountMenu() {
  const router = useRouter()
  const [isSigningOut, setIsSigningOut] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function handleSignOut() {
    if (isSigningOut) return

    setError(null)
    setIsSigningOut(true)

    try {
      const { error: signOutError } = await createClient().auth.signOut()

      if (signOutError) {
        setError("Não foi possível encerrar a sessão. Tente novamente.")
        return
      }

      router.replace("/login")
      router.refresh()
    } catch {
      setError("Não foi possível encerrar a sessão. Tente novamente.")
    } finally {
      setIsSigningOut(false)
    }
  }

  return (
    <div className="relative">
      <DropdownMenu>
        <DropdownMenuTrigger
          render={
            <Button
              variant="ghost"
              className="h-10 gap-2 px-2 hover:bg-ink-100"
              aria-label="Abrir menu da conta"
            />
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
          <DropdownMenuItem disabled={isSigningOut} onClick={handleSignOut}>
            {isSigningOut ? "Encerrando sessão…" : "Encerrar sessão"}
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>
      {error ? (
        <p
          className="absolute top-[calc(100%+0.5rem)] right-0 z-50 w-72 rounded-md border border-destructive/30 bg-card px-3 py-2 text-xs text-destructive shadow-md"
          role="alert"
        >
          {error}
        </p>
      ) : null}
    </div>
  )
}

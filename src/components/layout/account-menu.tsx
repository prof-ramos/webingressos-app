"use client"

import { ChevronDown } from "lucide-react"

import { Avatar, AvatarFallback } from "@/components/ui/avatar"
import { Button } from "@/components/ui/button"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuGroup,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"

export function AccountMenu({
  displayName,
  initials,
  roleLabel,
}: {
  displayName: string
  initials: string
  roleLabel: string
}) {
  return (
    <DropdownMenu>
      <DropdownMenuTrigger
        render={
          <Button
            variant="ghost"
            className="gap-2 px-2 hover:bg-ink-100"
            aria-label="Abrir menu da conta"
          />
        }
      >
        <Avatar className="size-8">
          <AvatarFallback className="bg-brand-100 text-xs font-bold text-brand-800">
            {initials}
          </AvatarFallback>
        </Avatar>
        <span className="hidden text-left sm:block">
          <span className="block text-xs font-bold text-ink-900">{displayName}</span>
          <span className="block text-[11px] text-ink-500">{roleLabel}</span>
        </span>
        <ChevronDown className="size-4 text-ink-500" aria-hidden="true" />
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end" className="w-52">
        <DropdownMenuGroup>
          <DropdownMenuLabel className="truncate">{displayName}</DropdownMenuLabel>
          <DropdownMenuItem disabled>Perfil (em breve)</DropdownMenuItem>
          <DropdownMenuItem disabled>Preferências (em breve)</DropdownMenuItem>
        </DropdownMenuGroup>
        <DropdownMenuSeparator />
        <form action="/auth/sign-out" method="post">
          <DropdownMenuItem
            nativeButton
            render={<button type="submit" className="w-full text-left" />}
          >
            Encerrar sessão
          </DropdownMenuItem>
        </form>
      </DropdownMenuContent>
    </DropdownMenu>
  )
}

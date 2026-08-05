"use client"

import { useState } from "react"
import { Menu } from "lucide-react"

import { BrandMark } from "@/components/layout/brand-mark"
import { NavigationLinks } from "@/components/layout/navigation-links"
import { WorkspaceSelector } from "@/components/layout/workspace-selector"
import { Button } from "@/components/ui/button"
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle,
  SheetTrigger,
} from "@/components/ui/sheet"

export function MobileNavigation() {
  const [open, setOpen] = useState(false)

  return (
    <Sheet open={open} onOpenChange={setOpen}>
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
        <NavigationLinks section="all" onNavigate={() => setOpen(false)} />
      </SheetContent>
    </Sheet>
  )
}

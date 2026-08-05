"use client"

import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"

export function WorkspaceSelector() {
  return (
    <Select defaultValue="campus-ledger">
      <SelectTrigger
        aria-label="Organização"
        className="h-10 w-full border-transparent bg-ink-50 text-ink-800 shadow-none hover:bg-brand-50"
      >
        <SelectValue />
      </SelectTrigger>
      <SelectContent>
        <SelectItem value="campus-ledger">Campus Ledger</SelectItem>
        <SelectItem value="nova-organizacao">Nova organização</SelectItem>
      </SelectContent>
    </Select>
  )
}

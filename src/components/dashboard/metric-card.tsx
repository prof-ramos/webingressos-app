import type { LucideIcon } from "lucide-react"

import { Card, CardContent } from "@/components/ui/card"

export function MetricCard({
  label,
  icon: Icon,
  detail,
}: {
  label: string
  icon: LucideIcon
  detail: string
}) {
  return (
    <Card className="rounded-[1.25rem] border-border shadow-[0_2px_12px_rgba(27,39,64,0.03)]">
      <CardContent className="flex min-h-36 flex-col justify-between p-5 sm:p-6">
        <div className="flex items-start justify-between gap-4">
          <span className="text-sm font-semibold text-ink-600">{label}</span>
          <span className="flex size-9 items-center justify-center rounded-lg bg-brand-100 text-brand-700">
            <Icon className="size-[18px]" aria-hidden="true" />
          </span>
        </div>
        <div>
          <p className="mt-4 text-3xl font-extrabold tracking-[-0.04em] text-ink-900">—</p>
          <p className="mt-1 text-xs text-ink-500">{detail}</p>
        </div>
      </CardContent>
    </Card>
  )
}

import type { LucideIcon } from "lucide-react"

import { Card, CardContent } from "@/components/ui/card"
import { Skeleton } from "@/components/ui/skeleton"

export function MetricCard({
  label,
  icon: Icon,
  detail,
  value,
  isLoading = false,
}: {
  label: string
  icon: LucideIcon
  detail: string
  /** Absent means the metric has no data source connected yet. */
  value?: string
  isLoading?: boolean
}) {
  return (
    <Card className="rounded-card shadow-card">
      <CardContent className="flex min-h-32 flex-col justify-between gap-4 p-5 sm:p-6">
        <div className="flex items-start justify-between gap-3">
          <span className="text-sm font-semibold text-ink-600">{label}</span>
          {/* DESIGN.md icon chip: a perfect circle in the palest green. */}
          <span className="flex size-9 shrink-0 items-center justify-center rounded-full bg-brand-100 text-brand-800">
            <Icon className="size-[18px]" aria-hidden="true" />
          </span>
        </div>
        <div>
          {isLoading ? (
            <Skeleton className="h-9 w-20 rounded-lg" />
          ) : (
            <p className="text-3xl font-extrabold tracking-[-0.04em] text-ink-900">
              {value ?? (
                <>
                  <span aria-hidden="true">—</span>
                  <span className="sr-only">sem dados</span>
                </>
              )}
            </p>
          )}
          <p className="mt-1 text-xs text-ink-500">{detail}</p>
        </div>
      </CardContent>
    </Card>
  )
}

import { Skeleton } from "@/components/ui/skeleton"

export default function DashboardLoading() {
  return (
    <div className="space-y-8" role="status" aria-live="polite">
      <span className="sr-only">Carregando conteúdo…</span>
      <div className="space-y-3">
        <Skeleton className="h-4 w-32 rounded-md" />
        <Skeleton className="h-10 w-64 rounded-lg" />
        <Skeleton className="h-4 w-full max-w-md rounded-md" />
      </div>
      <div className="grid grid-cols-2 gap-4 xl:grid-cols-4">
        {[0, 1, 2, 3].map((index) => (
          <Skeleton key={index} className="h-32 rounded-card" />
        ))}
      </div>
      <div className="grid items-start gap-5 xl:grid-cols-[minmax(0,1.5fr)_minmax(18rem,0.75fr)]">
        <Skeleton className="h-80 rounded-card" />
        <Skeleton className="h-56 rounded-card" />
      </div>
    </div>
  )
}

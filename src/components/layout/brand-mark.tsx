import Link from "next/link"

export function BrandMark({ compact = false }: { compact?: boolean }) {
  return (
    <Link href="/dashboard" className="flex items-center gap-3" aria-label="WebIngressos, ir para visão geral">
      <span className="flex size-9 items-center justify-center rounded-xl bg-brand-700 text-sm font-extrabold text-primary-foreground shadow-sm">
        W
      </span>
      {!compact && (
        <span className="text-base font-extrabold tracking-[-0.04em] text-ink-900">
          WebIngressos
        </span>
      )}
    </Link>
  )
}

import { Suspense } from "react"

import { LoginForm } from "@/components/auth/login-form"
import { BrandMark } from "@/components/layout/brand-mark"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Skeleton } from "@/components/ui/skeleton"
import { getAuthErrorMessage, getSafeNextPath } from "@/lib/safe-navigation"

export const metadata = {
  title: "Entrar",
}

function LoginFormFallback() {
  return (
    <div className="space-y-5" role="status" aria-live="polite">
      <span className="sr-only">Carregando formulário de acesso…</span>
      <Skeleton className="h-12 w-full rounded-lg" />
      <Skeleton className="h-12 w-full rounded-lg" />
      <Skeleton className="h-12 w-full rounded-lg" />
    </div>
  )
}

export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string | string[]; next?: string | string[] }>
}) {
  const { error, next } = await searchParams
  const safeNext = getSafeNextPath(typeof next === "string" ? next : null, "http://localhost")

  return (
    <main className="flex min-h-screen items-center justify-center bg-background px-4 py-10">
      <Card className="w-full max-w-md rounded-card shadow-panel">
        <CardHeader className="space-y-5 p-6 pb-2 sm:p-8 sm:pb-3">
          <BrandMark />
          <div>
            <CardTitle as="h1" className="text-2xl font-extrabold tracking-[-0.04em] text-ink-900">
              Entrar na operação
            </CardTitle>
            <p className="mt-2 text-sm leading-6 text-ink-600">
              Acesse o espaço da sua organização para começar.
            </p>
          </div>
        </CardHeader>
        <CardContent className="p-6 pt-5 sm:p-8 sm:pt-5">
          <Suspense fallback={<LoginFormFallback />}>
            <LoginForm initialError={getAuthErrorMessage(error)} next={safeNext} />
          </Suspense>
        </CardContent>
      </Card>
    </main>
  )
}

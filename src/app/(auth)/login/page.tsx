import { Ticket } from "lucide-react"

import { LoginForm } from "@/components/auth/login-form"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { getAuthErrorMessage } from "@/lib/safe-navigation"

export const metadata = {
  title: "Entrar",
}

export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string | string[] }>
}) {
  const { error } = await searchParams

  return (
    <main className="flex min-h-screen items-center justify-center bg-background px-4 py-10">
      <Card className="w-full max-w-md rounded-[1.25rem] border-border shadow-[0_12px_36px_rgba(27,39,64,0.08)]">
        <CardHeader className="space-y-5 p-6 pb-2 sm:p-8 sm:pb-3">
          <div className="flex size-12 items-center justify-center rounded-xl bg-brand-700 text-primary-foreground">
            <Ticket className="size-6" aria-hidden="true" />
          </div>
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
          <LoginForm initialError={getAuthErrorMessage(error)} />
        </CardContent>
      </Card>
    </main>
  )
}

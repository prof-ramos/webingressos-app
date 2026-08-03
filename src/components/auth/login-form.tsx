"use client"

import { useState, type FormEvent } from "react"
import { useRouter, useSearchParams } from "next/navigation"

import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { createClient } from "@/lib/supabase/client"
import { getSafeNextPath } from "@/lib/safe-navigation"

export function LoginForm({
  initialError = null,
  next = "/dashboard",
}: {
  initialError?: string | null
  next?: string
}) {
  const router = useRouter()
  const searchParams = useSearchParams()
  const [email, setEmail] = useState("")
  const [password, setPassword] = useState("")
  const [error, setError] = useState<string | null>(initialError)
  const [isPending, setIsPending] = useState(false)

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setError(null)
    setIsPending(true)

    try {
      const supabase = createClient()
      const { error: signInError } = await supabase.auth.signInWithPassword({ email, password })

      if (signInError) {
        setError(
          signInError.code === "invalid_credentials"
            ? "E-mail ou senha incorretos."
            : "Não foi possível entrar agora. Tente novamente em alguns instantes.",
        )
        return
      }

      router.replace(getSafeNextPath(next, window.location.origin))
      router.refresh()
    } catch {
      setError("A autenticação ainda não está configurada neste ambiente.")
    } finally {
      setIsPending(false)
    }
  }

  const errorId = "login-erro"
  const signOutFailed = searchParams.get("erro") === "logout"

  return (
    <form className="space-y-5" onSubmit={handleSubmit}>
      {signOutFailed && (
        <p role="alert" className="rounded-lg bg-destructive/10 px-3 py-2 text-sm text-destructive">
          Não foi possível encerrar a sessão anterior por completo. Entre novamente para confirmar
          quem está operando.
        </p>
      )}
      <div className="space-y-2">
        <Label htmlFor="email">E-mail</Label>
        <Input
          id="email"
          name="email"
          type="email"
          autoComplete="email"
          inputMode="email"
          required
          value={email}
          onChange={(event) => setEmail(event.target.value)}
          aria-invalid={error ? true : undefined}
          aria-describedby={error ? errorId : undefined}
          className="h-12"
        />
      </div>
      <div className="space-y-2">
        <Label htmlFor="password">Senha</Label>
        <Input
          id="password"
          name="password"
          type="password"
          autoComplete="current-password"
          required
          value={password}
          onChange={(event) => setPassword(event.target.value)}
          aria-invalid={error ? true : undefined}
          aria-describedby={error ? errorId : undefined}
          className="h-12"
        />
      </div>
      {error && (
        <p
          id={errorId}
          role="alert"
          className="rounded-lg bg-destructive/10 px-3 py-2 text-sm text-destructive"
        >
          {error}
        </p>
      )}
      <Button
        type="submit"
        disabled={isPending}
        aria-busy={isPending}
        className="h-12 w-full rounded-lg font-bold"
      >
        {isPending ? "Entrando…" : "Entrar"}
      </Button>
    </form>
  )
}

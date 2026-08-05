"use client"

import { useState, type FormEvent } from "react"
import { useRouter } from "next/navigation"

import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { getSafeNextPath } from "@/lib/safe-navigation"
import { createClient } from "@/lib/supabase/client"

export function LoginForm({ initialError = null }: { initialError?: string | null }) {
  const router = useRouter()
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
        setError("Não foi possível entrar. Confira seus dados e tente novamente.")
        return
      }

      const next = new URLSearchParams(window.location.search).get("next")
      router.push(getSafeNextPath(next, window.location.origin))
      router.refresh()
    } catch {
      setError("A autenticação ainda não está configurada neste ambiente.")
    } finally {
      setIsPending(false)
    }
  }

  return (
    <form className="space-y-5" onSubmit={handleSubmit}>
      <div className="space-y-2">
        <Label htmlFor="email">E-mail</Label>
        <Input
          id="email"
          name="email"
          type="email"
          autoComplete="email"
          required
          value={email}
          onChange={(event) => setEmail(event.target.value)}
          className="h-12"
        />
      </div>
      <div className="space-y-2">
        <div className="flex items-center justify-between gap-3">
          <Label htmlFor="password">Senha</Label>
          <span className="text-xs text-ink-600">Recuperação será conectada</span>
        </div>
        <Input
          id="password"
          name="password"
          type="password"
          autoComplete="current-password"
          required
          value={password}
          onChange={(event) => setPassword(event.target.value)}
          className="h-12"
        />
      </div>
      {error && (
        <p role="alert" className="rounded-lg bg-destructive/10 px-3 py-2 text-sm text-destructive">
          {error}
        </p>
      )}
      <Button type="submit" disabled={isPending} className="h-12 w-full rounded-lg">
        {isPending ? "Entrando…" : "Entrar"}
      </Button>
    </form>
  )
}

"use client"

import { AlertTriangle } from "lucide-react"

import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"

export default function DashboardError({ reset }: { error: Error; reset: () => void }) {
  return (
    <Card className="mx-auto max-w-xl rounded-card shadow-card">
      <CardHeader className="p-6 pb-2">
        <span className="flex size-10 items-center justify-center rounded-full bg-destructive/10 text-destructive">
          <AlertTriangle className="size-5" aria-hidden="true" />
        </span>
        <CardTitle as="h1" className="mt-4 text-xl font-extrabold tracking-[-0.03em] text-ink-900">
          Não foi possível carregar esta área
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-5 p-6 pt-2">
        <p role="alert" className="text-sm leading-6 text-ink-600">
          A operação continua registrada. Tente novamente e, se o erro persistir, avise a equipe
          responsável pelo ambiente.
        </p>
        <Button onClick={reset}>Tentar novamente</Button>
      </CardContent>
    </Card>
  )
}

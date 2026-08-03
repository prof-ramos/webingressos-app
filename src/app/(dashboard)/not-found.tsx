import Link from "next/link"
import { Compass } from "lucide-react"

import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"

export const metadata = {
  title: "Página não encontrada",
}

export default function DashboardNotFound() {
  return (
    <Card className="mx-auto max-w-xl rounded-card shadow-card">
      <CardHeader className="p-6 pb-2">
        <span className="flex size-10 items-center justify-center rounded-full bg-brand-100 text-brand-800">
          <Compass className="size-5" aria-hidden="true" />
        </span>
        <CardTitle as="h1" className="mt-4 text-xl font-extrabold tracking-[-0.03em] text-ink-900">
          Esta área não existe
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-5 p-6 pt-2">
        <p className="text-sm leading-6 text-ink-600">
          O endereço pedido não corresponde a nenhum módulo da operação. Use a navegação lateral para
          voltar a um módulo conhecido.
        </p>
        <Button render={<Link href="/dashboard" />}>Voltar para a visão geral</Button>
      </CardContent>
    </Card>
  )
}

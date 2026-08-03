import Link from "next/link"

import { BrandMark } from "@/components/layout/brand-mark"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"

export const metadata = {
  title: "Página não encontrada",
}

export default function NotFound() {
  return (
    <main className="flex min-h-screen items-center justify-center bg-background px-4 py-10">
      <Card className="w-full max-w-md rounded-card shadow-panel">
        <CardHeader className="space-y-5 p-6 pb-2 sm:p-8 sm:pb-3">
          <BrandMark />
          <CardTitle as="h1" className="text-2xl font-extrabold tracking-[-0.04em] text-ink-900">
            Página não encontrada
          </CardTitle>
        </CardHeader>
        <CardContent className="space-y-5 p-6 pt-3 sm:p-8 sm:pt-3">
          <p className="text-sm leading-6 text-ink-600">
            O endereço que você abriu não existe neste app. Verifique o link ou volte para a visão
            geral da operação.
          </p>
          <Button render={<Link href="/dashboard" />} className="h-11 rounded-lg px-5 font-bold">
            Ir para a visão geral
          </Button>
        </CardContent>
      </Card>
    </main>
  )
}

import { notFound } from "next/navigation"

import { Badge } from "@/components/ui/badge"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"

const modules = {
  eventos: {
    title: "Eventos",
    description: "Crie o espaço operacional de cada evento e acompanhe seu ciclo de vida.",
  },
  ingressos: {
    title: "Ingressos",
    description: "Consulte lotes, pedidos e credenciais individuais quando a camada comercial estiver conectada.",
  },
  "check-in": {
    title: "Check-in",
    description: "A futura portaria validará ingressos online e terá fallback para digitação manual.",
  },
  promoters: {
    title: "Promoters",
    description: "Acompanhe atribuição de vendas e comissões sem exigir login de promoter nesta primeira fase.",
  },
  relatorios: {
    title: "Relatórios",
    description: "A prestação de contas reunirá receitas, despesas, comissões e repasses auditáveis.",
  },
  configuracoes: {
    title: "Configurações",
    description: "As configurações de organização, acesso e integrações serão adicionadas por módulo.",
  },
} as const

export function generateStaticParams() {
  return Object.keys(modules).map((module) => ({ module }))
}

export default async function ModulePage({ params }: { params: Promise<{ module: string }> }) {
  const { module } = await params
  const content = modules[module as keyof typeof modules]

  if (!content) {
    notFound()
  }

  return (
    <div className="mx-auto max-w-3xl space-y-6">
      <div className="space-y-3">
        <Badge variant="secondary" className="rounded-md bg-brand-100 text-brand-800">
          Em construção
        </Badge>
        <h1 className="text-3xl font-extrabold tracking-[-0.05em] text-ink-900 sm:text-4xl">
          {content.title}
        </h1>
        <p className="text-base leading-7 text-ink-600">{content.description}</p>
      </div>
      <Card className="rounded-[1.25rem] border-border shadow-[0_2px_12px_rgba(27,39,64,0.03)]">
        <CardHeader className="p-6 pb-2">
          <CardTitle className="text-lg font-extrabold text-ink-900">Próximo passo</CardTitle>
        </CardHeader>
        <CardContent className="p-6 pt-3 text-sm leading-6 text-ink-600">
          Esta rota já faz parte do shell operacional. O comportamento real será conectado ao domínio e ao Supabase após a definição das migrations e políticas RLS.
        </CardContent>
      </Card>
    </div>
  )
}

import type { Metadata } from "next"
import Link from "next/link"
import { notFound } from "next/navigation"

import { Badge } from "@/components/ui/badge"
import {
  Breadcrumb,
  BreadcrumbItem,
  BreadcrumbLink,
  BreadcrumbList,
  BreadcrumbPage,
  BreadcrumbSeparator,
} from "@/components/ui/breadcrumb"
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

type ModuleKey = keyof typeof modules

export function generateStaticParams() {
  return Object.keys(modules).map((module) => ({ module }))
}

export async function generateMetadata({
  params,
}: {
  params: Promise<{ module: string }>
}): Promise<Metadata> {
  const { module } = await params
  const content = modules[module as ModuleKey]

  if (!content) {
    return { title: "Página não encontrada" }
  }

  return { title: content.title, description: content.description }
}

export default async function ModulePage({ params }: { params: Promise<{ module: string }> }) {
  const { module } = await params
  const content = modules[module as ModuleKey]

  if (!content) {
    notFound()
  }

  return (
    <div className="space-y-6">
      <div className="space-y-3">
        <Breadcrumb>
          <BreadcrumbList>
            <BreadcrumbItem>
              <BreadcrumbLink render={<Link href="/dashboard" />}>Visão geral</BreadcrumbLink>
            </BreadcrumbItem>
            <BreadcrumbSeparator />
            <BreadcrumbItem>
              <BreadcrumbPage>{content.title}</BreadcrumbPage>
            </BreadcrumbItem>
          </BreadcrumbList>
        </Breadcrumb>
        <div className="flex flex-wrap items-center gap-3">
          <h1 className="text-3xl font-extrabold tracking-[-0.05em] text-ink-900 sm:text-4xl">
            {content.title}
          </h1>
          <Badge variant="secondary" className="rounded-md bg-brand-100 text-brand-800">
            Em construção
          </Badge>
        </div>
        <p className="max-w-2xl text-sm leading-6 text-ink-600 sm:text-base">{content.description}</p>
      </div>

      <Card className="max-w-3xl rounded-card shadow-card">
        <CardHeader className="p-6 pb-2">
          <CardTitle as="h2" className="text-lg font-extrabold text-ink-900">
            Próximo passo
          </CardTitle>
        </CardHeader>
        <CardContent className="p-6 pt-3 text-sm leading-6 text-ink-600">
          Esta rota já faz parte do shell operacional. O comportamento real será conectado ao domínio
          e ao Supabase depois que as migrations e políticas RLS estiverem aplicadas.
        </CardContent>
      </Card>
    </div>
  )
}

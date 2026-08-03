import {
  ArrowUpRight,
  BarChart3,
  CalendarDays,
  ClipboardCheck,
  Plus,
  Ticket,
} from "lucide-react"

import { MetricCard } from "@/components/dashboard/metric-card"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import {
  Breadcrumb,
  BreadcrumbItem,
  BreadcrumbList,
  BreadcrumbPage,
} from "@/components/ui/breadcrumb"

export default function DashboardPage() {
  return (
    <div className="space-y-8">
      <div className="flex flex-col gap-5 sm:flex-row sm:items-end sm:justify-between">
        <div className="space-y-3">
          <Breadcrumb>
            <BreadcrumbList>
              <BreadcrumbItem>
                <BreadcrumbPage>Visão geral</BreadcrumbPage>
              </BreadcrumbItem>
            </BreadcrumbList>
          </Breadcrumb>
          <div>
            <div className="flex flex-wrap items-center gap-3">
              <h1 className="text-3xl font-extrabold tracking-[-0.05em] text-ink-900 sm:text-4xl">
                Visão geral
              </h1>
              <Badge variant="secondary" className="rounded-md bg-brand-100 text-brand-800">
                Estrutura inicial
              </Badge>
            </div>
            <p className="mt-2 max-w-2xl text-sm leading-6 text-ink-600 sm:text-base">
              Um ponto de partida para organizar eventos, acompanhar ingressos e operar a entrada.
            </p>
          </div>
        </div>
        <Button disabled size="lg" className="h-12 gap-2 rounded-lg px-5">
          <Plus className="size-4" aria-hidden="true" />
          Criar evento
        </Button>
      </div>

      <section aria-labelledby="summary-heading" className="space-y-4">
        <div className="flex items-center justify-between">
          <h2 id="summary-heading" className="text-lg font-extrabold tracking-[-0.03em] text-ink-900">
            Resumo da operação
          </h2>
          <span className="text-xs font-semibold text-ink-500">Dados aparecerão após a conexão</span>
        </div>
        <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
          <MetricCard label="Eventos ativos" icon={CalendarDays} detail="Nenhum evento carregado" />
          <MetricCard label="Ingressos vendidos" icon={Ticket} detail="Nenhum pedido carregado" />
          <MetricCard label="Check-ins hoje" icon={ClipboardCheck} detail="A operação ainda não começou" />
          <MetricCard label="Saldo previsto" icon={BarChart3} detail="Prestação de contas pendente" />
        </div>
      </section>

      <div className="grid gap-5 xl:grid-cols-[minmax(0,1.5fr)_minmax(18rem,0.75fr)]">
        <Card className="rounded-[1.25rem] border-border shadow-[0_2px_12px_rgba(27,39,64,0.03)]">
          <CardHeader className="flex flex-row items-start justify-between gap-4 p-6 pb-2">
            <div>
              <CardTitle className="text-lg font-extrabold tracking-[-0.03em] text-ink-900">
                Próxima fatia de operação
              </CardTitle>
              <p className="mt-1 text-sm text-ink-600">O fluxo será construído nesta ordem.</p>
            </div>
            <ArrowUpRight className="size-5 text-brand-700" aria-hidden="true" />
          </CardHeader>
          <CardContent className="p-6 pt-4">
            <ol className="divide-y divide-border">
              {[
                ["01", "Organização e evento", "Definir o espaço de trabalho e o primeiro evento."],
                ["02", "Lotes e pedidos", "Registrar a composição comercial sem apagar histórico."],
                ["03", "Ingresso e check-in", "Validar entradas com resposta idempotente."],
                ["04", "Prestação de contas", "Fechar o ciclo com lançamentos auditáveis."],
              ].map(([number, title, description]) => (
                <li key={number} className="flex gap-4 py-4 first:pt-1 last:pb-1">
                  <span className="flex size-8 shrink-0 items-center justify-center rounded-lg bg-brand-100 text-xs font-extrabold text-brand-800">
                    {number}
                  </span>
                  <div>
                    <h3 className="text-sm font-bold text-ink-900">{title}</h3>
                    <p className="mt-1 text-sm leading-5 text-ink-600">{description}</p>
                  </div>
                </li>
              ))}
            </ol>
          </CardContent>
        </Card>

        <Card className="rounded-[1.25rem] border-border bg-brand-50 shadow-none">
          <CardHeader className="p-6 pb-2">
            <CardTitle className="text-lg font-extrabold tracking-[-0.03em] text-brand-900">
              Operação segura por padrão
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4 p-6 pt-3">
            <p className="text-sm leading-6 text-brand-800">
              Cada ação relevante deve respeitar a organização, registrar seu ator e deixar um caminho de auditoria.
            </p>
            <div className="space-y-3 text-sm text-brand-800">
              <div className="flex gap-3">
                <span className="mt-1 size-2 shrink-0 rounded-full bg-brand-500" />
                <span>RLS em todos os dados de negócio</span>
              </div>
              <div className="flex gap-3">
                <span className="mt-1 size-2 shrink-0 rounded-full bg-brand-500" />
                <span>Check-in sem duplicidade</span>
              </div>
              <div className="flex gap-3">
                <span className="mt-1 size-2 shrink-0 rounded-full bg-brand-500" />
                <span>Financeiro imutável e rastreável</span>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  )
}

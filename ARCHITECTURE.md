# Visão de arquitetura

Documento vivo. Descreve a arquitetura **como ela está hoje**, não como se pretende que
fique. Quando algo não existe, isto está dito de forma explícita — não presuma capacidade
a partir de uma seção preenchida.

Complementos: [`CLAUDE.md`](./CLAUDE.md) (mapa de código e convenções),
[`AGENTS.md`](./AGENTS.md) (regras de trabalho), [`CONTEXT.md`](./CONTEXT.md) (linguagem do
domínio), [`docs/adr/`](./docs/adr/) (por que as decisões foram tomadas).

## 1. Estrutura do projeto

Não há separação `backend/` e `frontend/`: por decisão de arquitetura
([ADR 0001](./docs/adr/0001-monolito-modular.md)) o produto é um monólito modular Next.js.
Servidor e cliente convivem na mesma árvore, separados por Server Components, Route
Handlers e o proxy.

```text
webingressos-app/
├── proxy.ts                      # proxy do Next 16: refresh de sessão + proteção de rotas
├── next.config.ts                # sem opções customizadas hoje
├── eslint.config.mjs             # flat config, eslint-config-next
├── postcss.config.mjs            # @tailwindcss/postcss
├── components.json               # config do shadcn CLI (estilo base-nova, rsc: true)
├── src/
│   ├── app/                      # camada de rotas (App Router)
│   │   ├── layout.tsx            # <html lang="pt-BR"> + QueryProvider
│   │   ├── page.tsx              # redirect("/dashboard")
│   │   ├── globals.css           # tokens CSS e @theme inline — fonte da paleta
│   │   ├── (auth)/login/         # login, renderizado fora do shell
│   │   ├── (dashboard)/          # rotas dentro do AppShell
│   │   │   ├── layout.tsx
│   │   │   ├── dashboard/        # visão geral
│   │   │   └── [module]/         # eventos, ingressos, check-in, promoters,
│   │   │                         #   relatorios, configuracoes
│   │   └── auth/callback/route.ts# Route Handler: troca o code OAuth por sessão
│   ├── components/               # camada de apresentação
│   │   ├── ui/                   # primitivas geradas pelo shadcn sobre Base UI
│   │   ├── layout/               # AppShell, BrandMark
│   │   ├── auth/                 # LoginForm (client component)
│   │   ├── dashboard/            # MetricCard
│   │   └── providers/            # QueryProvider
│   ├── lib/                      # camada de infraestrutura
│   │   ├── supabase/             # config, client, server, proxy, database.types
│   │   ├── query-client.ts       # QueryClient compartilhado
│   │   └── utils.ts              # cn()
│   └── modules/                  # camada de domínio — um diretório por bounded context
│       ├── identity/domain.ts    # organização, membership, papéis
│       ├── events/domain.ts      # evento, status, colaboração
│       ├── sales/domain.ts       # pedido, ingresso
│       ├── promoters/domain.ts   # promoter e comissão
│       ├── operations/domain.ts  # check-in
│       ├── finance/domain.ts     # lançamento financeiro, Money
│       └── audit/domain.ts       # trilha de auditoria
├── supabase/
│   ├── config.toml               # config do Supabase CLI
│   └── migrations/               # schema, RLS, funções de autorização e check-in
├── docs/adr/                     # decisões de arquitetura aceitas
├── public/                       # assets estáticos
├── AGENTS.md · CLAUDE.md · CONTEXT.md · DESIGN.md · README.md
└── ARCHITECTURE.md               # este documento
```

Alias de import: `@/*` → `./src/*`.

**Direção de dependência entre módulos.** Explícita, via `import type`, sem ciclos:

```text
identity ← events ← { sales, promoters, finance }
                       └── sales ← operations
identity ← audit
```

## 2. Diagrama do sistema

```text
                        ┌──────────────────────────────┐
   [Organizador]        │      Navegador               │
   [Equipe de ops] ───► │  Next.js — Client Components │
   [Portaria]           │  AppShell · LoginForm        │
                        └───────────┬──────────────────┘
                                    │ HTTPS
                        ┌───────────▼──────────────────┐
                        │  Next.js (servidor)          │
                        │                              │
                        │  proxy.ts ──► updateSession  │──┐ auth.getClaims()
                        │  Server Components           │  │ redirect /login
                        │  Route Handler /auth/callback│  │
                        └───────────┬──────────────────┘  │
                                    │                     │
             ┌──────────────────────┴─────────────────────┘
             │ @supabase/ssr (cookies de sessão)
             │
   ┌─────────▼─────────────────────────────────────────┐
   │                    Supabase                       │
   │                                                   │
   │  Auth (auth.users, JWT em cookie)                 │
   │  PostgREST ──► Postgres                           │
   │                 ├── RLS por organização/evento    │
   │                 ├── helpers security definer      │
   │                 └── check_in_ticket()             │
   └───────────────────────────────────────────────────┘
```

Dois caminhos de escrita coexistem por desenho:

1. **Tabela + RLS** para CRUD comum — a política é a autorização, não o código da aplicação.
2. **Função `security definer`** quando a operação precisa de atomicidade e de uma regra que
   não cabe numa policy — hoje `check_in_ticket` e `create_organization`.

Não existe camada de API própria entre o app e o banco. Isso é intencional: a autorização
mora no Postgres, então um cliente que escape do app ainda é barrado pela mesma regra.

## 3. Componentes principais

### 3.1. Frontend

- **Nome:** app operacional (`app.webingressos.com.br`).
- **Descrição:** interface de organizadores e equipes de operação. Hoje entrega shell de
  navegação, tela de login funcional e páginas placeholder por módulo. **Nenhuma tela lê
  dados reais ainda** — o dashboard, o seletor de organização e o nome no header são
  estáticos.
- **Tecnologias:** Next.js 16 (App Router), React 19, TypeScript estrito, Tailwind CSS v4,
  Base UI via shadcn CLI, `lucide-react`, TanStack Query.
- **Padrão:** Server Components por padrão; `"use client"` apenas onde há estado, evento ou
  hook — hoje `AppShell`, `LoginForm` e `QueryProvider`.
- **Deploy:** não configurado neste repositório. Não há `vercel.json`, Dockerfile nem
  workflow de deploy.

### 3.2. Serviços de backend

Não existem serviços de backend separados. O que faria papel de backend está em três
lugares, todos dentro deste repositório ou do Postgres:

#### 3.2.1. Camada de servidor do Next

- **Responsabilidade:** renderização no servidor, refresh de sessão e proteção de rotas.
- **Arquivos:** `src/proxy.ts`, `src/lib/supabase/proxy.ts`, `src/lib/supabase/server.ts`,
  `src/app/auth/callback/route.ts`.
- **Tecnologias:** Next.js runtime, `@supabase/ssr`.

#### 3.2.2. Regras no Postgres

- **Responsabilidade:** autorização e as operações que exigem atomicidade.
- **Superfície:** políticas RLS em todas as tabelas de negócio, quatro helpers
  `security definer` (`is_org_member`, `has_org_role`, `can_access_event`,
  `has_event_role`) e duas funções de operação (`check_in_ticket`, `create_organization`).
- **Tecnologias:** PostgreSQL (Supabase), SQL/plpgsql.

#### 3.2.3. Contratos de domínio

- **Responsabilidade:** vocabulário tipado compartilhado. Cada módulo em `src/modules/`
  expõe hoje só um `domain.ts` com tipos — ainda não há casos de uso implementados.
- **Convenções:** branded IDs (`EventId`, `OrderId`, …), `Money = { cents: bigint;
  currency: "BRL" }`, instantes como string ISO em UTC, resultados discriminados no lugar
  de exceções (`CheckInResult`).

## 4. Armazenamento de dados

### 4.1. Postgres (Supabase)

- **Nome:** `webingressos-dev`, organização `proframos`, região `sa-east-1`, ref
  `zcvkdgethbhgaownygzs`. Único ambiente existente; não há staging nem produção.
- **Tipo:** PostgreSQL gerenciado pelo Supabase.
- **Propósito:** todo o estado do produto — tenants, eventos, comercial, operação de
  entrada, financeiro e auditoria.
- **Tabelas:**

  | Contexto | Tabelas |
  | --- | --- |
  | Identidade | `organizations`, `organization_memberships` |
  | Eventos | `events`, `event_organizations`, `event_status_history`, `lots` |
  | Comercial | `promoters`, `orders`, `order_items`, `tickets` |
  | Operação | `check_ins` |
  | Financeiro e trilha | `ledger_entries`, `audit_logs` |

- **Padrões de schema:** chave interna `bigint generated always as identity` e
  identificador externo `public_id uuid`; valores em `*_cents bigint` com
  `check (currency = 'BRL')`; `on delete restrict` em quase toda FK; índice para toda FK e
  para toda coluna usada em predicado de RLS.
- **Migrations:** três, em `supabase/migrations/`, já aplicadas no ambiente remoto.
  Alterações entram em migration nova, nunca editando as existentes.

### 4.2. Cache, fila e storage

Não existem. Sem Redis, sem broker de mensagens, sem uso de Supabase Storage. O cache do
lado do cliente é o do TanStack Query (`staleTime` 30 s, `refetchOnWindowFocus` desligado,
em `src/lib/query-client.ts`). [ADR 0001](./docs/adr/0001-monolito-modular.md) rejeita
introduzir filas ou workers como abstração antecipada.

## 5. Integrações externas

Uma só: **Supabase** (Auth + Postgres), consumido via `@supabase/supabase-js` e
`@supabase/ssr`.

Não há gateway de pagamento, provedor de e-mail/SMS, antifraude nem serviço de mapas
integrado. Checkout e cobrança ainda não existem no produto.

## 6. Deploy e infraestrutura

Esta seção é curta porque quase nada está configurado no repositório.

- **Provedor de nuvem:** Supabase para banco e autenticação. Hospedagem do app não definida
  aqui.
- **CI/CD:** **não existe.** Não há diretório `.github/` nem qualquer workflow. As
  verificações locais são `pnpm check` (lint + typecheck + build) e
  `pnpm supabase:test` (pgTAP de RLS e check-in).
- **Monitoramento e logs:** não configurados. Sem APM, sem agregador de logs, sem
  rastreamento de erros.
- **Configuração de runtime:** duas variáveis públicas, lidas apenas em
  `src/lib/supabase/config.ts` — `NEXT_PUBLIC_SUPABASE_URL` e
  `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`. Todo `.env*` está no `.gitignore`.

## 7. Segurança

- **Autenticação:** Supabase Auth. Sessão em cookie, gerenciada por `@supabase/ssr`. O
  login atual é e-mail e senha (`signInWithPassword`); o Route Handler
  `/auth/callback` já suporta a troca de code por sessão para OAuth e magic link.
- **Autorização:** RBAC por organização e evento, aplicado **no banco** via RLS. Papéis:
  `owner`, `finance`, `ops`, `gate`. Leitura de `tickets` e `check_ins` inclui `gate`;
  `ledger_entries` é restrito a `owner` e `finance`. As políticas reusam os quatro helpers
  em vez de repetir joins, e avaliam `(select auth.uid())` uma vez por consulta.
- **Verificação de sessão:** `auth.getClaims()` no servidor e no proxy. `getSession()`
  **não** é tratado como mecanismo de autorização.
- **Segredos:** apenas chaves públicas chegam ao browser. `service_role` e chaves secretas
  não entram no repositório, no cliente nem em exemplos. A senha do banco fica no 1Password
  (vault `webingressos`) e é digitada só no prompt do `supabase link`.
- **Exposição de tabelas:** o projeto não auto-expõe entidades novas; cada `grant` é
  explícito nas migrations, com a RLS como fronteira de autorização.
- **Identificadores:** URLs, QR codes e integrações usam só o `public_id` opaco, nunca a
  chave sequencial interna.
- **Integridade do check-in:** `unique (ticket_id)` em `check_ins` mais
  `on conflict do nothing` dentro de `check_in_ticket` — a idempotência é uma constraint do
  banco, não uma verificação otimista no app.
- **Criptografia:** TLS em trânsito e criptografia em repouso são os padrões da plataforma
  Supabase. Não há criptografia em nível de aplicação nem de coluna.

> **Configuração obrigatória.** Se as variáveis do Supabase não estiverem definidas,
> `updateSession` bloqueia as rotas protegidas e mantém públicas apenas as rotas de login
> e callback.

## 8. Ambiente de desenvolvimento e testes

- **Setup local:** `pnpm install`, criar `.env.local` com as duas variáveis públicas,
  `pnpm dev`. Passo a passo no [`README.md`](./README.md).
- **Banco:** pgTAP via `supabase test db --local`, com testes em
  `supabase/tests/database/rls_and_check_in.sql` para isolamento RLS, papéis de acesso e
  idempotência do check-in.
- **Aplicação:** não há testes unitários, de integração do Next.js ou E2E.
- **Qualidade de código:** ESLint (flat config, `eslint-config-next` com core-web-vitals e
  regras de TypeScript) e `tsc --noEmit` em modo estrito. `pnpm check` encadeia lint,
  typecheck e build.
- **Verificação de UI:** manual — viewport móvel e desktop, foco visível, contraste, estados
  de carregamento/erro/vazio e navegação por teclado.
- **Banco local:** `supabase/config.toml` existe e permite subir a stack local, mas o fluxo
  usado hoje aponta para o projeto remoto de desenvolvimento via `supabase link`.

## 9. Débitos e evolução

Débitos conhecidos, em ordem aproximada de impacto:

1. **Sem testes do app, E2E e CI.** As regras de RLS e a idempotência do check-in já têm
   cobertura pgTAP local, mas os fluxos de interface ainda não têm rede de segurança.
2. **Nenhum fluxo de negócio conectado.** Todas as telas são estáticas; o schema existe mas
   ninguém escreve nele pelo app.
3. **`database.types.ts` gerado mas não ligado.** Nenhum `createClient` usa o genérico
   `Database`, então as consultas não são tipadas de ponta a ponta.
4. **`LoginForm` ignora o `next`** da query string que o próprio proxy define; sempre
   redireciona para `/dashboard`.
5. **Logout, recuperação de senha e convites** não implementados.
6. **Deploy e observabilidade** não definidos.

Evoluções previstas, com a fronteira arquitetural já reservada:

- **Check-in offline.** [ADR 0003](./docs/adr/0003-checkin-online-first.md) mantém o scanner
  isolado para que uma camada Expo/React Native reuse os contratos sem que a decisão de app
  nativo precise ser tomada agora.
- **Colaboração entre organizações.** `event_organizations` e os helpers já cobrem
  organização dona e colaboradora; falta a interface de convite.
- **Extração de módulos.** [ADR 0001](./docs/adr/0001-monolito-modular.md) mantém os módulos
  extraíveis se volume ou equipe justificarem — sem microserviços antecipados.

## 10. Identificação do projeto

- **Nome:** WebIngressos App
- **Repositório:** https://github.com/prof-ramos/webingressos-app
- **Repositório relacionado:** [`webingressos-page`](https://github.com/prof-ramos/webingressos-page) — landing page comercial, escopo separado
- **Responsável:** `prof-ramos`
- **Última atualização deste documento:** 2026-08-01

## 11. Glossário

Definições completas em [`CONTEXT.md`](./CONTEXT.md). Resumo dos termos que aparecem neste
documento:

| Termo | Significado |
| --- | --- |
| **Organização** | Tenant primário. Responsável operacional pelo evento ([ADR 0002](./docs/adr/0002-organizacao-como-tenant.md)). |
| **Membro** | Pessoa vinculada a uma organização, com um papel. |
| **Papel** | `owner`, `finance`, `ops` ou `gate`. Verificado por organização e recurso. |
| **Colaborador do evento** | Organização autorizada a operar um evento sem ser dona do tenant. |
| **Evento** | Unidade operacional com ciclo de vida, lotes, pedidos e operação de entrada. |
| **Lote** | Janela comercial com capacidade, preço e período próprios. |
| **Promoter** | Registro operacional para atribuição de vendas e comissão. Sem login nesta fase. |
| **Pedido** | Agregado comercial de uma compra ou lançamento operacional. |
| **Ingresso** | Credencial individual com código público opaco, validável uma única vez. |
| **Check-in** | Primeira validação bem-sucedida de um ingresso. Operação idempotente. |
| **Lançamento financeiro** | Registro imutável de receita, despesa, comissão, divisão ou repasse. |
| **Prestação de contas** | Conferência e fechamento dos lançamentos de um evento. |
| **Auditoria** | Registro append-only de ações relevantes, com ator e instante. |
| **Motivo** | Justificativa humana exigida em mudanças sensíveis. |
| **ADR** | *Architecture Decision Record*. Registro de decisão em `docs/adr/`. |
| **RLS** | *Row Level Security*. Autorização por linha, aplicada no Postgres. |
| **RSC** | *React Server Component*. Padrão de renderização deste app. |

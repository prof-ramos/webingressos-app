@AGENTS.md

# Guia do repositório `webingressos-app`

Este arquivo descreve **como o código está organizado hoje**. As regras obrigatórias
de trabalho estão em [`AGENTS.md`](./AGENTS.md) (importado acima); a linguagem do
domínio está em [`CONTEXT.md`](./CONTEXT.md). Quando houver conflito, `AGENTS.md` e
`CONTEXT.md` vencem este arquivo.

## Escopo

App operacional de `app.webingressos.com.br` — organizadores e equipes de operação de
eventos universitários. A landing page comercial vive em outro repositório
([`webingressos-page`](https://github.com/prof-ramos/webingressos-page)) e nada de
autenticação, checkout ou backoffice deve ir para lá.

**Estado atual: fundação.** Existem shell visual, contratos de domínio, camada SSR do
Supabase e o schema com RLS. Não existem fluxos de negócio conectados nem cobertura E2E;
os gates de aplicação e banco rodam localmente e no CI.
Ver [Lacunas conhecidas](#lacunas-conhecidas) antes de assumir que algo funciona.

## Stack

| Camada | Escolha |
| --- | --- |
| Framework | Next.js 16 (App Router), React 19, TypeScript estrito |
| Estilo | Tailwind CSS v4 (`@theme inline` em `src/app/globals.css`), sem `tailwind.config` |
| Componentes | shadcn CLI sobre **Base UI** (`@base-ui/react`) — **não** Radix |
| Ícones | `lucide-react` |
| Backend | Supabase (Postgres + Auth) via `@supabase/ssr` |
| Estado remoto | TanStack Query, só onde houver interatividade real |
| Gerenciador | pnpm (10.x) |

## Comandos

```bash
pnpm install
pnpm dev              # servidor de desenvolvimento
pnpm lint             # eslint (flat config, eslint-config-next)
pnpm typecheck        # tsc --noEmit
pnpm test             # testes da aplicação com Vitest
pnpm check            # lint + typecheck + testes + build — gate completo da aplicação
```

Supabase:

```bash
supabase link --project-ref zcvkdgethbhgaownygzs   # senha só no prompt local, nunca versionada
pnpm supabase:push                                 # aplica supabase/migrations no projeto linkado
pnpm supabase:types                                # regenera src/lib/supabase/database.types.ts
pnpm supabase:test                                 # executa os testes pgTAP locais de RLS e check-in
```

`pnpm supabase:types` **sobrescreve** `src/lib/supabase/database.types.ts`. O arquivo é
gerado; não editar à mão.

## Variáveis de ambiente

Apenas duas chaves públicas são lidas, e somente em `src/lib/supabase/config.ts`:

- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`

Chaves `service_role`/secret não entram no browser, no repositório nem em exemplos.
`.env*` está no `.gitignore`. Não ler `process.env` de Supabase fora de `config.ts` —
use `getSupabaseConfig()` (tolerante à ausência) ou `requireSupabaseConfig()` (lança erro).

## Estrutura

```text
src/proxy.ts                  # entrada do proxy do Next 16 (equivalente ao antigo middleware)
src/
├── app/
│   ├── layout.tsx            # html lang="pt-BR" + QueryProvider
│   ├── page.tsx              # redirect("/dashboard")
│   ├── globals.css           # tokens CSS + @theme inline (fonte da paleta)
│   ├── (auth)/login/         # tela de login, fora do shell
│   ├── (dashboard)/
│   │   ├── layout.tsx        # envolve tudo em <AppShell>
│   │   ├── dashboard/        # visão geral
│   │   └── [module]/         # eventos, ingressos, check-in, promoters, relatorios, configuracoes
│   └── auth/callback/route.ts# troca do code OAuth/magic link por sessão
├── components/
│   ├── ui/                   # primitivas geradas pelo shadcn (Base UI) — não editar sem motivo
│   ├── layout/               # AppShell (sidebar + header + sheet mobile), BrandMark
│   ├── auth/login-form.tsx   # client component, signInWithPassword
│   ├── dashboard/            # MetricCard
│   └── providers/            # QueryProvider
├── lib/
│   ├── supabase/             # config, client (browser), server (RSC), proxy (sessão), database.types
│   ├── query-client.ts       # staleTime 30s, refetchOnWindowFocus off
│   └── utils.ts              # cn()
└── modules/                  # contratos de domínio, um diretório por bounded context
    ├── identity/  events/  sales/  promoters/  operations/  finance/  audit/
supabase/
├── config.toml
└── migrations/               # 3 migrations: identity+events, sales+operations, finance+audit
docs/adr/                     # 4 ADRs aceitos
```

Alias de import: `@/*` → `./src/*`.

## Arquitetura

### Autenticação e proteção de rotas

O fluxo inteiro passa por três arquivos:

1. `src/proxy.ts` — o Next 16 chama `proxy()` para todas as rotas exceto assets estáticos.
   O arquivo precisa ficar ao lado de `app/`; na raiz do repositório o Next o ignora em silêncio.
   Ele apenas delega para `updateSession`.
2. `src/lib/supabase/proxy.ts` — cria um `createServerClient` ligado aos cookies do
   request, chama `auth.getClaims()` e redireciona para `/login?next=<path>` quando não
   há claims. Rotas públicas: `/login` e qualquer coisa sob `/auth`.
3. `src/lib/supabase/server.ts` — cliente para Server Components e Route Handlers. O
   `setAll` é envolvido em `try/catch` porque Server Components nem sempre podem
   escrever cookies; o refresh real acontece no proxy.

Use `auth.getClaims()` como mecanismo de autorização no servidor/proxy. **Não** trate
`getSession()` como autorização.

> As variáveis do Supabase são obrigatórias. Sem elas, `updateSession` bloqueia as rotas
> protegidas e mantém públicas apenas as rotas de login e callback.

### Módulos de domínio

Cada diretório em `src/modules/` expõe hoje só um `domain.ts` com tipos. Convenções já
estabelecidas ali:

- **Branded IDs**: `type EventId = string & { readonly __brand: "EventId" }`. Novos IDs
  seguem o mesmo padrão — não usar `string` cru para identificadores.
- **Status em português** quando são conceitos do produto (`EventStatus`:
  `rascunho | planejado | vendas_abertas | encerrado | prestacao_contas_fechada |
  cancelado`), em inglês quando são estados técnicos genéricos (`OrderStatus`,
  `LedgerEntryKind`). Manter a grafia idêntica à do enum Postgres correspondente.
- **Dinheiro**: `Money = { cents: bigint; currency: "BRL" }`. Nunca float, nunca reais.
- **Instantes**: string ISO em UTC no TS, `timestamptz` no banco.
- **Resultados discriminados** em vez de exceções para regras de negócio — ver
  `CheckInResult` em `src/modules/operations/domain.ts`.

Dependências entre módulos são explícitas via `import type`. A direção atual é
`identity ← events ← {sales, promoters, finance}` e `sales ← operations`. Não criar
ciclos.

### Camada de dados

Três clientes distintos, cada um com seu lugar:

| Arquivo | Uso |
| --- | --- |
| `src/lib/supabase/client.ts` | Client Components (`"use client"`) |
| `src/lib/supabase/server.ts` | Server Components, Route Handlers, Server Actions |
| `src/lib/supabase/proxy.ts` | apenas o proxy, para refresh de sessão |

Leituras simples ficam em Server Components. TanStack Query é para estado remoto
interativo (listas com filtro, mutações otimistas, polling) — não para buscar dados
que a página poderia renderizar no servidor.

## Banco de dados

As migrations em `supabase/migrations/` já criam o modelo completo da primeira fatia
vertical e **já foram aplicadas no projeto remoto de dev**. Alterações vão em migrations
novas (`supabase migration new <nome>`), nunca editando as existentes.

Tabelas: `organizations`, `organization_memberships`, `events`, `event_organizations`,
`event_status_history`, `lots`, `promoters`, `orders`, `order_items`, `tickets`,
`check_ins`, `ledger_entries`, `audit_logs`.

### Padrões de schema

- Chave interna `bigint generated always as identity`; identificador externo
  `public_id uuid` único. URLs, QR codes e integrações usam só o público.
- Valores em `*_cents bigint` com `currency text check (currency = 'BRL')`.
- `on delete restrict` em quase todas as FKs — dados operacionais não são apagados.
- Índice para toda FK e para toda coluna usada em predicado de RLS.
- RLS habilitada em **todas** as tabelas de negócio, com `grant` explícito
  (o projeto não auto-expõe tabelas novas).

### Helpers de autorização

Quatro funções `security definer` centralizam a checagem e devem ser reusadas nas
políticas novas em vez de reescrever joins:

- `is_org_member(organization_id)`
- `has_org_role(organization_id, allowed_roles[])`
- `can_access_event(event_id)` — cobre organização dona **e** colaboradoras
- `has_event_role(event_id, allowed_roles[])`

Sempre `(select auth.uid())` para que o planner avalie uma vez por consulta.
Papéis: `owner`, `finance`, `ops`, `gate`. Leitura de `tickets`/`check_ins` inclui
`gate`; `ledger_entries` é restrito a `owner`/`finance`.

### Check-in

`public.check_in_ticket(ticket_code, target_event_public_id, scanner_device_label)` é a
única porta de entrada. Ela valida o papel do ator, confere evento e status do pedido,
usa `unique (ticket_id)` + `on conflict do nothing` para idempotência e devolve
`accepted | already_checked_in | invalid`. A transação é curta e não faz chamada externa.
Qualquer evolução do check-in mantém essas quatro propriedades.

## Convenções de código

- Server Components por padrão; `"use client"` só quando há estado, evento ou hook.
- TypeScript estrito. Sem `any`, sem `@ts-ignore`.
- Imports agrupados: externos, depois `@/…`, separados por linha em branco.
- Sem ponto e vírgula na maior parte do `src/` (os arquivos herdados do template —
  `src/app/layout.tsx`, `src/app/page.tsx` — ainda usam; siga o arquivo que estiver editando).
- Texto de interface em **português-BR**. Comentários de código e nomes de identificadores
  em inglês, exceto os termos de domínio definidos em `CONTEXT.md`.
- Acessibilidade não é opcional: `aria-label` em controles só com ícone, `aria-hidden`
  em ícones decorativos, `sr-only` para títulos de sheet, `role="alert"` em erros.

## Interface

- **Light-only e mobile-first.** O `@custom-variant dark (&:is(.never-dark *))` em
  `globals.css` desativa o modo escuro de propósito — não reintroduzir.
- Use os tokens (`bg-brand-100`, `text-ink-600`, `border-border`, `text-destructive`).
  Não escrever hex cru nem trazer uma segunda matiz. Verde é recurso escasso: no máximo
  um elemento saturado por tela.
- Raios: controle `rounded-lg`, card `rounded-[1.25rem]`. Sombras são um sussurro
  (`shadow-[0_2px_12px_rgba(27,39,64,0.03)]`), nunca gloss.
- Fonte única: Plus Jakarta Sans, inclusive para números e valores.
- Antes de concluir UI: viewport móvel e desktop, foco visível, contraste, estados de
  carregamento/erro/vazio e navegação por teclado.

Detalhes completos em [`DESIGN.md`](./DESIGN.md) — snapshot local derivado do design
canônico da landing page. `satnaing/shadcn-admin` é referência de composição
(sidebar, busca, tabelas), mas seus componentes não são importados: ele usa Vite/Radix,
este app usa Next/Base UI (ADR 0004).

## Adicionar um componente de UI

```bash
pnpm dlx shadcn@latest add <componente>
```

`components.json` já aponta para o estilo `base-nova`, `rsc: true` e os aliases do
projeto. O componente cai em `src/components/ui/`. Revise o resultado para que ele use
os tokens do projeto antes de commitar.

## Armadilhas conhecidas

Cada item abaixo foi um defeito real neste repositório, encontrado só por inspeção do build
ou do DOM. Nenhum deles falha `pnpm check`.

### Falhas silenciosas de configuração

- **`src/proxy.ts` tem de ficar ao lado de `app/`.** Na raiz do repositório o Next 16 o ignora
  sem erro: `middleware-manifest.json` fica vazio e **nenhuma rota é protegida**. Confira que o
  build lista `ƒ Proxy (Middleware)` e que `GET /dashboard` sem sessão responde 307.
- **CSS fora de `@layer` vence todas as camadas do Tailwind.** Um `* { border-color }` solto em
  `globals.css` anulava `focus-visible:border-ring`, `aria-invalid:border-destructive` e
  `border-transparent`. Regras base vão em `@layer base`, sempre.
- **Fonte declarada não é fonte carregada.** `--font-sans` apontava para Plus Jakarta Sans sem
  ninguém baixá-la. Ao mexer em tipografia, confirme `document.fonts` no navegador.

### Base UI (não é Radix — a API difere)

- **`Select` mostra o *valor*, não o rótulo.** Sem a prop `items` no `Select.Root`, o gatilho
  exibe o slug cru.
- **`Menu.GroupLabel` exige `Menu.Group` em volta.** Solto, lança `MenuGroupContext is missing`
  em tempo de execução e o menu abre vazio.
- **`render` com elemento nativo precisa de `nativeButton`.** Sem essa prop o `MenuItem`
  intercepta `Enter`/`Espaço` e o botão nativo nunca ativa — controle só funciona com o mouse.

### Auth e redirecionamento

- **Identidade no servidor vem de `getClaims()`.** `getUser()` custa uma requisição ao serviço
  de Auth em cada render; o e-mail está em `JwtPayload.email`.
- **Validar `?next=` por prefixo de string não basta.** `searchParams.get` decodifica, então
  `%2F%5Cevil.example` chega como `/\evil.example` — passa em `startsWith("/")` e o parser de URL
  normaliza para outro host. Compare a origem já parseada, como `auth/callback` faz.
- **O código de erro do Supabase é `invalid_credentials`.** Filtre por `error.code`, nunca por
  `error.message`.
- **Logout que falha não pode redirecionar como sucesso** — a sessão pode continuar válida.

### Interface

- **As variantes de `Button`/`Input`/`SelectTrigger` já carregam a escala de `DESIGN.md`**
  (44 compacto / 48 campo / 56 primário). Use `size="lg"` para a ação primária da tela em vez de
  corrigir altura, padding ou peso com `className`.

### Como verificar

- **Abra o que é interativo.** Medir controles em estado fechado esconde defeitos: dois bugs
  (menu da conta vazio, logout sem teclado) sobreviveram a uma rodada inteira de verificação
  porque o dropdown nunca foi aberto. Acione por **mouse e por teclado**, e observe `pageerror`.
- **Leia estilo computado depois da transição.** Com `transition-colors`, medir logo após o
  `Tab` devolve a cor de origem e simula um defeito que não existe.
- **Para auditar telas autenticadas sem sessão**, uma rota temporária sob `/auth/*` (público no
  proxy) renderiza `AppShell` + a página. Remova antes de commitar.
- **`tsc` falha com `.next/types` obsoleto** depois de apagar uma rota; rode o build antes de
  concluir que o erro é do código.

## Lacunas conhecidas

Não presuma que estas coisas existem:

- **Sem E2E ou fluxos de negócio conectados.** A suíte Vitest cobre a configuração do app
  e o workflow em `.github/workflows/ci.yml` executa os gates da aplicação e do banco;
  a suíte pgTAP em `supabase/tests/database/` continua cobrindo RLS e idempotência do
  check-in.
- **Configuração local:** copie `.env.example` para `.env.local` e preencha as duas
  variáveis públicas. Nenhum segredo entra no exemplo, no repositório ou no CI.
- **`database.types.ts` é gerado mas não está ligado aos clientes** — nenhum
  `createClient` usa o genérico `Database`. Ligar isso é uma melhoria pendente.
- **Nenhuma tela lê dados de negócio reais.** Dashboard, módulos e o seletor de organização
  do `AppShell` são estáticos; o e-mail exibido no header vem da sessão autenticada, lido no
  `layout.tsx` do grupo `(dashboard)`.
- **Recuperação de senha e convites** ainda não estão implementados. Logout existe em
  `POST /auth/sign-out`; `Perfil` e `Preferências` no menu da conta seguem desabilitados.
- Não inventar dados, clientes, resultados ou disponibilidade em nenhuma tela.

Auditoria de interface, o que já foi corrigido e o que continua aberto:
[`docs/ux-ui-auditoria.md`](./docs/ux-ui-auditoria.md).

## Onde procurar decisões

| Pergunta | Arquivo |
| --- | --- |
| Visão geral dos componentes e integrações | [`ARCHITECTURE.md`](./ARCHITECTURE.md) |
| Regras obrigatórias de trabalho | [`AGENTS.md`](./AGENTS.md) |
| Significado de um termo do domínio | [`CONTEXT.md`](./CONTEXT.md) |
| Cor, tipografia, espaçamento, componente | [`DESIGN.md`](./DESIGN.md) |
| Por que a arquitetura é assim | [`docs/adr/`](./docs/adr/) |
| Regras de migration e RLS | [`supabase/README.md`](./supabase/README.md) |
| Ordem da primeira fatia vertical | [`README.md`](./README.md) |

ADRs aceitos: 0001 monólito modular · 0002 organização como tenant · 0003 check-in
online-first · 0004 shadcn-admin como referência.

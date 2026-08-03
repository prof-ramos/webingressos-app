# WebIngressos App

Aplicação operacional da WebIngressos para organizadores e equipes de operação de eventos
universitários. Este repositório é separado da landing page comercial em
[`webingressos-page`](https://github.com/prof-ramos/webingressos-page) — autenticação,
checkout, backoffice e regras operacionais vivem aqui e não lá.

O produto é um monólito modular: uma aplicação Next.js com fronteiras de domínio claras,
Supabase para autenticação e persistência, e uma primeira experiência online-first para
operação e check-in.

## Estado atual

Esta é a **fundação** do produto, não uma versão pronta para produção.

Já existe:

- shell visual completo (sidebar, header, navegação mobile) e tela de login;
- contratos de domínio em `src/modules/`, um diretório por bounded context;
- camada SSR do Supabase (cliente de browser, de servidor e refresh de sessão no proxy);
- schema completo da primeira fatia vertical, com RLS e políticas por organização/evento,
  já aplicado no projeto remoto de desenvolvimento.

Ainda não existe:

- nenhuma tela lendo dados reais — o dashboard e os módulos são estáticos;
- fluxos de negócio conectados (criar evento, vender, escanear, fechar contas);
- logout, recuperação de senha e convites;
- fluxos E2E e monitoramento de produção.

## Stack

| Camada | Escolha |
| --- | --- |
| Framework | Next.js 16 (App Router), React 19, TypeScript estrito |
| Estilo | Tailwind CSS v4 com tokens em `src/app/globals.css` |
| Componentes | shadcn CLI sobre Base UI (`@base-ui/react`) |
| Ícones | `lucide-react` |
| Backend | Supabase (Postgres + Auth) via `@supabase/ssr` |
| Estado remoto | TanStack Query |
| Gerenciador | pnpm 10 |

## Desenvolvimento

```bash
pnpm install
pnpm dev
```

O app precisa de duas variáveis públicas. Comece pelo exemplo seguro:

```bash
cp .env.example .env.local
```

Chaves secretas ou `service_role` não devem aparecer no navegador nem no repositório.
Todo o `.env*` está no `.gitignore`.

> Essas variáveis são obrigatórias para executar o app: sem elas, o proxy bloqueia as rotas
> protegidas e o login não funciona.

### Scripts

| Comando | O que faz |
| --- | --- |
| `pnpm dev` | servidor de desenvolvimento |
| `pnpm build` | build de produção |
| `pnpm start` | serve o build |
| `pnpm lint` | ESLint |
| `pnpm typecheck` | `tsc --noEmit` |
| `pnpm test` | testes unitários da aplicação com Vitest |
| `pnpm check` | lint + typecheck + testes do app + build |
| `pnpm supabase:push` | aplica `supabase/migrations` no projeto linkado |
| `pnpm supabase:types` | regenera `src/lib/supabase/database.types.ts` |
| `pnpm supabase:test` | executa os testes pgTAP locais de RLS e check-in |

Rode `pnpm check` antes de concluir qualquer alteração. Para validar as políticas e o
check-in, rode também `pnpm supabase:test`. O CI executa os dois gates em cada push para
`main` e em cada pull request; ele usa apenas a instância local do Supabase e nunca faz
push para um projeto remoto.

## Supabase de desenvolvimento

O projeto `webingressos-dev` foi provisionado na organização `proframos`, região
`sa-east-1`, ref `zcvkdgethbhgaownygzs`. Não confundir com o projeto `ragjuridico`, já
existente na conta.

Para vincular o checkout local:

```bash
supabase link --project-ref zcvkdgethbhgaownygzs
pnpm supabase:push
pnpm supabase:types
```

O link pede a senha do banco apenas no prompt do terminal. Ela não vai para o `.env.local`,
para o chat nem para o Git. As migrations deste repositório já foram aplicadas no ambiente
remoto; mudanças de schema entram em migrations novas, nunca editando as existentes.

Regras de migration, RLS e helpers de autorização em [`supabase/README.md`](./supabase/README.md).

## Organização do código

```text
proxy.ts                 # proxy do Next 16: refresh de sessão e proteção de rotas
src/
├── app/                 # rotas App Router
│   ├── (auth)/login/    # login, fora do shell
│   ├── (dashboard)/     # tudo que roda dentro do AppShell
│   └── auth/callback/   # troca do code por sessão
├── components/          # shell, primitivas de UI e componentes compartilhados
├── lib/                 # clientes Supabase, QueryClient e utilidades
└── modules/             # contratos e casos de uso por domínio
    ├── audit/
    ├── events/
    ├── finance/
    ├── identity/
    ├── operations/
    ├── promoters/
    └── sales/
supabase/migrations/     # schema, RLS e funções de autorização
docs/adr/                # decisões de arquitetura
```

Alias de import: `@/*` aponta para `./src/*`.

## Documentação

| Pergunta | Arquivo |
| --- | --- |
| Como os componentes se encaixam | [`ARCHITECTURE.md`](./ARCHITECTURE.md) |
| Como o código está organizado e o que assumir | [`CLAUDE.md`](./CLAUDE.md) |
| Regras de trabalho no repositório | [`AGENTS.md`](./AGENTS.md) |
| Significado dos termos do domínio | [`CONTEXT.md`](./CONTEXT.md) |
| Cor, tipografia, espaçamento e componentes | [`DESIGN.md`](./DESIGN.md) |
| Por que a arquitetura é assim | [`docs/adr/`](./docs/adr/) |
| Migrations e RLS | [`supabase/README.md`](./supabase/README.md) |

## Interface

A interface é light-only, mobile-first e em português-BR. As cores vêm dos tokens de
`src/app/globals.css` — uma única matiz verde mais uma escala de neutros — e não devem ser
escritas como hex cru nos componentes.

O projeto [`satnaing/shadcn-admin`](https://github.com/satnaing/shadcn-admin) é referência
de composição para sidebar, busca e tabelas. Seus componentes não são importados: ele usa
Vite/Radix, este app usa Next.js e Base UI. Os padrões aproveitados continuam subordinados
aos tokens e às decisões de [`DESIGN.md`](./DESIGN.md).

## Primeira fatia vertical

Organização → evento → lote → pedido → ingresso → check-in → lançamento financeiro.

O check-in é online-first, com validação server-side, constraint contra duplicidade e
resposta idempotente (`accepted`, `already_checked_in` ou `invalid`), além de fallback para
digitação manual. Sincronização offline e um cliente nativo Android/iOS são evoluções
posteriores; o scanner deve manter uma fronteira que permita essa extração futura.

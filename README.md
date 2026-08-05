# WebIngressos App

Aplicação operacional da WebIngressos para organizadores e equipes de operação de eventos universitários. Este repositório é separado da landing page comercial em [`webingressos-page`](https://github.com/prof-ramos/webingressos-page).

O produto está sendo construído como um monólito modular: uma aplicação Next.js com fronteiras de domínio claras, Supabase para autenticação e persistência, e uma primeira experiência online-first para operação e check-in.

## Estado atual

Esta é a fundação do produto, não uma versão pronta para produção. O shell visual, os contratos de domínio, a integração SSR com Supabase, as migrations/RLS iniciais e a separação dos módulos estão em place; ainda faltam fluxos de negócio completos e testes de integração.

## Desenvolvimento

```bash
pnpm install
cp .env.example .env.local
pnpm dev
```

Validação local:

```bash
pnpm check
pnpm test
```

O app usa `NEXT_PUBLIC_SUPABASE_URL` e `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`. Chaves secretas ou `service_role` não devem aparecer no navegador, em `.env.example` ou no repositório.

## Supabase de desenvolvimento

O projeto `webingressos-dev` foi provisionado na organização `proframos`, região `sa-east-1`, ref `zcvkdgethbhgaownygzs`. O projeto remoto não deve ser confundido com o projeto `ragjuridico` já existente na conta.

Após redefinir/guardar a senha do banco no painel do Supabase, vincule o checkout local:

```bash
supabase link --project-ref zcvkdgethbhgaownygzs
pnpm supabase:push
pnpm supabase:types
```

O link solicita a senha apenas no terminal. Não coloque a senha em `.env.local`, no chat ou no Git.

## Organização do código

```text
src/
├── app/                 # rotas App Router, auth e dashboard
├── components/          # shell e componentes compartilhados
├── lib/                 # clientes Supabase e utilidades
└── modules/             # contratos e casos de uso por domínio
    ├── audit/
    ├── events/
    ├── finance/
    ├── identity/
    ├── operations/
    ├── promoters/
    └── sales/
```

Os requisitos e critérios de aceite da fundação estão na [`spec do WebIngressos App`](./docs/specs/webingressos-app-foundation.md). As decisões e os termos do domínio estão em [`CONTEXT.md`](./CONTEXT.md) e [`docs/adr/`](./docs/adr/). O snapshot local do design foi derivado do `DESIGN.md` da landing page, que continua sendo a fonte de referência visual compartilhada.

## Referências de interface

O projeto [`satnaing/shadcn-admin`](https://github.com/satnaing/shadcn-admin) é uma referência para composição de dashboards, sidebar responsiva, busca global e tabelas. Seus componentes não são importados diretamente: o projeto usa Vite/Radix, enquanto este app usa Next.js e Base UI. Os padrões aproveitados devem continuar subordinados aos tokens e às decisões de [`DESIGN.md`](./DESIGN.md).

## Primeira fatia vertical

Organização → evento → lote → pedido → ingresso → check-in → lançamento financeiro.

Check-in começa online-first, com validação server-side, prevenção de duplicidade e fallback manual. A sincronização offline e um cliente nativo Android/iOS são evoluções posteriores; o scanner deve manter uma fronteira que permita essa extração futura.

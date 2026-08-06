<!-- BEGIN:nextjs-agent-rules -->
# Regras do app WebIngressos

Leia os guias atuais em `node_modules/next/dist/docs/` quando trabalhar com APIs específicas do Next.js. Consulte Context7 antes de usar ou alterar APIs de bibliotecas, frameworks, SDKs, CLIs ou serviços cloud.
<!-- END:nextjs-agent-rules -->

## Escopo

Este repositório contém o app operacional em `app.webingressos.com.br`. A landing page comercial fica em repositório separado e não deve receber autenticação, checkout, backoffice ou regras operacionais.

## Regras técnicas

- Next.js App Router, TypeScript estrito e Server Components por padrão.
- Supabase Auth usa `@supabase/ssr`, `createServerClient`/`createBrowserClient` e refresh no `proxy.ts`.
- Use `auth.getClaims()` no servidor/proxy; não trate `getSession()` como mecanismo de autorização.
- Toda tabela de negócio precisa de RLS e políticas limitadas por organização/evento.
- Chaves `service_role`/secret ficam apenas no servidor; nunca versionar `.env` real.
- Valores usam centavos inteiros e `timestamptz` UTC.
- Check-in tem validação server-side, constraint contra duplicidade e transação curta.
- Use TanStack Query apenas para estado remoto interativo; leituras simples podem permanecer em Server Components.
- Use os componentes Base UI gerados pelo shadcn e os tokens de `globals.css`; não introduza cores cruas da paleta.

## Produto e design

- Consulte [`CONTEXT.md`](./CONTEXT.md) antes de criar entidades ou renomear conceitos.
- [`DESIGN.md`](./DESIGN.md) é o snapshot local derivado do design canônico da landing page.
- A interface é light-only, mobile-first e em português-BR.
- Não invente dados reais, clientes, resultados ou disponibilidade.

## Qualidade

Antes de concluir uma alteração, execute `pnpm check` e, quando houver UI, verifique viewport móvel/desktop, foco, contraste, estados de carregamento/erro/vazio e navegação por teclado.

`pnpm check` não pega proxy ignorado, fonte não carregada, CSS fora de camada, menu que abre vazio nem controle inacessível por teclado — todos já aconteceram aqui. Verifique no navegador **acionando** cada controle interativo, por mouse e por teclado, e observando `pageerror`. As armadilhas específicas deste repositório estão em [`CLAUDE.md`](./CLAUDE.md#armadilhas-conhecidas).

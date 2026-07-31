# ADR 0004 — shadcn-admin como referência de composição

- Status: aceito
- Data: 2026-07-31

## Contexto

O projeto `satnaing/shadcn-admin` reúne padrões úteis para um backoffice: sidebar responsiva, busca global e tabelas operacionais. Ele usa Vite e Radix, enquanto este app usa Next.js App Router e Base UI.

## Decisão

Usaremos o projeto como referência de composição e comportamento, adaptando as ideias aos componentes já instalados e aos tokens do `DESIGN.md`. Não vamos copiar o conjunto de componentes nem adicionar Radix em paralelo somente para reproduzir sua implementação.

## Consequências

- mantemos uma única camada de primitivas de UI;
- podemos aproveitar padrões maduros sem misturar contratos de framework;
- sidebar, busca e tabelas devem ser adicionadas quando houver fluxo operacional real para sustentar cada uma.

# ADR 0001 — Monólito modular para o app operacional

- Status: aceito
- Data: 2026-07-31

## Contexto

A landing page pública tem ciclo, risco e objetivo diferentes do produto operacional. O produto precisa evoluir eventos, vendas, operação e prestação de contas sem espalhar regras críticas por serviços antes de haver necessidade real.

## Decisão

O app operacional viverá em um repositório separado e será um monólito modular Next.js. Cada módulo mantém linguagem, tipos e casos de uso próprios; a comunicação entre módulos ocorre por contratos explícitos. Route Handlers e Server Actions serão usados nas bordas, com validação server-side.

## Consequências

- deploy e observabilidade começam simples;
- autenticação, autorização e auditoria podem ser aplicadas de modo consistente;
- módulos continuam extraíveis se volume, equipe ou requisitos justificarem;
- não criamos microserviços, filas ou workers como abstração antecipada.

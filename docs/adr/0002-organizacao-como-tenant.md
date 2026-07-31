# ADR 0002 — Organização como tenant primário

- Status: aceito
- Data: 2026-07-31

## Contexto

Atléticas, repúblicas, centros acadêmicos e produtores precisam compartilhar o app com equipes diferentes. Eventos podem envolver colaboração, mas a responsabilidade operacional precisa continuar clara.

## Decisão

`Organização` é o tenant primário. `Evento` pertence a uma organização e pode receber colaboradores com escopo explícito. Todo acesso a dado de negócio deve atravessar membership ou colaboração válida, refletida nas políticas RLS.

## Consequências

- isolamento entre organizações é uma regra de segurança, não apenas de interface;
- convites e colaboração futura podem ser adicionados sem transformar evento em tenant;
- memberships, vínculos de evento e índices de RLS precisam nascer junto com o schema.

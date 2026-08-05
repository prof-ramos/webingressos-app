# Spec — Fundação do WebIngressos App

- **Status:** baseline de desenvolvimento aceita
- **Data:** 2026-08-05
- **Entrega-alvo:** branch `agent/webingressos-app-foundation`, comparada a `main`, incluindo o fechamento TDD preparado no working tree
- **Público:** engenharia, revisão de código, produto e segurança

## 1. Objetivo

Estabelecer a fundação técnica e de domínio do app operacional da WebIngressos. A entrega deve permitir que os próximos fluxos de evento, venda, check-in e prestação de contas sejam construídos sobre limites de autorização, integridade e interface já definidos.

Esta spec é normativa: descreve o comportamento que a fundação deve preservar. A matriz de rastreabilidade registra a evidência disponível na entrega atual, mas não transforma uma implementação acidental em requisito nem substitui validação em ambiente real.

## 2. Limites do sistema

- O repositório contém o app operacional servido em `app.webingressos.com.br`; a landing page comercial permanece em outro repositório.
- O sistema começa como um monólito modular Next.js. Regras de domínio ficam em módulos explícitos e as bordas usam APIs server-side.
- Supabase fornece autenticação e PostgreSQL. Autorização de dados é aplicada no banco por RLS e funções confiáveis, não apenas pela interface.
- A organização é o tenant primário. Um evento pertence a exatamente uma organização, ainda que aceite colaboradores com escopo limitado.
- A primeira fatia vertical é: organização → evento → lote → pedido → ingresso → check-in → lançamento financeiro.

Em caso de conflito, a precedência documental é: esta spec para critérios da entrega; `CONTEXT.md` para linguagem de domínio; ADRs para decisões arquiteturais; `DESIGN.md` para tokens e direção visual; `AGENTS.md` para regras de contribuição.

## 3. Requisitos

### 3.1. Arquitetura e contratos

- **ARCH-01 — Monólito modular.** O app deve usar Next.js App Router e TypeScript estrito, com fronteiras de domínio para identidade, eventos, vendas, operação, promoters, finanças e auditoria.
- **ARCH-02 — Renderização.** Componentes devem ser Server Components por padrão. Estado e APIs de navegador devem ficar em ilhas cliente pequenas e explícitas.
- **ARCH-03 — Estado remoto.** TanStack Query só deve ser introduzido onde existir estado remoto interativo. Leituras simples podem permanecer no servidor e nenhum provider global deve ser carregado sem consumidor real.
- **ARCH-04 — Primitivas visuais.** A interface deve reutilizar Base UI/shadcn e os tokens de `globals.css`, sem introduzir uma segunda biblioteca de primitivas ou cores cruas da paleta.
- **ARCH-05 — Contratos públicos.** URLs, QR codes e integrações devem usar identificadores públicos opacos. IDs internos podem permanecer sequenciais no banco.

### 3.2. Autenticação e navegação

- **AUTH-01 — Rotas públicas.** `/login` e `/auth/*` devem permanecer acessíveis sem sessão.
- **AUTH-02 — Rotas protegidas.** Qualquer outra rota deve exigir claims retornados e validados pelo Supabase para o cookie atual. Sem sessão, o usuário deve ser redirecionado para `/login`, preservando `pathname` e query locais no parâmetro `next`.
- **AUTH-03 — Falha fechada.** Se a configuração pública do Supabase estiver ausente, rotas protegidas devem redirecionar para `/login?error=supabase_not_configured&next=<caminho-local-seguro>`; o app não pode liberar acesso por falha de configuração.
- **AUTH-04 — Autorização no servidor.** Proxy e código server-side devem usar `auth.getClaims()` para decisões de autorização e refresh de cookies via `@supabase/ssr`. `getSession()` não deve ser tratado como prova de autorização.
- **AUTH-05 — Destino seguro.** Login e callback só podem redirecionar para caminhos relativos iniciados por uma única `/` e resolvidos para a mesma origem. Valores absolutos, protocol-relative, malformados ou de outra origem devem cair em `/dashboard`. O valor de `next` preserva caminho, query e fragmento quando fornecido pelo cliente; redirects do proxy preservam caminho e query, pois requisições HTTP não carregam fragmento.
- **AUTH-06 — Estados de autenticação.** Login e logout devem bloquear repetição enquanto pendentes e apresentar erro compreensível e persistente. Uma falha de logout precisa continuar visível depois que o menu da conta fechar.
- **AUTH-07 — Segredos.** Somente URL e chave publicável podem chegar ao navegador. `service_role`, senhas e outros segredos não podem ser versionados nem expostos ao cliente.
- **AUTH-08 — Contrato de entrada.** O login inicial usa e-mail e senha por `signInWithPassword`. `GET /auth/callback` atende fluxos PKCE e recebe `code` obrigatório e `next` opcional. Sucesso troca o código pela sessão e redireciona para o `next` seguro. Código ausente ou troca rejeitada redireciona para `/login?error=auth_callback_failed&next=<caminho-local-seguro>`. A ordem textual dos parâmetros não é contratual. Erros de callback ou configuração devem ser exibidos no login antes da primeira submissão; uma falha da submissão substitui a mensagem vinda da URL. `next` só define o destino após autenticação bem-sucedida e nunca altera a rota de erro nem as regras de AUTH-05.

### 3.3. Tenant, papéis e RLS

- **SEC-01 — RLS obrigatória.** Toda tabela de negócio exposta deve ter RLS habilitada e políticas limitadas por organização e/ou evento.
- **SEC-02 — Papéis da organização.** Os papéis reconhecidos são `owner`, `finance`, `ops` e `gate`. A autorização deve verificar papel, tenant e recurso, não somente uma string de papel.
- **SEC-03 — Propriedade do evento.** `events.organization_id` é imutável e identifica o tenant proprietário.
- **SEC-04 — Colaboração limitada.** Vínculo como colaborador não concede poderes de proprietário nem permite reatribuir o evento. Permissões colaborativas devem ser avaliadas no escopo do evento.
- **SEC-05 — Dados sensíveis.** Pedidos e seus itens só podem ser lidos por perfis operacionais autorizados do evento; o papel `gate` não deve receber PII de compradores por consequência do acesso ao check-in.
- **SEC-06 — Auditoria confiável.** Logs de auditoria são append-only para usuários autenticados. Escritas devem ocorrer por funções e transições confiáveis, com ator, tenant, entidade, ação, instante e motivo quando exigido.

A matriz mínima de autorização é:

Nesta matriz, `owner` significa exclusivamente um membro `owner` da organização registrada em `events.organization_id`.

| Operação | Papéis permitidos |
| --- | --- |
| criar evento, lote, promoter ou pedido; operar pedido e emitir ingresso | `owner`, `ops` |
| alterar lifecycle do evento ou pedido | `owner`, `ops` |
| consultar pedidos e itens | `owner`, `ops`, `finance` |
| consultar ingresso e executar/consultar check-in | `owner`, `ops`, `gate` |
| criar, consultar e transicionar lançamento financeiro | `owner`, `finance` |

`Acesso ao evento` significa ser membro da organização proprietária ou possuir colaboração registrada em `event_organizations`. O vínculo registra a organização externa como `collaborator`; o papel operacional vem de `organization_memberships` nessa organização e pode ser `ops`, `finance` ou `gate`. Um membro `owner` da organização colaboradora não herda nenhum poder no evento por ser owner; acesso adicional exigirá um modelo explícito futuro. Assim, a função de autorização cruza evento, organização colaboradora, membership e papel solicitado pela operação.

### 3.4. Ciclos de vida e integridade comercial

- **LIFE-01 — Evento.** As transições permitidas são `rascunho → planejado|cancelado`, `planejado → vendas_abertas|cancelado`, `vendas_abertas → encerrado|cancelado` e `encerrado → prestacao_contas_fechada`. `cancelado` e `prestacao_contas_fechada` são terminais; cancelamento exige motivo. Transições devem ocorrer por `transition_event_status`, com histórico e auditoria. Sair de `vendas_abertas` deve ser rejeitado enquanto algum item de pedido `confirmed` tiver menos ingressos emitidos que sua quantidade.
- **LIFE-02 — Pedido.** Um pedido nasce `pending`. As transições permitidas são `pending → confirmed|cancelled` e `confirmed → cancelled|refunded`; cancelamento e estorno exigem motivo. `cancelled` e `refunded` são terminais. Cancelar ou estornar um pedido confirmado mantém os ingressos emitidos para auditoria, mas os torna inelegíveis para check-in porque o pedido deixa de estar `confirmed`. Essas transições permanecem permitidas com evento `encerrado` ou `cancelado`, mas são bloqueadas após `prestacao_contas_fechada`. Mudanças devem ocorrer por `transition_order_status`.
- **LIFE-03 — Confirmação do pedido.** Confirmar exige evento em `vendas_abertas`, soma dos itens igual ao total, lotes dentro da janela de venda e capacidade suficiente em número de ingressos por lote. Não existe capacidade global do evento nesta entrega. Pedidos `pending` não reservam capacidade. Para cada lote, o consumo existente soma `quantity` de itens em outros pedidos `confirmed`; o pedido-alvo é excluído dessa soma e sua própria quantidade é adicionada exatamente uma vez. Pedidos `cancelled` ou `refunded` deixam de consumir capacidade. As linhas de evento, lote e pedido relevantes devem ser bloqueadas durante a validação para evitar corrida.
- **LIFE-04 — Itens e lotes.** Itens só podem ser escritos enquanto o pedido estiver `pending`. O evento de um lote é imutável e itens não podem cruzar eventos.
- **LIFE-05 — Ingressos.** A emissão é uma operação posterior e separada da confirmação do pedido, mas precisa ser concluída antes de o evento sair de `vendas_abertas`, conforme LIFE-01. Cada ingresso exige pedido `confirmed`, evento em `vendas_abertas` e vínculo consistente entre evento, pedido, item e lote. A quantidade emitida não pode superar a quantidade do item e o código público deve ser opaco e gerado pelo banco. Cancelamento ou estorno posterior não apaga ingressos; apenas os invalida operacionalmente. Isso não reabre nem invalida retroativamente uma transição de evento já concluída.
- **LIFE-06 — Valores e tempo.** Valores monetários usam centavos inteiros e moeda `BRL`. Instantes persistidos usam `timestamptz` em UTC.

### 3.5. Check-in, finanças e auditoria

- **OPS-01 — Autorização do check-in.** Somente `owner`, `ops` e `gate` com acesso ao evento podem validar um ingresso.
- **OPS-02 — Elegibilidade.** Check-in exige evento em `vendas_abertas`, pedido `confirmed` e ingresso pertencente ao evento informado. O estado atual não aceita novas entradas depois que o evento avança para `encerrado`.
- **OPS-03 — Idempotência.** A primeira validação cria o check-in; repetições retornam `already_checked_in` e não criam uma segunda entrada. A unicidade por ingresso deve existir também no banco.
- **OPS-04 — Resultado estável.** `check_in_ticket` deve distinguir `accepted`, `already_checked_in` e `invalid`. O RPC atual produz exatamente `not_found`, `wrong_event`, `event_not_open` e `order_not_confirmed` como motivos de `invalid`; `cancelled` permanece reservado no tipo de domínio e não é produzido pelo schema atual.
- **FIN-01 — Lançamento financeiro.** Um lançamento nasce `previsto` e só pode avançar `previsto → aprovado → pago` por `transition_ledger_entry_status`, sob papel `owner` ou `finance`.
- **FIN-02 — Fechamento.** Depois de `prestacao_contas_fechada`, nenhum lançamento do evento pode ser inserido ou alterado.
- **FIN-03 — Correções.** Vendas e movimentos financeiros não são apagados para correção; devem usar novos registros ou transições auditáveis.

### 3.6. Interface, acessibilidade e desempenho

- **UI-01 — Direção visual.** A interface é light-only, mobile-first e em português-BR. Dados demonstrativos não podem ser apresentados como clientes ou resultados reais.
- **UI-02 — Shell responsivo.** Navegação desktop e mobile devem compartilhar os mesmos destinos. O menu móvel deve fechar após navegação e continuar operável por teclado.
- **UI-03 — Semântica.** Cada página deve ter heading principal identificável; campos e seletores devem ter nomes acessíveis; o item atual do breadcrumb não deve fingir ser link.
- **UI-04 — Estados.** Fluxos interativos devem contemplar carregamento, erro, vazio e sucesso quando aplicáveis, com foco e mensagens acessíveis.
- **UI-05 — Contraste e foco.** Texto e controles devem atingir WCAG 2.2 AA, preservar foco visível e permitir navegação por teclado. A verificação deve cobrir ao menos um viewport móvel de até 390 px e um desktop de pelo menos 1280 px.
- **UI-06 — Fronteira do bundle.** O shell estrutural deve permanecer Server Component; somente navegação ativa, menu móvel, seletor e conta devem hidratar como ilhas cliente.

### 3.7. Qualidade e verificação

- **QUAL-01 — Check obrigatório.** `pnpm check` deve passar, cobrindo lint, TypeScript e build de produção.
- **QUAL-02 — Proxy real.** O build deve registrar `Proxy (Middleware)`, e testes HTTP devem provar que `/dashboard` é protegido enquanto login e callback são públicos.
- **QUAL-03 — Bundle.** Testes devem impedir a volta de provider global de queries sem uso e a promoção do shell estrutural inteiro a Client Component.
- **QUAL-04 — Acessibilidade pública.** A página de login deve ser verificada em Chromium com heading, campos nomeados e análise axe sem violações nos viewports móvel e desktop definidos em UI-05.
- **QUAL-05 — Banco.** Invariantes de RLS, lifecycle e concorrência exigem testes PostgreSQL/Supabase automatizados antes de a fundação ser considerada pronta para produção.
- **QUAL-06 — Tipos gerados.** Mudanças em migrations ou RPCs devem ser seguidas por `pnpm supabase:types` e revisão do diff gerado.

## 4. Contratos externos preservados

- Variáveis públicas: `NEXT_PUBLIC_SUPABASE_URL` e `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`.
- Rotas públicas: `/login` e `/auth/*`.
- Destino autenticado padrão: `/dashboard`.
- Callback PKCE: `GET /auth/callback?code=<code>&next=<caminho-local>`; falhas usam `error=auth_callback_failed` e configuração ausente usa `error=supabase_not_configured`.
- RPCs de lifecycle: `transition_event_status`, `transition_order_status`, `transition_ledger_entry_status` e `check_in_ticket`.
- Estados de evento: `rascunho`, `planejado`, `vendas_abertas`, `encerrado`, `prestacao_contas_fechada`, `cancelado`.
- Estados de pedido: `pending`, `confirmed`, `cancelled`, `refunded`.
- Estados financeiros: `previsto`, `aprovado`, `pago`.

Qualquer alteração nesses contratos exige atualização desta spec, dos tipos de domínio e, quando aplicável, das migrations e tipos gerados.

## 5. Fora de escopo desta entrega

- versão pronta para produção, rollout, monitoramento e SLOs;
- CRUD e fluxos operacionais completos das áreas exibidas no shell;
- checkout, adquirente, conciliação e pagamentos reais;
- recuperação de senha e gestão completa de perfil;
- scanner offline, sincronização, aplicativo Expo ou cliente nativo;
- mudanças na landing page comercial;
- dados reais de clientes, disponibilidade, resultados ou métricas;
- microserviços, filas e workers sem necessidade operacional comprovada.

## 6. Matriz de rastreabilidade da entrega atual

Os estados abaixo descrevem a evidência disponível em 2026-08-05:

- `Implementado`: comportamento e prova local presentes;
- `Prova parcial`: comportamento presente, mas falta a prova automatizada indicada;
- `Bloqueador`: comportamento normativo conhecido como ausente;
- `Fora de escopo`: não faz parte desta entrega.

| Eixo | Requisitos | Evidência atual | Estado |
| --- | --- | --- | --- |
| Arquitetura | ARCH-01–05 | ADRs, `src/modules`, App Router, tipos de domínio e ausência de provider global sem consumidor | Implementado |
| Autenticação | AUTH-01–08 | `src/proxy.ts`, Supabase SSR, navegação segura, login e menu da conta; testes HTTP dos redirects e Playwright do erro inicial | Prova parcial — falta E2E com uma sessão Supabase real |
| Tenant e RLS | SEC-01–06 | migrations de schema, políticas, funções confiáveis e revogação de escritas diretas | Prova parcial — falta suíte PostgreSQL automatizada |
| Ciclos comerciais | LIFE-01–06 | RPCs, triggers e constraints nas migrations; `20260805120000_foundation_blockers.sql` aplicada no desenvolvimento e quatro provas pgTAP vinculadas | Prova parcial — faltam cenários PostgreSQL concorrentes mais amplos |
| Check-in e finanças | OPS-01–04, FIN-01–03 | `check_in_ticket`, unicidade por ingresso, lifecycle financeiro e guards de fechamento | Prova parcial — falta teste de integração concorrente |
| Interface | UI-01–06 | shell responsivo, fonte canônica de destinos, paridade desktop/mobile protegida por teste, ilhas cliente e Playwright/axe do login | Prova parcial — falta evidência visual autenticada no viewport móvel; rotas operacionais permanecem fora de escopo |
| Qualidade | QUAL-01–06 | `pnpm check`, testes HTTP, bundle, Playwright e pgTAP vinculados; tipos Supabase versionados | Prova parcial — QUAL-05 ainda exige cobertura de RLS e concorrência antes de produção |

## 7. Critério de aceite da fundação

A entrega é aceita como **baseline de desenvolvimento** quando:

1. `pnpm check`, `pnpm test` e `git diff --check` estiverem verdes;
2. o build reconhecer o proxy e as rotas protegidas falharem fechadas;
3. não restar nenhuma linha `Bloqueador` na matriz;
4. o code review não encontrar outra violação concreta desta spec ou das regras do repositório;
5. lacunas de `Prova parcial` permanecerem explicitamente descritas e não forem apresentadas como prontidão de produção.

A promoção para **fundação pronta para produção** exige, no mínimo, testes PostgreSQL das políticas e transições, cenários concorrentes de capacidade/check-in, E2E autenticado e uma spec separada de release readiness com checklist objetivo do ambiente de deploy, observabilidade e rollback. Aplicar migrations ou obter build verde, isoladamente, não satisfaz esse nível.

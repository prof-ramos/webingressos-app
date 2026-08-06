# Auditoria de UX/UI — shell operacional

Levantamento completo da interface existente (login, `AppShell`, visão geral e páginas de
módulo), com o que foi corrigido nesta rodada e o que continua em aberto.

Método: leitura do código, comparação com [`DESIGN.md`](../DESIGN.md) e inspeção do build de
produção em Chromium (1440×1000 e 390×844) medindo estilos computados, ordem de camadas CSS,
alvos de toque e árvore de headings.

---

## 1. Defeitos verificados e corrigidos

### 1.0 O proxy nunca rodava: nenhuma rota estava protegida — **crítico**

Encontrado ao verificar o build: `middleware-manifest.json` vinha com `"middleware": {}` e
`sortedMiddleware: []`. `GET /dashboard` respondia **200** sem Supabase configurado, quando
deveria redirecionar para `/login`.

Causa: `proxy.ts` estava na raiz do repositório. A convenção do Next 16 é "no root do projeto,
**ou dentro de `src` se aplicável**, no mesmo nível de `pages` ou `app`"
(`next/dist/docs/01-app/03-api-reference/03-file-conventions/proxy.md`). Como este projeto usa
`src/app`, o arquivo tinha de ser `src/proxy.ts` — na raiz ele era ignorado em silêncio.

Efeito: todo o shell operacional era publicamente acessível e nenhuma sessão era renovada. O
RLS continuava protegendo os dados no Postgres, mas a barreira de rota não existia.

Correção: `proxy.ts` → `src/proxy.ts`. O build passou a listar `ƒ Proxy (Middleware)` e o
comportamento verificado é:

| Rota | Antes | Depois |
| --- | --- | --- |
| `/dashboard` | 200 | 307 → `/login?next=%2Fdashboard` |
| `/eventos` | 200 | 307 → `/login?next=%2Feventos` |
| `/login` | 200 | 200 |

É também o que dá sentido ao item 1.19: sem o proxy, o `?next=` nunca era produzido.

### 1.1 A fonte do produto nunca era carregada — **crítico**

`globals.css` declarava `--font-sans: "Plus Jakarta Sans"` e `body { font-family: "Plus
Jakarta Sans" }`, mas nada no projeto baixava a fonte: sem `next/font`, sem `<link>`, sem
arquivo local. `document.fonts` vinha vazio e o app inteiro renderizava na sans-serif padrão
do sistema.

Como `DESIGN.md` apoia a identidade em uma única família com tracking apertado, era o maior
desvio visual do sistema.

Correção: `Plus_Jakarta_Sans` via `next/font/google` (variável, 200–800, `display: "swap"`,
subsets `latin` + `latin-ext`), exposta como `--font-plus-jakarta` e consumida por
`--font-sans`. A fonte passa a ser auto-hospedada no build.

> `next/font/google` baixa a fonte em tempo de build — o build passa a exigir acesso a
> `fonts.googleapis.com`. O runtime não depende disso.

### 1.2 Um `*` fora de camada matava estados de foco e de erro — **crítico**

`globals.css` tinha, fora de qualquer `@layer`:

```css
* { border-color: var(--border); }
```

CSS sem camada tem precedência sobre **toda** camada do Tailwind. Consequências medidas no
build antigo:

| Utilitário | Deveria pintar | Pintava |
| --- | --- | --- |
| `focus-visible:border-ring` (input) | `#2f9e68` | `#e9ecf1` |
| `aria-invalid:border-destructive` | `#c8394f` | `#e9ecf1` |
| `border-transparent` (botão preenchido) | transparente | `#e9ecf1` |

Ou seja: nenhum campo mudava a borda ao receber foco, nenhum campo inválido ficava vermelho, e
todo botão primário carregava uma linha cinza de 1px sobre o verde.

Correção: as regras base foram movidas para `@layer base`. Depois da mudança, os valores
computados são `rgb(47,158,104)` no foco, `rgb(200,57,79)` em `aria-invalid` e
`rgba(0,0,0,0)` na borda do botão.

### 1.3 O seletor de organização mostrava o slug

`WorkspaceSelector` renderizava `campus-ledger` na barra lateral e no menu mobile. O
`Select` do Base UI renderiza o **valor** selecionado; o rótulo só aparece quando `items`
descreve a lista. Corrigido com `items` e uma única fonte de verdade para as organizações.

### 1.4 Configurações era inalcançável no mobile

O link `/configuracoes` existia apenas no rodapé da barra lateral `lg:flex`. No sheet mobile
os links eram `/dashboard, /eventos, /ingressos, /check-in, /promoters, /relatorios` — sem
Configurações. Em viewport móvel a rota simplesmente não tinha entrada de navegação.
Corrigido: o mesmo rodapé fixo aparece nos dois contextos.

### 1.5 Affordance falsa no header

O header desktop tinha `Operação ⌄ Campus Ledger` dentro de uma `div` inerte: um chevron que
prometia um menu inexistente, duplicando o seletor que já estava na barra lateral. Virou texto
com separador `/`, sem chevron.

### 1.6 Mobile sem contexto de organização

O rótulo da organização era `hidden … lg:flex`. Num produto mobile-first, a tela pequena não
dizia em qual organização o usuário estava operando. O nome agora aparece ao lado do menu.

### 1.7 "Encerrar sessão" era um item morto

`Perfil`, `Preferências` e `Encerrar sessão` eram `DropdownMenuItem` sem handler. Logout
aparentava funcionar e não fazia nada.

Correção: `POST /auth/sign-out` (route handler que chama `auth.signOut()` e responde 303 para
`/login`, rota já pública no proxy) acionado por um form dentro do menu. `Perfil` e
`Preferências` ficaram `disabled` com rótulo "(em breve)" — honesto em vez de decorativo.

### 1.8 Alvos de toque abaixo do mínimo

Medidos em 390px: abrir menu **32×32**, fechar sheet 28×28, menu da conta 40px de altura. O
controle principal de navegação mobile era o menor da tela.

Agora: abrir menu 44×44, fechar sheet 44×44, menu da conta 44px, itens do dropdown com
`min-h-11`. Os links de navegação já tinham 44px.

### 1.9 Árvore de headings invertida

`CardTitle` renderiza `<div>`. O resultado era um outline onde os títulos de seção não
existiam, mas os itens filhos eram `h3`:

```text
H1 Visão geral · H2 Resumo da operação · H3 Organização e evento · H3 Lotes e pedidos …
```

`CardTitle` ganhou a prop opcional `as` e os títulos de card passaram a `h2`:

```text
H1 Visão geral · H2 Resumo da operação · H2 Próxima fatia de operação
· H3 Organização e evento … · H2 Operação segura por padrão
```

### 1.10 Sem link para pular a navegação

Nenhum "pular para o conteúdo" e `<main>` sem `id`: em toda navegação de teclado era preciso
atravessar a sidebar inteira. Adicionados o link (visível só no foco) e `id="conteudo"`.

### 1.11 Estado ativo não anunciado

Os links de navegação marcavam o item ativo só com cor de fundo — nenhum `aria-current`.
Adicionado `aria-current="page"` na navegação e no link de configurações, mais anel de foco
com token em vez do outline padrão do navegador.

### 1.12 Sem título por rota

Nenhuma página de módulo definia `metadata`, então toda aba do navegador dizia
"WebIngressos | Operação de eventos". Adicionados `generateMetadata` em `[module]` e
`metadata` na visão geral.

### 1.13 Sem estados de carregamento, erro e 404

Não havia `loading.tsx`, `error.tsx` nem `not-found.tsx`. Uma URL de módulo inválida caía no
404 padrão do Next — sem estilo e em inglês. Adicionados:

- `(dashboard)/loading.tsx` — skeletons no formato da página (usa o `Skeleton` que existia e
  nunca havia sido usado), com `role="status"`.
- `(dashboard)/error.tsx` — recuperação com "Tentar novamente".
- `(dashboard)/not-found.tsx` e `app/not-found.tsx` — em português, dentro e fora do shell.

### 1.14 Hover do botão primário clareava

`DESIGN.md` é explícito: o preenchimento primário **escurece** no hover, nunca clareia.
`hover:bg-primary/80` fazia o oposto (e reduzia o contraste com o texto branco). Adicionado o
token `--primary-strong: var(--brand-800)` e o hover passou a `hover:bg-primary-strong` — verificado:
`rgb(10,77,50)`.

### 1.15 E-mail da conta buscado no cliente

`AppShell` chamava `supabase.auth.getUser()` num `useEffect`, exibindo "Conta autenticada"
até a resposta chegar — um round-trip extra e um flash de placeholder em cada carga, contra a
regra de Server Components por padrão. A leitura foi para `(dashboard)/layout.tsx` e desce
como prop.

> Efeito colateral: com Supabase configurado as rotas do dashboard passam a ser dinâmicas
> (leem cookies). Correto para telas autenticadas, que não poderiam ser estáticas de verdade.

### 1.16 Layout e densidade

- **Largura inconsistente:** a visão geral usava `max-w-[1440px]` e as páginas de módulo
  `max-w-3xl` centralizado — a régua do conteúdo saltava ao navegar. Unificadas no container
  do shell; só a prosa e o card mantêm medida legível.
- **Header de seção colidindo no mobile:** "Resumo da operação" e "Dados aparecerão após a
  conexão" dividiam uma linha `justify-between`, quebrando em duas linhas cada. Agora empilham
  abaixo de `sm`.
- **Card esticado:** o grid de duas colunas alongava o card "Operação segura por padrão" até a
  altura do vizinho, deixando um vazio grande. `items-start` resolve.
- **Métricas em coluna única no mobile:** `sm:grid-cols-2` deixava as quatro métricas
  empilhadas abaixo de 640px, empurrando o conteúdo real para fora da tela. Passaram a
  `grid-cols-2` desde o menor viewport.
- **Breadcrumb de um item** na visão geral repetia o `h1`. Removido ali; as páginas de módulo
  passaram a ter um breadcrumb real com link para a visão geral.

### 1.17 CTA desabilitado sem explicação

"Criar evento" era o elemento mais proeminente da tela, estava `disabled`, não recebia foco e
não dizia por quê. Agora tem texto associado por `aria-describedby`: "Disponível quando o
cadastro de eventos for conectado."

### 1.18 Métrica vazia ilegível para leitor de tela

`MetricCard` renderizava `—` fixo, que o leitor de tela não anuncia. Passou a expor
`sr-only "sem dados"`, aceitar `value` e `isLoading` (com `Skeleton`), e o chip de ícone virou
círculo, como manda `rounded.full` em `DESIGN.md`.

### 1.19 Login

- Usava um ícone genérico de ingresso: a tela de entrada não trazia o nome do produto. Agora
  usa o `BrandMark`.
- **`?next=` era ignorado.** O proxy redireciona para `/login?next=<path>`, e o formulário
  mandava sempre para `/dashboard`, perdendo o destino. Agora honra o parâmetro, aceitando só
  caminhos absolutos same-origin.
- Todo erro virava a mesma frase. Credencial inválida e indisponibilidade agora são mensagens
  distintas.
- O erro não estava ligado aos campos: adicionados `aria-describedby`, `aria-invalid` e
  `aria-busy` no envio.
- Removido o texto morto "Recuperação será conectada" — não era controle nem informação.

### 1.20 Higiene de ativos e chrome

- Sem favicon: a aba mostrava o ícone padrão. Adicionado `src/app/icon.svg` com a marca.
- `public/` só continha os SVGs do template do Next (`next.svg`, `vercel.svg`, `file.svg`,
  `globe.svg`, `window.svg`), nenhum referenciado. Removidos.
- Adicionados `viewport.themeColor` e `colorScheme: "light"`, coerentes com o app light-only.

### 1.21 `prefers-reduced-motion` ignorado

Sheet e dropdown animam via `tw-animate-css` sem respeitar a preferência do sistema.
Adicionado o bloco de redução de movimento — também alinhado ao "nada além de 200ms de
transição" de `DESIGN.md`.

### 1.22 O menu da conta quebrava ao abrir — **crítico**

Encontrado ao medir as alturas dos itens de menu (a rodada anterior mediu só controles
fechados). Clicar no avatar lançava `Base UI: MenuGroupContext is missing. Menu group parts
must be used within <Menu.Group> or <Menu.RadioGroup>` e nenhum item era renderizado: o menu
abria vazio.

Causa: `DropdownMenuLabel` mapeia para `Menu.GroupLabel`, que o Base UI exige dentro de
`Menu.Group`, e o rótulo estava solto no topo do conteúdo. O defeito já existia antes desta
auditoria — o menu nunca funcionou. Corrigido envolvendo rótulo e itens em
`DropdownMenuGroup`.

Verificado depois da correção: os três itens renderizam, sem erro de página, e
`POST /auth/sign-out` leva de fato a `/login`.

### 1.25 "Encerrar sessão" só funcionava com o mouse

Apontado na revisão da PR #4 e confirmado por teste: com o `<form>` renderizado **como** o
`DropdownMenuItem`, o foco de teclado caía no próprio form e `Enter` não disparava nada — só
`keydown` e `keyup`, nenhum `click`. Logout era inalcançável por teclado.

Duas coisas eram necessárias:

1. Inverter o aninhamento — o form envolve o item, e o item **é** o `button type="submit"`.
2. Passar `nativeButton` ao `DropdownMenuItem`. O Base UI assume elemento não-nativo por padrão
   e intercepta `Enter`/`Espaço`; sem essa prop ele engolia o envio mesmo com o foco no botão
   certo.

Verificado nos três caminhos de ativação: `Enter`, `Espaço` e mouse levam a `/login`.

### 1.26 Redirecionamento aberto no `?next=`

Também da revisão da PR #4, e confirmado: a validação por prefixo de string deixava passar
`?next=%2F%5Cevil.example`. `searchParams.get` decodifica para `/\evil.example`, que começa com
`/` e não com `//` — mas o parser de URL normaliza a barra invertida e resolve para
`https://evil.example/`. Depois do login, `router.replace` faria a navegação externa.

Corrigido comparando a origem já parseada, como a rota de callback sempre fez. Verificado:

| `?next=` | Decodificado | Destino |
| --- | --- | --- |
| `%2Feventos` | `/eventos` | `/eventos` |
| `%2F%5Cevil.example` | `/\evil.example` | `/dashboard` |
| `%2F%2Fevil.example` | `//evil.example` | `/dashboard` |
| `https%3A%2F%2Fevil.example` | `https://evil.example` | `/dashboard` |

### 1.27 Ajustes menores da revisão

- **Identidade lida com `getClaims`.** O layout usava `auth.getUser()`, que faz uma requisição
  ao serviço de Auth em cada render inicial — o proxy já validou o JWT. `getClaims()` verifica
  o token localmente e o e-mail está em `JwtPayload.email`, então o rótulo deixou de custar uma
  ida à rede e passou a seguir o invariante de `AGENTS.md`.
- **Logout que falha não finge sucesso.** `POST /auth/sign-out` ignorava o erro de `signOut()` e
  redirecionava como se tivesse dado certo, podendo deixar a sessão viva. Agora o erro leva a
  `/login?erro=logout` e a tela avisa que a sessão anterior pode não ter sido encerrada.
- **Erro de login pelo código, não pelo texto.** A comparação era com
  `signInError.message === "Invalid login credentials"`. Passou a usar `signInError.code`, que é
  estável — e o valor correto no `@supabase/auth-js` instalado é `invalid_credentials`, não o
  `invalid_login_credentials` sugerido na revisão.
- **`--primary-strong` referencia `var(--brand-800)`** em vez de repetir `#0a4d32`.
- **Carregamento da métrica anunciado:** `aria-busy` no contêiner e `sr-only` com
  "Carregando {label}", com o `Skeleton` marcado como decorativo.
- **`XIcon` do sheet** ganhou `aria-hidden="true"`, já que o texto `Fechar` nomeia o controle.
- **README** deixou de listar logout como inexistente.

### 1.23 Alturas dos controles fora da escala do design

As primitivas do shadcn nasceram com `h-8` (32px) em botão, input e select trigger — abaixo dos
44px de alvo de toque e longe dos 44/48/56px de `DESIGN.md`. Cada tela corrigia por conta
própria (`h-12` no login, `h-12` no CTA, `h-11` nos cards de erro, `min-h-11` no shell), então
a escala vivia espalhada em `className` em vez de nas variantes.

As variantes passaram a materializar a escala do design:

| Componente | Antes | Depois | Spec de `DESIGN.md` |
| --- | --- | --- | --- |
| `Button` default | 32px, px-2.5, 500 | **44px**, px-5 (20px), 600 | `button-compact` |
| `Button` lg | 36px, px-2.5, 500 | **56px**, px-6 (24px), 1rem/700 | `button-primary` |
| `Button` sm / xs | 28px / 24px | 40px / 32px | (densidade, opt-in) |
| `Button` icon | 32px | **44px** | — |
| `Input` | 32px, px-2.5, fundo transparente | **48px**, px-4 (16px), 1rem, fundo branco | `input` |
| `SelectTrigger` | 32px | **48px** | "mesma altura do campo de texto" |
| Item de menu / select | ~28px | **44px** | (alvo de toque) |

`sm` e `xs` continuam disponíveis para superfícies densas — barras de ferramentas e linhas de
tabela — mas deixaram de ser o padrão, então descer abaixo de 44px agora é uma escolha
explícita.

Com as variantes corretas, os ajustes locais saíram: `h-12`/`h-11`/`min-h-11`/`px-5`/
`font-bold`/`rounded-lg` foram removidos de login, visão geral, `error`, `not-found` e do
`AppShell`. O CTA primário da visão geral e o botão de entrar passaram a `size="lg"`.

Medido no build de produção: campo de e-mail 48px com 16px de padding, 1rem/400 e fundo
`rgb(255,255,255)`; botão Entrar 56px com 24px de padding e 1rem/700; links de navegação,
menu da conta, abrir menu, fechar sheet e itens de menu em 44px; select trigger em 48px.

> `Input` e `SelectTrigger` também passaram de `bg-transparent` para `bg-card`: `DESIGN.md`
> descreve o campo como "white fill, hairline border", e sobre o canvas `#f9fafc` o fundo
> transparente fazia o campo se dissolver na página em vez de ler como objeto sobre ela.

### 1.24 Tokens de raio e sombra repetidos à mão

`rounded-[1.25rem]` e `shadow-[0_2px_12px_rgba(27,39,64,0.03)]` estavam copiados em cinco
lugares, com o valor cru contrariando a regra de usar tokens. Adicionados `--radius-tile`,
`--radius-card`, `--radius-panel`, `--shadow-card`, `--shadow-card-hover` e `--shadow-panel`
ao `@theme`; os usos passaram a `rounded-card` / `shadow-card` / `shadow-panel`.

---

## 2. Em aberto

Itens reais que ficaram fora desta rodada, em ordem de impacto.

### Alto

1. **Nenhuma tela lê dados de negócio.** Métricas, seletor de organização e módulos são
   estáticos. O `MetricCard` já aceita `value`/`isLoading`; falta a leitura via Server
   Component.
2. **Seletor de organização não troca nada.** Hoje é um `Select` decorativo com uma opção. Ou
   passa a trocar o tenant de verdade, ou deve virar rótulo até existir a troca.
3. **Recuperação de senha e convites não existem.** A tela de login não oferece saída para
   quem esqueceu a senha.
4. **Sem verificação automatizada de interface.** Nenhum teste de componente, E2E ou CI. Todos
   os defeitos acima foram encontrados manualmente e podem voltar sem aviso.

### Médio

1. **`Card` usa `ring-1 ring-foreground/10` em vez da hairline `--outline`.** Além disso todo
   card passava `border-border` sem classe de largura, o que não pintava nada.
2. **Sem hover de card.** `DESIGN.md` define o único estado interativo do sistema (subir 2px,
   borda esverdeada, sombra um passo acima). Nenhum card é clicável ainda; vale implementar
   junto com o primeiro card navegável.
3. **`database.types.ts` não está ligado aos clientes.** Não é UI, mas é o que vai garantir que
   as telas de dados não inventem campos.
4. **Sem `.env.example`,** apesar de o README mandar copiá-lo.

### Baixo

1. **Sem página de erro global** (`app/global-error.tsx`) para falhas no layout raiz.
2. **`BrandMark` usa a letra "W"** em vez de um logotipo. Combinar com a landing page.
3. **Contraste de texto ambiente:** `text-ink-500` (#8a92a3) sobre `#f9fafc` fica em ~2.6:1.
   `DESIGN.md` aceita que essa camada seja "ambiente", mas hoje ela carrega informação de
   estado ("Dados aparecerão após a conexão", detalhes das métricas). Ou o texto sobe para
   `ink-600`, ou a informação não deveria estar nele.

---

## 3. Nota sobre a verificação

As medições vieram do build de produção em Chromium headless. Um detalhe a conferir em
aparelho real: a 14px, o Chromium headless deste ambiente colapsa o avanço do espaço da Plus
Jakarta Sans (o mesmo texto em Arial 14px e em Plus Jakarta Sans 16px ou 40px renderiza
normal). Tem cara de rasterização sem hinting em `deviceScaleFactor` 1, não de defeito no
código — mas convém confirmar num dispositivo antes de assumir.

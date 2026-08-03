# Supabase

O projeto de desenvolvimento foi provisionado como `webingressos-dev` na organização `proframos`, região `sa-east-1`, ref `zcvkdgethbhgaownygzs`. As migrations deste diretório já foram aplicadas no ambiente remoto.

## Regras para as migrations

- começar cada migration com `supabase migration new <nome>`;
- usar `bigint generated always as identity` para chaves internas;
- manter um identificador público opaco e único quando a entidade sair do limite interno;
- usar `timestamptz` para instantes e centavos inteiros para valores em BRL;
- criar índices para toda FK e para colunas usadas nos predicados de RLS;
- habilitar RLS em todas as tabelas de negócio;
- escrever políticas com o vínculo da organização/evento e avaliar `auth.uid()` uma vez por consulta;
- manter transações curtas, com ordem de lock consistente; nunca fazer chamada externa durante check-in;
- não usar `service_role` ou chave secreta no browser.

O primeiro conjunto de tabelas deve acompanhar a fatia vertical descrita em [`../CONTEXT.md`](../CONTEXT.md): organização, memberships, evento, lote, pedido, item, ingresso, check-in, lançamento financeiro e auditoria.

## Fluxo de aplicação

```bash
supabase link --project-ref zcvkdgethbhgaownygzs
pnpm supabase:push
pnpm supabase:types
pnpm supabase:test
```

O link requer a senha do banco no prompt local, ou pode reutilizar a credencial nativa salva pelo Supabase CLI. Ela não deve ser versionada.

As credenciais estão sendo mantidas no 1Password, vault `webingressos`, nos itens `Supabase | webingressos-dev` e `Supabase Database Password | webingressos-dev`. A senha do banco foi redefinida no Dashboard e o item não contém valores expostos no repositório.

## Testes locais

Os testes pgTAP em `supabase/tests/database/` validam isolamento entre organizações,
papéis de `gate` e `finance`, além da idempotência do check-in. Execute `pnpm supabase:test`;
o comando usa o banco local do Supabase e não altera o ambiente remoto.

## Ciclo de vida de eventos

O status só muda pela RPC `transition_event(uuid, event_status, text)`, que valida papel
`owner`/`ops`, bloqueia a linha, aplica a matriz e grava o histórico na mesma transação:

| Status atual | Próximos status |
| --- | --- |
| `rascunho` | `planejado`, `cancelado` |
| `planejado` | `vendas_abertas`, `cancelado` |
| `vendas_abertas` | `encerrado`, `cancelado` |
| `encerrado` | `prestacao_contas_fechada`, `cancelado` |
| `prestacao_contas_fechada` | nenhum |
| `cancelado` | nenhum |

Cancelamento e fechamento da prestação exigem motivo. Clientes só podem criar eventos em
`rascunho`; a criação grava o primeiro histórico via trigger confiável. A edição direta
fica limitada aos detalhes `name`, `starts_at` e `ends_at`, sem conceder atualização de
`status`, posse ou organização.

## Auditoria

`audit_logs` é append-only para clientes autenticados: inserts diretos na tabela e a
execução do RPC genérico `record_audit_log` são negados. Operações confiáveis do banco
devem registrar o ator, o instante e o alvo dentro da mesma transação; elas podem usar o
helper interno sem expor uma API que aceite ações arbitrárias do navegador.

## Pedidos e dados do comprador

`orders` não é uma superfície de leitura geral para o papel `authenticated`. A visão
`orders_operational` usa `security_invoker`, respeita o RLS do pedido e omite os campos de
comprador; a tabela base concede a esse papel somente as nove colunas operacionais
necessárias para a view. Detalhes de cliente só podem ser obtidos por
`get_order_customer(uuid)`, que exige papel `owner`, `ops` ou `finance` no evento; `gate`
e outras organizações recebem uma negativa de autorização uniforme.

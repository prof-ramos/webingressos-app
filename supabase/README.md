# Supabase

O projeto de desenvolvimento foi provisionado como `webingressos-dev` na organização `proframos`, região `sa-east-1`, ref `zcvkdgethbhgaownygzs`. As migrations base deste diretório já foram aplicadas no ambiente remoto; migrations novas ficam pendentes até revisão e deploy.

## Regras para as migrations

- começar cada migration com `supabase migration new <nome>`;
- usar `uuid` com geração UUIDv7 como chave primária das entidades de domínio,
  integração e sincronização;
- reservar `bigint generated always as identity` para registros técnicos e estritamente
  internos;
- não tratar UUID como segredo; QR codes usam token antifraude separado;
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

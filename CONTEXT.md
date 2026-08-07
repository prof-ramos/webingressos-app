# Contexto do domínio

Este documento registra a linguagem compartilhada do produto. Os termos abaixo devem ser usados com o mesmo significado em código, telas, decisões e banco.

## Atores e limites

- **Organização**: tenant principal da WebIngressos e responsável operacional pelo evento.
- **Membro**: pessoa com vínculo a uma organização e um papel de acesso.
- **Papel**: `owner`, `finance`, `ops` ou `gate`; permissões devem ser verificadas por organização e recurso, não apenas por uma string de papel.
- **Colaborador do evento**: organização ou pessoa autorizada a participar da operação de um evento sem se tornar dona do tenant.

## Operação do evento

- **Evento**: unidade operacional que pertence a uma organização, tem ciclo de vida, lotes, pedidos e operação de entrada.
- **Lote**: janela comercial de ingressos com capacidade, preço e período próprios.
- **Promoter**: registro operacional vinculado a um evento para atribuição de vendas e comissão; inicialmente não possui login.
- **Check-in**: primeira validação bem-sucedida de um ingresso em um evento. É uma operação idempotente: repetir a leitura não cria uma segunda entrada.

## Comercial e financeiro

- **Pedido**: agregado comercial que registra a entrada de uma compra ou lançamento operacional.
- **Item do pedido**: relação entre um pedido e uma quantidade de ingressos de um lote.
- **Ingresso**: credencial individual, identificável por um código público opaco e validável uma única vez.
- **Lançamento financeiro**: registro imutável do livro operacional de receita, despesa, comissão, divisão ou repasse.
- **Prestação de contas**: etapa de conferência e fechamento dos lançamentos de um evento; não é apenas uma tela de relatório.

## Rastreamento

- **Auditoria**: registro append-only de ações relevantes, com ator, organização, entidade, ação, instante e justificativa quando aplicável.
- **Motivo**: explicação humana exigida em mudanças sensíveis, como cancelamento, estorno manual ou fechamento.

## Regras já decididas

1. O ciclo do evento é `rascunho → planejado → vendas abertas → encerrado → prestação de contas fechada`, com `cancelado` como saída possível antes do fechamento.
2. Vendas e movimentos financeiros não são apagados; correções são novos registros ou transições auditáveis.
3. Valores monetários usam centavos inteiros e moeda explícita (`BRL`); instantes usam UTC.
4. Entidades de domínio, integração e sincronização usam UUIDv7 como chave primária; BIGINT sequencial fica restrito a registros estritamente internos. O UUID do registro não é segredo e o QR Code usa um token antifraude separado.
5. A autorização é sempre limitada por organização e evento, com RLS em todas as tabelas de negócio expostas.

# ADR 0003 — Check-in online-first com fronteira extraível

- Status: aceito
- Data: 2026-07-31

## Contexto

A portaria precisa validar ingressos rapidamente e impedir duplicidades. Offline é importante para eventos com conectividade ruim, mas sincronização correta adiciona conflitos, fila local, reconciliação e uma superfície operacional nova.

## Decisão

O primeiro piloto usa scanner responsivo/PWA online-first, validação server-side, constraint de unicidade, transação curta e fallback de digitação manual. A UI do scanner fica isolada para que uma futura camada Expo/React Native possa reutilizar contratos sem decidir agora por um app nativo.

## Consequências

- o piloto reduz o risco de consistência e de reconciliação;
- uma queda de conexão ainda exige procedimento manual;
- offline, sincronização e empacotamento nativo permanecem evolução explícita, não promessa atual.

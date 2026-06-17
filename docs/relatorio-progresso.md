# Relatório de Progresso — 484 Method

> Gerado em 2026-06-17. Fonte: histórico do git (datas reais) + ações de
> infraestrutura da sessão. Atualize ao fechar marcos relevantes.

**O que é:** app Flutter de treino oral de inglês para brasileiros adultos,
princípio *som-first* (ouvir → repetir → feedback → liberar a escrita →
regravar). Métrica norte: **minutos de prática aprovada**.

**Período coberto:** 11/06 → 17/06/2026 · **19 commits** · 1 desenvolvedor (+ Claude).

---

## Linha do tempo por dia

### 11/06 — Fundação do loop core (2 commits)
- `de01f0a` Loop core validado: microfone no Chrome → Azure Pronunciation Assessment.
- `76f2de8` Lição 1 som-first completa: ouvir → repetir → feedback → Livro Aberto → regravar.

### 12/06 — Currículo + regras de produto (6 commits)
- `5cb3000` Lições 2–4 com desbloqueio progressivo persistido.
- `56399f1` Currículo da Fase 1 completo (10 lições).
- `d30a0eb` Aprovação multicritério — barra pronúncia "aportuguesada" sem exigir perfeição.
- `421a5c7` Onboarding + consentimento LGPD + exclusão de dados.
- `3cf83d3` Analytics local de eventos.
- `c762638` Scripts de execução web (dev hot-reload + release estável).

### 14/06 — Refino pedagógico (4 commits)
- `030e797` Feedback que celebra a melhora entre tentativas.
- `f3c3890` Modo desafio (aprovação próxima da nativa, opcional).
- `4f39ae0` Mapa de sílabas colorido na tela de resultado.
- `1b4701e` Recalibra o modo desafio contra TTS nativo (corrige falso negativo).

### 15/06 — Backend (2 commits)
- `ae6fa5f` Fundação Supabase: backend opcional com espelhamento + fallback local.
- `bb58367` Supabase ativo + ajuste de texto.

### 17/06 — IA, paywall e CI (4 commits + infraestrutura)
- `a014480` Feedback via Claude API plugado na lição (Edge Function + fallback fixo).
- `476dbf6` Gating de paywall com `EntitlementService` (3 lições grátis).
- `b1e2e27` + `1622ffe` Workflow de CI iOS no GitHub Actions.
- `cba92d7` Doc de engatilhamento do TestFlight.

Ações de infraestrutura (sem commit):

| Ação | Resultado |
|------|-----------|
| Confirmação do secret `ANTHROPIC_API_KEY` no Supabase | estava faltando (503) → configurado → validado HTTP 200 |
| Teste da Edge Function `feedback` | feedback real em PT-BR, no tom da marca |
| Verificação do teto de gasto da Anthropic | US$ 5 pré-pago, recarga automática OFF → cap rígido |
| Criação do repo privado no GitHub | geovaneparanayba/484-method |
| Primeiro build iOS na nuvem | verde, 4m46s (analyze + testes + `build ios`) |

> Dias sem commit: 13/06 e 16/06.

---

## Estado atual vs. escopo do MVP

| Item do MVP | Status |
|-------------|--------|
| Auth (Supabase anônima) | Pronto — em produção |
| Fase 1 — 10 lições som-first | Pronto |
| Loop core completo (Azure) | Pronto |
| Feedback PT-BR via Claude API | Pronto — deployado e validado |
| Dashboard (484h) + streak | Pronto |
| Threshold configurável por lição | Pronto |
| Onboarding + LGPD | Pronto |
| Analytics de eventos | Pronto |
| Paywall (RevenueCat real) | Parcial — gating pronto; venda real bloqueada |
| App rodando no iPhone (TestFlight) | Bloqueado |

---

## Único bloqueio real

Tudo que falta depende de **assinar o Apple Developer Program (US$ 99/ano)**.
Sem isso não há build assinado, TestFlight, nem teste real do RevenueCat.
O passo a passo está em [ios-testflight-setup.md](ios-testflight-setup.md).

**Resumo:** o MVP está funcionalmente completo e testável na web; o que resta é
a distribuição iOS, parada apenas pela conta Apple.

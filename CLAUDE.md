# 484 Method — MVP

## Produto
App Flutter (iOS + Android) de treino oral de inglês para brasileiros adultos
falso iniciantes (25–45 anos, "sei mais inglês do que consigo falar").
Princípio inegociável: **primeiro o ouvido, depois a boca, só depois os olhos** —
a escrita nunca aparece antes da primeira tentativa oral do aluno.

Loop core de uma lição (8 etapas):
1. Objetivo (1 frase) → 2. Ouça (áudio sem texto) → 3. Repita (grava de ouvido)
→ 4. Feedback (nota + orientação curta em PT-BR) → 5. Tente de novo (regrava)
→ 6. Livro Aberto (texto, tradução, exemplo) → 7. Regravação final
→ 8. Conclusão (minutos aprovados + próxima atividade)

Métrica norte do produto: **minutos de prática oral APROVADA**, nunca tempo de tela.

## Escopo do MVP (v1)
- ✅ Auth: **Supabase Auth** (decidido e em produção) — sign-in anônimo, cada
  usuário ganha um id estável sem cadastro. Progresso e eventos no Postgres
  com RLS por user_id; degrada para local-only sem credenciais.
- Fase 1 "Inglês que Você Já Conhece": 21 microlições obrigatórias de 5–10
  min, em 4 blocos pedagógicos internos — reconhecimento/confiança, som/
  sílaba forte, palavra/frase, conversa do dia a dia — mais 4 lições BÔNUS
  opcionais (uma por bloco, `Lesson.bonus = true`, palavras/frases mais
  difíceis do mesmo assunto, nunca exigidas para progredir) — 25 lições no
  total (matriz completa em docs/curriculo-fase1.md)
- ✅ Loop core completo: áudio pré-gerado → gravação → Azure Pronunciation
  Assessment → feedback pedagógico em PT-BR → liberação da escrita → regravação
- ✅ Feedback gerado pela Claude API via Edge Function (fallback p/ mensagens
  fixas sem chave/rede) — ver "Regras de produto que viram código".
- ✅ Dashboard com progresso em minutos aprovados (barra das 484h) + streak
  + desafio do dia (lição sorteada por dia entre as liberadas; só local,
  expira ao virar o dia — ver ProgressStore.dailyChallengeLessonId)
- Threshold de aprovação CONFIGURÁVEL por lição (permissivo na Fase 1)
- ✅ Onboarding com promessa + regra som-first + consentimento de gravação de voz
- ✅ Analytics de eventos (conclusão, tentativas, regravação, retenção)
- Paywall (oferta "Beta Fundador" — acesso à Fase 1): gating das lições atrás
  de `EntitlementService` JÁ implementado, fake local na web. 2026-06: todas
  as 25 lições estão grátis (`kFreeLessonCount`) até ter usuários reais e
  monetização ativa — falta a impl real com RevenueCat, bloqueada por conta
  Apple (ver Stack).
- ✅ Desafio de 21 dias (instrumento de validação — mede OUTCOME, não só
  comportamento): estado do cohort é local em `ProgressStore` (`cohortStartDate`,
  `cohortDay` 1-based, `cohortFinalUnlocked` no dia ≥ 21, confiança
  inicial/final 1–5) — não vai no snapshot do progresso (evita migração de
  coluna); as métricas saem como eventos (`cohort_started`, `final_confidence`,
  `before_after_review_completed`, `testimonial_submitted`) na tabela `events`
  (props jsonb). UI: card por estágio na home + pesquisa de confiança
  (`showConfidenceSurvey`) + `CohortReviewScreen` (antes/depois: delta de
  confiança + minutos aprovados + lições + depoimento). O par OBJETIVO
  (gravação de fala aberta baseline/final) está implementado (fatia 2):
  `AudioRecorderService.longForm()` (60s, sem auto-stop por silêncio),
  `CohortRecordingScreen` (prompts do memo, best-effort), upload pro bucket
  privado `cohort-recordings` via `Backend.uploadCohortRecording` + metadados
  em `public.cohort_recordings` (RLS por dono; migração
  `cohort_recordings_storage`). Consentimento AMPLIADO próprio
  (`ProgressStore.hasVoiceStorageConsent` — guardar áudio ≠ processar na hora);
  `deleteRemoteData` apaga Storage+metadados em bloco próprio (não trava o
  delete de progress/events). Política de privacidade atualizada. FALTA: UI
  in-app de rating cego (hoje o avaliador baixa os áudios pelo dashboard do
  Supabase / SQL em `cohort_recordings`; signed URLs exigiriam estender a Edge
  Function `dev-stats`).
- ✅ Teste de willingness-to-pay (fake door): a `PaywallScreen` é um teste de
  preço A/B — cada usuário vê uma variante estável (`lib/services/pricing.dart`,
  `ProgressStore.assignedPriceVariant`) e o funil inteiro vai pra `events` com
  `price_bucket`/`amount_cents` (`paywall_viewed` → `paywall_subscribe_clicked`
  → `paywall_email_captured` c/ e-mail). Hoje NÃO cobra: o CTA captura e-mail
  (lista de Fundadores) pra provar intenção antes de construir cobrança. O Pix
  entra em `PaywallScreen._startCheckout` (seam marcado; `url_launcher` já é
  dep, não precisa de plugin novo). Gatilho: card não-bloqueante na home no
  "momento uau" (`first_before_after_seen`), some quando a pessoa deixa o
  e-mail — não gateia as lições grátis. Métrica que importa: conversão POR
  preço (e-mail/viewed), segmentada por `price_bucket`, entre usuários ativos.

## Fora de escopo (NÃO implementar)
- Fases 2–8, múltiplos sotaques, connected speech, pares mínimos, IPA
- Conversa livre com IA generativa
- Gamificação social, ranking, comunidade, dashboards B2B
- Modo offline completo
- TTS dinâmico em runtime (áudios são PRÉ-GERADOS e servidos por CDN)

## Ambiente de desenvolvimento (restrições reais)
- Máquina: MacBook Pro 2013 Intel, 8 GB RAM, disco apertado — SEM Xcode local
  e SEM dispositivo Android. O dev tem apenas iPhone.
- Iteração diária: **Flutter web no Chrome** (`flutter run -d chrome`) — o
  navegador dá acesso ao microfone, então o loop core é testável na web.
- Toda feature deve funcionar na web durante o desenvolvimento; abstrair o
  que for específico de plataforma (gravação de áudio, por exemplo) atrás de
  uma interface para trocar a implementação entre web e mobile.
- Build Android: toolchain local funciona (`flutter build apk`), sem emulador.
- ⚠️ Ao adicionar QUALQUER plugin novo no pubspec: rodar
  `rm -rf .dart_tool/flutter_build` antes do próximo `flutter run -d chrome`,
  senão o web_plugin_registrant fica desatualizado e o plugin lança
  MissingPluginException em runtime (já causou tela branca duas vezes).
- Build/teste iOS: via CI na nuvem (Codemagic ou GitHub Actions) + TestFlight
  no iPhone do dev. Nunca sugerir instalar Xcode nesta máquina.

## Stack
- Flutter (iOS + Android)
- Azure Speech SDK — Pronunciation Assessment (accuracy, fluency, completeness)
- ElevenLabs — geração dos áudios das lições (offline/build-time, não em runtime)
- **Supabase** — auth (anônima) + progresso + eventos (RLS) + Edge Functions.
  Projeto dedicado `484-method` (ref pwijrjgdbosxamybukhg, sa-east-1).
- Claude API — feedback pedagógico em PT-BR, chamado pela Edge Function
  `feedback` (chave Anthropic como secret `ANTHROPIC_API_KEY`, nunca no
  cliente). Mapeia scores do Azure → mensagem acionável; base em
  docs/feedback-library.md (fallback fixo quando indisponível).
- RevenueCat — assinaturas. ⚠️ `purchases_flutter` NÃO roda na web: a venda
  real só funciona em build iOS/Android e exige Apple Developer Program
  ($99/ano, ainda não adquirido). Por isso o paywall vive atrás de
  `EntitlementService` (interface), com fake local na web e a impl RevenueCat
  prevista para entrar sem tocar a UI quando houver conta Apple + CI iOS.

## Regras de produto que viram código
- Aprovação de tentativa: accuracy como critério principal em palavras;
  completeness/fluency ganham peso em chunks (lições 7–9)
- Feedback nunca diz só "errado" — sempre indica o que tentar corrigir. A
  mensagem fixa aparece na hora e é trocada pela da Claude quando chega; sem
  rede/chave fica a fixa (o app nunca depende da Claude para funcionar)
- Paywall: as 25 lições da Fase 1 são grátis hoje (`kFreeLessonCount`, ver
  Stack) enquanto não há monetização real ativa; o gate volta a valer quando
  RevenueCat entrar. Gating passa SEMPRE pela interface `EntitlementService` —
  nunca checar compra direto da UI
- Lições bônus (`Lesson.bonus`) nunca são pré-requisito de progressão: a
  lição N exige a lição anterior NÃO bônus concluída, não literalmente N-1
  (ver home_screen.dart)
- Tom adulto, direto, encorajador; sem infantilizar, sem prometer fluência
- LGPD: gravação de voz é dado sensível — consentimento explícito antes da
  primeira gravação, política de retenção/exclusão definida, exclusão de conta
  apaga os dados, nunca usar áudio para treinar modelos

## Docs
- docs/curriculo-fase1.md — as 10 lições com palavras, foco e critérios
- docs/feedback-library.md — mensagens de feedback por tipo de erro
- Plano completo: ~/Downloads/484Method_Plano_Projeto_CORRIGIDO.docx

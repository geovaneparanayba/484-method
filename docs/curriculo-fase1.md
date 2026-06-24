# Currículo — Fase 1: "Inglês que Você Já Conhece" (40h)

Fase mais importante do MVP. Objetivo: provar ao aluno que ele já sabe alguma
coisa, reorganizar palavras familiares pelo som correto e criar o hábito
ouvir → repetir → gravar → corrigir → regravar.

**Nunca** chamar esta fase de "Phonics" ou "Sons Críticos" na UI — o nome
comercial é "Inglês que Você Já Conhece".

A fase é organizada em **3 blocos pedagógicos internos** (não são fases
comerciais novas — Fase 1 continua sendo um único módulo/oferta):

1. **Reconhecimento e confiança** — vocabulário familiar, baixa ameaça
   emocional.
2. **Som e sílaba forte** — ritmo, stress e armadilhas de pronúncia
   (palavras parecidas com português, mas com som ou uso diferente).
3. **Da palavra à frase** — chunks, cortesia, pedidos e situações reais do
   dia a dia.

## Escala de dificuldade do banco de palavras (120–300 palavras)

| Nível | Exemplos | Função |
|---|---|---|
| Muito fácil | banana, pizza, taxi, video, menu | Alta familiaridade, baixa ameaça emocional |
| Familiar com stress diferente | hospital, cinema, chocolate, internet, camera | Treinar sílaba forte e ritmo |
| Familiar com som enganoso | business, comfortable, interesting, manager, project | Reduzir pronúncia aportuguesada |
| Familiar com uso diferente | outdoor, notebook, shopping, home office, chips | Explicar uso real quando necessário |

## As 20 microlições (5–10 min cada): 17 obrigatórias + 3 bônus opcionais

Cada bloco termina com uma revisão (obrigatória) e um bônus (`Lesson.bonus =
true`, opcional): mesmo assunto do bloco, palavras/frases mais difíceis. O
bônus nunca é pré-requisito da próxima lição — a progressão pula direto para
ela a partir da revisão anterior.

### Bloco 1 — Reconhecimento e confiança

| # | Tema | Palavras/frases | Foco | Critério de aprovação |
|---|---|---|---|---|
| 1 | Quebrando o gelo | apple, cinema, hotel, internet, pizza | Confiança e familiaridade | Gravar ≥1 vez; regravar após feedback |
| 2 | Palavras do celular | app, online, email, login, video | Inglês digital cotidiano | Accuracy leve + completude |
| 3 | Comida | coffee, burger, sandwich, cake, water | Vocabulário simples e útil | Repetição clara, finalizar a palavra |
| 4 | Viagem | airport, taxi, bus, passport, ticket | Inglês de sobrevivência | Pronúncia + associação com situação |
| 5 | Muito fácil 2 | banana, menu, gym, mall, fashion | Reforço de confiança | Repetição clara |
| 6 | Revisão Bloco 1 | 1 item de cada lição 1–5 | Progresso visível | Minutos aprovados |
| 7 | **Bônus** — Desafio: vocabulário avançado | calendar, celebrity, vegetable, elevator, umbrella | Vocabulário mais longo, mesmo assunto | Accuracy + fonema mínimo (opcional) |

### Bloco 2 — Som e sílaba forte

| # | Tema | Palavras/frases | Foco | Critério de aprovação |
|---|---|---|---|---|
| 8 | Trabalho | meeting, manager, project, office, job | Conexão com carreira | Stress básico e clareza |
| 9 | Ritmo diferente | hospital, chocolate, camera, restaurant, comfortable | Sílaba forte e redução | Repetir com sílaba forte correta (minProsody) |
| 10 | Som enganoso | business, interesting, mouse, delivery, feedback | Reduzir pronúncia aportuguesada | Accuracy + fonema mínimo |
| 11 | Uso diferente | outdoor, notebook, shopping, home office, chips | Significado real no inglês | Accuracy + compreensão do uso |
| 12 | Revisão Bloco 2 | 1 item de cada lição 8–11 | Progresso visível | Minutos aprovados |
| 13 | **Bônus** — Desafio: ritmo avançado | necessary, temperature, government, photography, vocabulary | Sílaba forte traiçoeira, palavras longas | minProsody (opcional) |

### Bloco 3 — Da palavra à frase

| # | Tema | Palavras/frases | Foco | Critério de aprovação |
|---|---|---|---|---|
| 14 | Primeiros chunks | I like it, I need it, I want this, I love it, I got it | Da palavra isolada à frase curta | Completeness + fluency |
| 15 | Frases de cortesia | Thank you, See you, Excuse me, It's okay, No problem | Comunicação imediata | Completeness + fluency |
| 16 | Pequenos pedidos | Can I have a coffee, I need help, One coffee please, Can you help me, Just a minute | Fala funcional | Completeness + fluency |
| 17 | Casa e lazer | closet, freezer, playground, babysitter, happy hour | Vocabulário doméstico e social | Accuracy + completude |
| 18 | Compras e dinheiro | cash, credit card, discount, voucher, cashback | Inglês prático de consumo | Accuracy + completude |
| 19 | Revisão final | 1 item de cada lição 14–18 | Fecha o básico, evolução visível | Minutos aprovados, evolução visível |
| 20 | **Bônus** — Desafio: pedidos mais longos | Could you help me please, I'd like to order a coffee, Do you have a discount, Where is the restroom, Can I get a receipt | Pedidos educados mais longos | Completeness + fluency (opcional) |

## Regra de liberação da escrita
Uma tentativa oral é obrigatória antes de qualquer texto. Após a tentativa e
o feedback inicial, o app libera a escrita (Livro Aberto: palavra/frase,
tradução, fonética simplificada, exemplo) para evitar frustração. A aprovação
final exige nova gravação com critério mínimo.

## O que NÃO fazer na Fase 1
Não usar TH, pares mínimos difíceis, IPA complexo, explicações longas de
fonética ou frases extensas. Tudo isso é de fases posteriores (fora do MVP).

## Métricas de sucesso do MVP
- Conclusão da 1ª lição ≥ 60% · Retenção D1 ≥ 35% · D7 ≥ 20% (beta)
- Tentativas médias por item: 2–5 · Sessão média: 5–15 min
- Percentual de regravação ≥ 50% (valida se o feedback gera ação)

# Biblioteca de feedback (PT-BR)

O feedback transforma erro em ação. Nunca dizer só "errado" — sempre indicar
o que tentar na próxima gravação. Tom adulto, direto e encorajador.

Pipeline: resultado do Azure Pronunciation Assessment (accuracy, fluency,
completeness, erros por fonema/palavra) → classificar tipo de erro →
mensagem da biblioteca (ou Claude API para variações, mantendo o mesmo tom).

## Mensagens base por tipo de erro

| Tipo de erro | Mensagem |
|---|---|
| Sílaba forte errada | Você colocou força no final. Tente deixar a força no começo da palavra. |
| H inicial | Comece com ar saindo da boca, como uma respiração leve. |
| Vogal longa/curta | Esse som precisa ser um pouco mais longo. Escute e copie a duração. |
| Consoante final sumiu | Não deixe a última consoante desaparecer. Termine a palavra com clareza. |
| Ritmo aportuguesado | Copie o ritmo do áudio, não a escrita da palavra. |
| Boa tentativa | Muito bom. Agora tente repetir com o mesmo ritmo do áudio. |

## Métricas do Azure e uso

| Métrica | Uso |
|---|---|
| Accuracy | Critério principal para palavras e frases curtas |
| Fluency | Mais relevante em chunks e frases (lições 7–9) |
| Completeness | Evita que o aluno pule palavras |
| Prosody | Usar com cautela; não bloquear aprovação por prosody na Fase 1 |

## Threshold
Configurável por lição, nunca hardcoded. Fase 1 começa permissiva (gerar
vitória, não frustração) e o critério sobe gradualmente. Testar com vozes
brasileiras reais antes de confiar no score.

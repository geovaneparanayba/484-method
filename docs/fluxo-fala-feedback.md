# Fluxo: do "ouvir" até o feedback (loop core de um item)

Sequência de uma palavra no loop som-first. Duas viagens de rede (Azure e
Claude), nenhuma chave no cliente. O feedback fixo aparece na hora; o da Claude
substitui quando chega (≤6s, com fallback pra fixa em qualquer falha).

Referências no código: [`lesson_screen.dart`](../lib/screens/lesson_screen.dart),
[`audio_recorder_service.dart`](../lib/services/audio_recorder_service.dart),
[`backend_assessor.dart`](../lib/services/backend_assessor.dart),
Edge Functions [`assess`](../supabase/functions/assess/index.ts) e
[`feedback`](../supabase/functions/feedback/index.ts),
critério em [`lesson.dart`](../lib/models/lesson.dart).

```mermaid
sequenceDiagram
    actor Aluno
    participant App as App (Flutter)
    participant Azure as Azure (Edge: assess)
    participant Claude as Claude (Edge: feedback)

    Aluno->>App: 1. Toca "Ouvir"
    App-->>Aluno: 2. Áudio pré-gerado (sem texto)
    Aluno->>App: 3. Grava (repete de ouvido)
    Note over App: 4. Normaliza PCM → WAV 16 kHz mono<br/>(detecta float32/estéreo do navegador)
    App->>Azure: 5. WAV (chave Azure no servidor)
    Azure-->>App: 6. Scores: accuracy, prosódia, fonema
    Note over App: 7. Aprova? (accuracy + fonema mínimo + prosódia)
    App-->>Aluno: 8. Nota + feedback FIXO (instantâneo)
    App->>Claude: 9. Scores → Claude Haiku (+ cap diário)
    Claude-->>App: 10. Feedback PT-BR acionável (≤6s)
    App-->>Aluno: 11. Substitui pelo feedback da Claude
    App-->>Aluno: 12. Livro Aberto (texto/IPA) → regravação final
    Note over Aluno,App: 13. Antes/depois + "Momento Uau"<br/>→ minutos aprovados → próxima palavra/lição
```

## Passos que mais importam
- **Som-first:** a escrita (passo 12, Livro Aberto) só aparece **depois** da 1ª
  tentativa oral.
- **Normalização (4):** o navegador ignora o formato pedido e entrega float32 na
  taxa nativa (ex.: 44,1 kHz), às vezes estéreo; o app detecta e reamostra pra
  16 kHz mono — o que o Azure exige.
- **Corte de custo:** gravação só-silêncio retorna null e **não** chama o Azure.
- **Aprovação (7):** não usa PronScore (infla e não separa sotaque); usa
  accuracy + piso por fonema + prosódia (nas lições de ritmo).
- **Feedback resiliente:** fixo na hora, Claude quando chega; o app nunca
  depende da Claude pra funcionar.

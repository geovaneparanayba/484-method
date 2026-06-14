import '../models/lesson.dart';
import 'pronunciation_assessor.dart';

/// Feedback curto e acionável em PT-BR (docs/feedback-library.md).
/// Regra de produto: nunca dizer só "errado" — sempre indicar o que tentar.
/// Nesta fase as mensagens são fixas; depois a Claude API gera variações.
String feedbackFor(PronunciationResult r, Lesson lesson,
    {bool rigorous = false}) {
  if (lesson.approves(r.accuracy, r.minPhoneme, r.prosody,
      rigorous: rigorous)) {
    if (r.accuracy >= 95) {
      return 'Perfeito! Som limpo, do jeito nativo. Pode repetir pra fixar.';
    }
    if (r.accuracy >= 85) {
      return 'Muito bom! Tente mais uma vez com o mesmo ritmo do áudio.';
    }
    return 'Boa! Passou no critério. Mais uma tentativa deixa ainda melhor.';
  }
  if (r.completeness < 100) {
    return 'Faltou um pedaço — fale a palavra inteira, até o fim.';
  }
  // Um som específico de português escapou: aponta o trecho exato.
  final phonemeFloor =
      rigorous ? Lesson.rigorousPhoneme : lesson.minPhoneme;
  final worst = r.worstSyllable;
  if (r.minPhoneme < phonemeFloor &&
      worst != null &&
      worst.grapheme.isNotEmpty) {
    return 'Quase! O trecho "${worst.grapheme}" saiu com som de português. '
        'Escute de novo prestando atenção nesse pedaço.';
  }
  // Prosódia: piso da lição (modo normal) ou o do desafio (modo rigoroso).
  final prosodyFloor = rigorous ? Lesson.rigorousProsody : lesson.minProsody;
  if (prosodyFloor != null && (r.prosody ?? 100) < prosodyFloor) {
    return 'O som está bom, mas o ritmo ficou diferente — ouça onde está '
        'a força da palavra e copie a música, não as letras.';
  }
  if (r.accuracy < 60) {
    return 'Copie o ritmo do áudio, não a escrita da palavra. '
        'Escute de novo e tente outra vez.';
  }
  return 'Quase lá. Escute mais uma vez e copie a duração dos sons.';
}

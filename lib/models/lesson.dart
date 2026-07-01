/// Modelo das microlições da Fase 1.
///
/// O threshold de aprovação é POR LIÇÃO (regra de produto: configurável,
/// permissivo no começo da Fase 1 e subindo gradualmente).
class Lesson {
  const Lesson({
    required this.id,
    required this.title,
    required this.objective,
    required this.microSkill,
    required this.approvalThreshold,
    required this.items,
    this.minPhoneme = 65,
    this.minProsody,
    this.bonus = false,
  });

  final String id;
  final String title;

  /// Micro-habilidade trabalhada nesta lição (a coluna "Foco" de
  /// docs/curriculo-fase1.md), em poucas palavras — usada na dashboard
  /// (#9 "próxima melhor ação") pra dizer exatamente o que a pessoa vai
  /// treinar, em vez de só "treinar a lição X".
  final String microSkill;

  /// Lição opcional: não é exigida para desbloquear a próxima lição do
  /// currículo principal. Mesmo bloco e assunto, mas com palavras/frases
  /// mais difíceis — para quem quer ir além do básico.
  final bool bonus;

  /// Explicado ao aluno em uma frase no início (etapa 1 do template).
  final String objective;

  /// Accuracy mínima (0-100) para aprovar a tentativa.
  ///
  /// A aprovação NÃO usa o PronScore: ele é inflado por fluency e
  /// completeness (fáceis de gabaritar em palavra curta) e mal distingue
  /// pronúncia aportuguesada de nativa — medido em 2026-06: "hotel"
  /// aportuguesado dá PronScore 85.6 vs 93.6 nativo.
  final double approvalThreshold;

  /// Piso por fonema: nenhum som individual pode ficar abaixo disso.
  /// É o critério que pega o som de português ("chocolate" aportuguesado
  /// tem accuracy média 72, mas um fonema em 38).
  final double minPhoneme;

  /// Prosódia mínima (stress/ritmo), para lições de ritmo. Null = não exige.
  final double? minProsody;

  final List<LessonItem> items;

  /// Pisos do "modo desafio", calibrados contra TTS nativo (medições de
  /// 2026-06): o nativo tira accuracy 94-100, fonema mínimo 78-100 (vogais
  /// fracas baixam até 78 mesmo no nativo) e prosódia 84-88; o mesmo texto
  /// com sotaque pt-BR cai para accuracy 72-96 e prosódia 66-82.
  ///
  /// A prosódia (stress/ritmo) é a alavanca que separa sotaque de nativo em
  /// palavras-armadilha como "hotel", onde a accuracy do sotaque empata com
  /// a do nativo. O piso de fonema fica em 78 — subir mais reprovaria a
  /// vogal fraca do "banana" nativo (falso negativo).
  static const rigorousAccuracy = 90.0;
  static const rigorousPhoneme = 78.0;
  static const rigorousProsody = 80.0;

  bool approves(double accuracy, double minPhonemeScore, double? prosody,
      {bool rigorous = false}) {
    final accFloor = rigorous ? rigorousAccuracy : approvalThreshold;
    final phonFloor = rigorous ? rigorousPhoneme : minPhoneme;
    if (accuracy < accFloor) return false;
    if (minPhonemeScore < phonFloor) return false;
    // No modo rigoroso a prosódia entra mesmo nas lições sem minProsody.
    final prosFloor = rigorous ? rigorousProsody : minProsody;
    if (prosFloor != null && (prosody ?? 100) < prosFloor) return false;
    return true;
  }
}

class LessonItem {
  const LessonItem({
    required this.text,
    required this.translation,
    required this.example,
    required this.exampleTranslation,
    required this.audioAsset,
    this.ipa,
    this.phonetic,
  });

  /// Palavra ou chunk em inglês — é o ReferenceText da avaliação.
  final String text;
  final String translation;
  final String example;
  final String exampleTranslation;

  /// Caminho do MP3 pré-gerado (relativo a assets/, como o audioplayers usa).
  final String audioAsset;

  /// Fonética em IPA (inglês americano), ex.: /bəˈnænə/. Mostrada no Livro
  /// Aberto (depois da 1ª tentativa oral), nunca antes.
  final String? ipa;

  /// Fonética simplificada em PT-BR, sílaba forte em MAIÚSCULA (ex.: ba-NÉ-na).
  /// Apoio para quem não lê IPA — o público falso-iniciante da Fase 1.
  final String? phonetic;
}

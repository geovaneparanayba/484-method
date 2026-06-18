import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Avalia a pronúncia de um áudio contra um texto de referência.
///
/// Interface separada da implementação Azure para que testes usem um fake
/// e para que a troca de fornecedor (ou a migração da chamada para um
/// backend próprio) não toque o resto do app.
abstract interface class PronunciationAssessor {
  Future<PronunciationResult> assess({
    required Uint8List wavAudio,
    required String referenceText,
  });
}

class PronunciationResult {
  const PronunciationResult({
    required this.accuracy,
    required this.fluency,
    required this.completeness,
    required this.pronScore,
    required this.recognizedText,
    required this.words,
    this.prosody,
  });

  /// Escalas 0-100 do Azure Pronunciation Assessment.
  final double accuracy;
  final double fluency;
  final double completeness;
  final double pronScore;

  /// Stress, entonação e ritmo — o detector de "som aportuguesado com
  /// sílaba forte errada". Null se o serviço não retornar.
  final double? prosody;

  final String recognizedText;
  final List<WordScore> words;

  /// O fonema mais fraco de toda a tentativa. O PronScore médio esconde um
  /// som errado isolado (ex.: "chocolate" aportuguesado tem média 85 com um
  /// fonema em 38); o mínimo é o que pega pronúncia de português.
  double get minPhoneme {
    var min = 100.0;
    for (final w in words) {
      for (final p in w.phonemes) {
        if (p < min) min = p;
      }
    }
    return min;
  }

  /// A sílaba mais fraca (para feedback acionável: "o trecho 'cho'...").
  SyllableScore? get worstSyllable {
    SyllableScore? worst;
    for (final w in words) {
      for (final s in w.syllables) {
        if (worst == null || s.accuracy < worst.accuracy) worst = s;
      }
    }
    return worst;
  }
}

class WordScore {
  const WordScore({
    required this.word,
    required this.accuracy,
    this.errorType,
    this.syllables = const [],
    this.phonemes = const [],
  });

  final String word;
  final double accuracy;

  /// Ex.: "Mispronunciation", "Omission". Null quando não há erro.
  final String? errorType;

  final List<SyllableScore> syllables;

  /// Accuracy de cada fonema, na ordem falada.
  final List<double> phonemes;
}

class SyllableScore {
  const SyllableScore({required this.grapheme, required this.accuracy});

  /// O trecho escrito correspondente (ex.: "cho" em chocolate) — é o que
  /// faz sentido mostrar ao aluno.
  final String grapheme;
  final double accuracy;
}

class PronunciationAssessmentException implements Exception {
  PronunciationAssessmentException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Cliente do Azure Speech (REST, short audio).
///
/// A chave vive no cliente apenas nesta fase de protótipo/dev. Antes de
/// qualquer build distribuída a chamada migra para um backend, senão a
/// chave vaza com o app.
class AzurePronunciationAssessor implements PronunciationAssessor {
  AzurePronunciationAssessor({
    required this.subscriptionKey,
    required this.region,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String subscriptionKey;
  final String region;
  final http.Client _client;

  @override
  Future<PronunciationResult> assess({
    required Uint8List wavAudio,
    required String referenceText,
  }) async {
    final uri = Uri.https(
      '$region.stt.speech.microsoft.com',
      '/speech/recognition/conversation/cognitiveservices/v1',
      {'language': 'en-US', 'format': 'detailed'},
    );
    final assessmentParams = base64.encode(utf8.encode(jsonEncode({
      'ReferenceText': referenceText,
      // Atenção: o valor aceito é "HundredMark" ("HundredPoint" causa 400).
      'GradingSystem': 'HundredMark',
      'Granularity': 'Phoneme',
      'Dimension': 'Comprehensive',
      'EnableProsodyAssessment': 'True',
    })));

    final response = await _client.post(
      uri,
      headers: {
        'Ocp-Apim-Subscription-Key': subscriptionKey,
        'Content-Type': 'audio/wav; codecs=audio/pcm; samplerate=16000',
        'Pronunciation-Assessment': assessmentParams,
        'Accept': 'application/json',
      },
      body: wavAudio,
    );

    if (response.statusCode != 200) {
      throw PronunciationAssessmentException(
        'Azure respondeu ${response.statusCode}: ${response.body}',
      );
    }

    return parseAzureResponse(
        jsonDecode(response.body) as Map<String, dynamic>);
  }
}

/// Converte o JSON detalhado do Azure (REST short-audio) em
/// [PronunciationResult]. Compartilhado pela chamada direta (dev) e pela via
/// backend (Edge Function), que retorna o mesmo corpo do Azure.
PronunciationResult parseAzureResponse(Map<String, dynamic> json) {
  if (json['RecognitionStatus'] != 'Success') {
    throw PronunciationAssessmentException(
      'Fala não reconhecida (${json['RecognitionStatus']}). '
      'Tente de novo mais perto do microfone.',
    );
  }

  // No REST short-audio os scores vêm direto no item do NBest (não dentro
  // de um objeto "PronunciationAssessment" como no Speech SDK).
  final best = (json['NBest'] as List).first as Map<String, dynamic>;
  final words = (best['Words'] as List? ?? []).map((w) {
    final word = w as Map<String, dynamic>;
    return WordScore(
      word: word['Word'] as String,
      accuracy: (word['AccuracyScore'] as num?)?.toDouble() ?? 0,
      errorType:
          word['ErrorType'] == 'None' ? null : word['ErrorType'] as String?,
      syllables: (word['Syllables'] as List? ?? [])
          .map((s) => SyllableScore(
                grapheme: (s['Grapheme'] ?? s['Syllable'] ?? '') as String,
                accuracy: (s['AccuracyScore'] as num?)?.toDouble() ?? 0,
              ))
          .toList(),
      phonemes: (word['Phonemes'] as List? ?? [])
          .map((p) => (p['AccuracyScore'] as num?)?.toDouble() ?? 0)
          .toList(),
    );
  }).toList();

  return PronunciationResult(
    accuracy: (best['AccuracyScore'] as num).toDouble(),
    fluency: (best['FluencyScore'] as num).toDouble(),
    completeness: (best['CompletenessScore'] as num).toDouble(),
    pronScore: (best['PronScore'] as num).toDouble(),
    prosody: (best['ProsodyScore'] as num?)?.toDouble(),
    recognizedText: best['Display'] as String? ?? '',
    words: words,
  );
}

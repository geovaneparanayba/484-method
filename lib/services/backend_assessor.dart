import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'backend.dart';
import 'pronunciation_assessor.dart';

/// Avalia a pronúncia via Edge Function `assess` (proxy do Azure no backend).
/// A chave do Azure fica como secret do Supabase — nunca no cliente, então a
/// build web pública não vaza nada. O áudio vai em base64 num JSON; a resposta
/// é o mesmo corpo do Azure, parseado por [parseAzureResponse].
class BackendPronunciationAssessor implements PronunciationAssessor {
  BackendPronunciationAssessor(this._backend);

  final Backend _backend;

  @override
  Future<PronunciationResult> assess({
    required Uint8List wavAudio,
    required String referenceText,
  }) async {
    try {
      final res = await _backend.client.functions.invoke(
        'assess',
        body: {
          'referenceText': referenceText,
          'audioBase64': base64.encode(wavAudio),
        },
      );
      if (res.status != 200) {
        throw PronunciationAssessmentException(
          'Não consegui avaliar agora (código ${res.status}).',
        );
      }
      final data = res.data;
      final json = data is Map<String, dynamic>
          ? data
          : jsonDecode(data as String) as Map<String, dynamic>;
      return parseAzureResponse(json);
    } on PronunciationAssessmentException {
      rethrow;
    } catch (e) {
      debugPrint('[assessor] falha na Edge Function assess: $e');
      throw PronunciationAssessmentException(
        'Não consegui avaliar sua gravação agora. '
        'Confira sua conexão e tente de novo.',
      );
    }
  }
}

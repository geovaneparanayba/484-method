import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:method484/main.dart';
import 'package:method484/screens/practice_screen.dart';
import 'package:method484/services/pronunciation_assessor.dart';

class _FakeAssessor implements PronunciationAssessor {
  @override
  Future<PronunciationResult> assess({
    required Uint8List wavAudio,
    required String referenceText,
  }) async {
    return const PronunciationResult(
      accuracy: 90,
      fluency: 85,
      completeness: 100,
      pronScore: 88,
      recognizedText: 'banana',
      words: [WordScore(word: 'banana', accuracy: 90)],
    );
  }
}

void main() {
  testWidgets('sem chave configurada, mostra instruções de setup',
      (tester) async {
    await tester.pumpWidget(const Method484App());
    expect(find.textContaining('Chave do Azure'), findsOneWidget);
  });

  testWidgets('tela de prática mostra palavra-alvo e botão de gravar',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: PracticeScreen(assessor: _FakeAssessor()),
    ));
    expect(find.text('apple'), findsOneWidget);
    expect(find.text('Gravar'), findsOneWidget);
    expect(find.textContaining('Áudio enviado ao Azure'), findsOneWidget);
  });
}

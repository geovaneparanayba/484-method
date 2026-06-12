import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:method484/data/fase1.dart';
import 'package:method484/main.dart';
import 'package:method484/screens/lesson_screen.dart';
import 'package:method484/screens/practice_screen.dart';
import 'package:method484/services/progress_store.dart';
import 'package:method484/services/pronunciation_assessor.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

Future<ProgressStore> _emptyStore() async {
  SharedPreferences.setMockInitialValues({});
  return ProgressStore.load();
}

void main() {
  testWidgets('sem chave configurada, mostra instruções de setup',
      (tester) async {
    await tester.pumpWidget(Method484App(store: await _emptyStore()));
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

  testWidgets('lição começa pela introdução e não mostra a palavra antes',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: LessonScreen(lesson: licao01, assessor: _FakeAssessor()),
    ));
    expect(find.textContaining('Regra do jogo'), findsOneWidget);
    await tester.tap(find.text('Começar'));
    await tester.pump();
    // Etapa "ouça": a palavra não pode estar escrita em lugar nenhum.
    expect(find.text('banana'), findsNothing);
    expect(find.text('Ouvir'), findsOneWidget);
  });

  test('conclusão de lição persiste e não duplica', () async {
    final store = await _emptyStore();
    expect(store.isLessonCompleted('fase1-licao01'), isFalse);
    await store.markLessonCompleted('fase1-licao01');
    await store.markLessonCompleted('fase1-licao01');
    expect(store.isLessonCompleted('fase1-licao01'), isTrue);
    expect(store.isLessonCompleted('fase1-licao02'), isFalse);
  });

  test('progresso acumula e streak conta uma vez por dia', () async {
    final store = await _emptyStore();
    expect(store.streakDays, 0);

    await store.addApproved(const Duration(seconds: 10));
    expect(store.totalApproved.inSeconds, 10);
    expect(store.streakDays, 1);

    // Segunda prática no mesmo dia: soma tempo, não soma streak.
    await store.addApproved(const Duration(seconds: 5));
    expect(store.totalApproved.inSeconds, 15);
    expect(store.streakDays, 1);
  });
}

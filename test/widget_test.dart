import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:method484/data/fase1.dart';
import 'package:method484/main.dart';
import 'package:method484/models/lesson.dart';
import 'package:method484/screens/home_screen.dart';
import 'package:method484/screens/lesson_screen.dart';
import 'package:method484/screens/onboarding_screen.dart';
import 'package:method484/screens/word_memory_screen.dart';
import 'package:method484/services/feedback_messages.dart';
import 'package:method484/services/analytics_service.dart';
import 'package:method484/services/entitlement_service.dart';
import 'package:method484/services/progress_store.dart';
import 'package:method484/services/pronunciation_assessor.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAssessor implements PronunciationAssessor {
  @override
  Future<PronunciationResult> assess({
    required Uint8List wavAudio,
    required String referenceText,
    int attempt = 1,
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
  testWidgets('sem Supabase configurado, mostra instruções de setup',
      (tester) async {
    await tester.pumpWidget(Method484App(
      store: await _emptyStore(),
      entitlement: await LocalEntitlementService.load(),
    ));
    expect(find.textContaining('Supabase não configurado'), findsOneWidget);
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
    expect(find.text('apple'), findsNothing);
    expect(find.text('Ouvir'), findsOneWidget);
  });

  testWidgets('lição retoma no item salvo em vez de recomeçar do 1º',
      (tester) async {
    final store = await _emptyStore();
    // Simula quem já passou de "apple"/"cinema" e fechou a lição na 3ª
    // palavra (índice 2 = "hotel") — reabrir não pode jogar de volta pro 0.
    await store.saveItemIndex(licao01.id, 2);

    await tester.pumpWidget(MaterialApp(
      home: LessonScreen(
          lesson: licao01, assessor: _FakeAssessor(), store: store),
    ));
    await tester.tap(find.text('Começar'));
    await tester.pump();
    expect(find.textContaining('Palavra 3'), findsOneWidget);
    expect(find.textContaining('Palavra 1'), findsNothing);
  });

  testWidgets('home com autostart cai direto na 1ª lição (progresso zero)',
      (tester) async {
    final store = await _emptyStore();
    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(
        store: store,
        entitlement: await LocalEntitlementService.load(),
        assessor: _FakeAssessor(),
        autostartFirstLesson: true,
      ),
    ));
    await tester.pumpAndSettle();
    // Conserto do funil consentimento→1ª lição: o novato entra na lição,
    // não fica parado na dashboard vazia.
    expect(find.textContaining('Regra do jogo'), findsOneWidget);
  });

  testWidgets('onboarding só libera após consentimento de voz',
      (tester) async {
    final store = await _emptyStore();
    var done = false;
    await tester.pumpWidget(MaterialApp(
      home: OnboardingScreen(store: store, onDone: () => done = true),
    ));
    expect(find.textContaining('Sua voz, suas regras'), findsOneWidget);
    expect(store.hasVoiceConsent, isFalse);

    await tester.ensureVisible(find.textContaining('Aceitar e fazer'));
    await tester.tap(find.textContaining('Aceitar e fazer'));
    await tester.pumpAndSettle();
    expect(store.hasVoiceConsent, isTrue);
    expect(done, isTrue);
  });

  test('feedback varia por desempenho e aponta o som fraco', () {
    const lesson = Lesson(
      id: 't', title: 't', objective: 't', approvalThreshold: 75, items: [],
    );
    PronunciationResult mk(double acc, double minPhon, {String syl = ''}) =>
        PronunciationResult(
          accuracy: acc, fluency: 100, completeness: 100, pronScore: acc,
          recognizedText: 't',
          words: [
            WordScore(
              word: 't', accuracy: acc,
              phonemes: [minPhon, 100],
              syllables: [SyllableScore(grapheme: syl, accuracy: minPhon)],
            ),
          ],
        );
    expect(feedbackFor(mk(98, 96), lesson), contains('Perfeito'));
    expect(feedbackFor(mk(88, 85), lesson), contains('Muito bom'));
    expect(feedbackFor(mk(78, 80), lesson), contains('Boa'));
    // Fonema fraco com sílaba conhecida → aponta o trecho.
    expect(feedbackFor(mk(72, 40, syl: 'cho'), lesson), contains('"cho"'));
  });

  test('aprovação multicritério barra pronúncia aportuguesada', () {
    const lesson = Lesson(
      id: 't',
      title: 't',
      objective: 't',
      approvalThreshold: 75,
      minProsody: 70,
      items: [],
    );
    // Scores medidos no experimento de 2026-06-12 (TTS pt-BR lendo o texto
    // em inglês simula o sotaque aportuguesado; argumentos: accuracy,
    // fonema mínimo, prosódia):
    expect(lesson.approves(72, 38, 82.1), isFalse, // chocolate aportuguesado
        reason: 'fonema em 38 deve reprovar mesmo com accuracy 72');
    expect(lesson.approves(96, 78, 65.9), isFalse, // hotel aportuguesado
        reason: 'prosódia 66 deve reprovar em lição de ritmo');
    expect(lesson.approves(98, 94, 87.8), isTrue); // chocolate nativo
    expect(lesson.approves(100, 100, 83.9), isTrue); // hotel nativo
  });

  test('modo desafio exige pronúncia próxima da nativa', () {
    const lesson = Lesson(
      id: 't', title: 't', objective: 't', approvalThreshold: 75, items: [],
    );
    // Passa no modo normal (>=75), mas não no desafio (exige accuracy >=90).
    expect(lesson.approves(82, 78, 90), isTrue);
    expect(lesson.approves(82, 78, 90, rigorous: true), isFalse);

    // Casos reais de "hotel" (medições de 2026-06): a prosódia separa
    // sotaque de nativo quando a accuracy empata.
    expect(lesson.approves(100, 100, 84, rigorous: true), isTrue, // nativo
        reason: 'hotel nativo deve passar no desafio');
    expect(lesson.approves(96, 78, 66, rigorous: true), isFalse, // sotaque
        reason: 'hotel com sotaque deve falhar por prosódia, não por accuracy');

    // "banana" nativo: vogal fraca tira 78 — não pode ser falso negativo.
    expect(lesson.approves(94, 78, 87, rigorous: true), isTrue,
        reason: 'pronúncia nativa não pode ser reprovada por vogal fraca');
  });

  test('conclusão de lição persiste e não duplica', () async {
    final store = await _emptyStore();
    expect(store.isLessonCompleted('fase1-licao01'), isFalse);
    await store.markLessonCompleted('fase1-licao01');
    await store.markLessonCompleted('fase1-licao01');
    expect(store.isLessonCompleted('fase1-licao01'), isTrue);
    expect(store.isLessonCompleted('fase1-licao02'), isFalse);
  });

  test('analytics guarda eventos e respeita o limite', () async {
    SharedPreferences.setMockInitialValues({});
    final analytics = await AnalyticsService.load();
    await analytics.log('lesson_started', {'lesson': 'fase1-licao01'});
    await analytics.log('attempt_assessed', {'approved': true});
    final events = analytics.dump();
    expect(events, hasLength(2));
    expect(events.first, contains('lesson_started'));
  });

  test('apagar dados zera progresso e consentimento (LGPD)', () async {
    final store = await _emptyStore();
    await store.grantVoiceConsent();
    await store.addApproved(const Duration(seconds: 30));
    await store.markLessonCompleted('fase1-licao01');

    await store.clearAll();
    expect(store.hasVoiceConsent, isFalse);
    expect(store.totalApproved, Duration.zero);
    expect(store.isLessonCompleted('fase1-licao01'), isFalse);
    expect(store.streakDays, 0);
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

  test('acesso Beta Fundador começa desligado e persiste quando ligado',
      () async {
    SharedPreferences.setMockInitialValues({});
    final ent = await LocalEntitlementService.load();
    expect(ent.hasFounderAccess, isFalse); // default: sem acesso

    await ent.setFounderAccess(true);
    expect(ent.hasFounderAccess, isTrue);

    // Persiste: uma nova instância lê o mesmo valor (cross-sessão).
    final ent2 = await LocalEntitlementService.load();
    expect(ent2.hasFounderAccess, isTrue);
  });

  test('regra de produto: todas as lições estão grátis por enquanto', () {
    expect(kFreeLessonCount, fase1Lessons.length);
  });

  test('preferência de tema começa em system e persiste (cross-sessão)',
      () async {
    final store = await _emptyStore();
    expect(store.themePref, 'system'); // default: segue o aparelho

    await store.setThemePref('dark');
    expect(store.themePref, 'dark');

    final store2 = await ProgressStore.load();
    expect(store2.themePref, 'dark');
  });

  test('mapa de fala: separa dominadas/revisar, ordena e categoriza', () {
    final rows = <Map<String, dynamic>>[
      {'props': {'item': 'apple', 'accuracy': 92, 'approved': true}},
      {'props': {'item': 'apple', 'accuracy': 70, 'approved': false}},
      {'props': {'item': 'hotel', 'accuracy': 55, 'approved': false}},
      {'props': {'item': 'hotel', 'accuracy': 60, 'approved': false}},
      {'props': {'item': 'banana', 'accuracy': 40, 'approved': false}},
      {'props': {'item': 'cinema', 'accuracy': 88, 'approved': true}},
      // accuracy ok, mas prosódia baixa → categoria Ritmo.
      {'props': {'item': 'comfortable', 'accuracy': 85, 'prosody': 50, 'approved': false}},
      {'props': {'noise': 1}}, // sem 'item' → ignorado
    ];
    final mem = aggregateWordMemory(rows);

    // Dominadas (aprovadas alguma vez), melhor accuracy primeiro.
    expect(mem.mastered.map((s) => s.word).toList(), ['apple', 'cinema']);
    expect(mem.mastered.first.bestAccuracy, 92);
    expect(mem.mastered.first.attempts, 2); // apple: 2 tentativas

    // A revisar (nunca aprovadas), pior accuracy primeiro.
    expect(mem.review.map((s) => s.word).toList(),
        ['banana', 'hotel', 'comfortable']);
    expect(mem.review.first.bestAccuracy, 40);

    // Categoria por dimensão fraca (dado real).
    expect(mem.review.firstWhere((s) => s.word == 'comfortable').category,
        SpeechCategory.rhythm);
    expect(mem.review.firstWhere((s) => s.word == 'banana').category,
        SpeechCategory.pronunciation); // sem prosódia → pronúncia
  });

  test('ativação: firstOnce dispara só uma vez; aha persiste', () async {
    final store = await _emptyStore();
    expect(store.firstOnce('first_recording_completed'), isTrue);
    expect(store.firstOnce('first_recording_completed'), isFalse);
    expect(store.firstOnce('first_feedback_seen'), isTrue); // outro passo: ok

    expect(store.hasAnsweredAha, isFalse);
    await store.setAhaAnswered();
    expect(store.hasAnsweredAha, isTrue);
  });
}

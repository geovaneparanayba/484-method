import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'backend.dart';
import 'pricing.dart';

/// Persistência local do progresso (web: localStorage; mobile: prefs), com
/// espelhamento opcional no Supabase ([Backend]).
///
/// Guarda a métrica norte do produto — segundos de prática oral APROVADA —
/// e o streak de dias consecutivos. O local é a fonte de verdade da UI;
/// quando há backend, cada escrita é espelhada (fire-and-forget) para o
/// Supabase, habilitando cross-device.
class ProgressStore {
  ProgressStore(this._prefs, {this.backend});

  final Backend? backend;

  static const _kApprovedSeconds = 'approved_seconds_total';
  static const _kStreakDays = 'streak_days';
  static const _kLastPracticeDay = 'last_practice_day';
  static const _kCompletedLessons = 'completed_lessons';
  static const _kVoiceConsentAt = 'voice_consent_at';
  static const _kVoiceStorageConsentAt = 'voice_storage_consent_at';
  static const _kRigorousMode = 'rigorous_mode';
  static const _kThemeMode = 'theme_mode';
  static const _kActivationSteps = 'activation_steps';
  static const _kAhaAnswered = 'aha_answered';
  static const _kAbandonAsked = 'abandon_asked';
  static const _kItemIndexPrefix = 'lesson_item_index_';
  static const _kApprovedTodaySeconds = 'approved_seconds_today';
  static const _kApprovedTodayDate = 'approved_seconds_today_date';
  static const _kDailyChallengeLessonId = 'daily_challenge_lesson_id';
  static const _kDailyChallengeDate = 'daily_challenge_date';
  static const _kDailyChallengeCompleted = 'daily_challenge_completed';
  static const _kPriceBucket = 'price_bucket';
  static const _kFounderEmailLeft = 'founder_email_left';
  static const _kCohortStart = 'cohort_start_date';
  static const _kBaselineConfidence = 'cohort_baseline_confidence';
  static const _kFinalConfidence = 'cohort_final_confidence';

  /// Meta do produto: 484 horas de prática aprovada.
  static const goalSeconds = 484 * 3600;

  /// Meta curta do dia (#7): mais tangível que a jornada de 484h.
  static const dailyGoalSeconds = 3 * 60;

  /// Primeiro marco (#7): entre a meta diária e as 484h, um objetivo
  /// alcançável em poucos dias que dá a primeira sensação real de progresso.
  static const firstMilestoneSeconds = 10 * 60;

  final SharedPreferences _prefs;

  static Future<ProgressStore> load({Backend? backend}) async {
    final store =
        ProgressStore(await SharedPreferences.getInstance(), backend: backend);
    await store._hydrateFromRemote();
    return store;
  }

  /// Em outro dispositivo (mesma conta), traz o progresso remoto se ele for
  /// maior que o local — evita "perder" tempo aprovado ao logar em outro lugar.
  Future<void> _hydrateFromRemote() async {
    final remote = await backend?.pullProgress();
    if (remote == null) return;
    final remoteSeconds = (remote['approved_seconds'] as int?) ?? 0;
    if (remoteSeconds > totalApproved.inSeconds) {
      await _prefs.setInt(_kApprovedSeconds, remoteSeconds);
      await _prefs.setInt(_kStreakDays, (remote['streak_days'] as int?) ?? 0);
      final lessons = (remote['completed_lessons'] as List?)?.cast<String>();
      if (lessons != null) {
        await _prefs.setStringList(_kCompletedLessons, lessons);
      }
    }
  }

  Map<String, dynamic> _snapshot() => {
        'approved_seconds': totalApproved.inSeconds,
        'streak_days': streakDays,
        'last_practice_day': _prefs.getString(_kLastPracticeDay),
        'completed_lessons':
            _prefs.getStringList(_kCompletedLessons) ?? const [],
        'rigorous_mode': rigorousMode,
        'voice_consent_at': _prefs.getString(_kVoiceConsentAt),
      };

  Duration get totalApproved =>
      Duration(seconds: _prefs.getInt(_kApprovedSeconds) ?? 0);

  int get streakDays => _prefs.getInt(_kStreakDays) ?? 0;

  double get goalFraction =>
      (totalApproved.inSeconds / goalSeconds).clamp(0.0, 1.0);

  /// Tempo aprovado hoje (#7): zera automaticamente ao virar o dia.
  Duration get approvedToday {
    final today = _ymd(DateTime.now());
    if (_prefs.getString(_kApprovedTodayDate) != today) return Duration.zero;
    return Duration(seconds: _prefs.getInt(_kApprovedTodaySeconds) ?? 0);
  }

  double get firstMilestoneFraction =>
      (totalApproved.inSeconds / firstMilestoneSeconds).clamp(0.0, 1.0);

  bool get reachedFirstMilestone =>
      totalApproved.inSeconds >= firstMilestoneSeconds;

  /// Soma tempo aprovado e atualiza o streak conforme o dia da prática.
  Future<void> addApproved(Duration d) async {
    await _prefs.setInt(
        _kApprovedSeconds, totalApproved.inSeconds + d.inSeconds);

    final today = _ymd(DateTime.now());
    if (_prefs.getString(_kApprovedTodayDate) != today) {
      await _prefs.setInt(_kApprovedTodaySeconds, d.inSeconds);
      await _prefs.setString(_kApprovedTodayDate, today);
    } else {
      await _prefs.setInt(
          _kApprovedTodaySeconds, approvedToday.inSeconds + d.inSeconds);
    }
    final lastDay = _prefs.getString(_kLastPracticeDay);
    if (lastDay != today) {
      final yesterday =
          _ymd(DateTime.now().subtract(const Duration(days: 1)));
      final newStreak = (lastDay == yesterday) ? streakDays + 1 : 1;
      await _prefs.setInt(_kStreakDays, newStreak);
      await _prefs.setString(_kLastPracticeDay, today);
    }
    backend?.pushProgress(_snapshot()); // espelha sempre (tempo mudou)
  }

  /// LGPD: gravação de voz é dado pessoal sensível — o app só pode gravar
  /// após consentimento explícito, e a data do aceite fica registrada.
  bool get hasVoiceConsent => _prefs.getString(_kVoiceConsentAt) != null;

  Future<void> grantVoiceConsent() async {
    await _prefs.setString(
        _kVoiceConsentAt, DateTime.now().toIso8601String());
    backend?.pushProgress(_snapshot());
  }

  /// LGPD: consentimento AMPLIADO — guardar a gravação (não só processar e
  /// descartar, como no loop de lição). Base para o áudio de baseline/final do
  /// desafio de 21 dias ficar salvo no Storage pro antes/depois com rating
  /// cego. Distinto de [hasVoiceConsent] de propósito: reter voz é uma base
  /// legal diferente de processá-la na hora.
  bool get hasVoiceStorageConsent =>
      _prefs.getString(_kVoiceStorageConsentAt) != null;

  Future<void> grantVoiceStorageConsent() => _prefs.setString(
      _kVoiceStorageConsentAt, DateTime.now().toIso8601String());

  /// Modo desafio: aprovação exige pronúncia próxima da nativa. Default off
  /// (Fase 1 é confiança primeiro).
  bool get rigorousMode => _prefs.getBool(_kRigorousMode) ?? false;

  Future<void> setRigorousMode(bool value) async {
    await _prefs.setBool(_kRigorousMode, value);
    backend?.pushProgress(_snapshot());
  }

  /// Preferência de tema (UI, só local — não espelha no backend): 'system'
  /// (default, segue o aparelho), 'light' ou 'dark'.
  String get themePref => _prefs.getString(_kThemeMode) ?? 'system';

  Future<void> setThemePref(String value) =>
      _prefs.setString(_kThemeMode, value);

  /// Ativação (Fase 0): marca um passo `first_*` como já visto (idempotente).
  /// Retorna true só na 1ª vez — pra disparar o evento sem repetir. Só local;
  /// clearAll zera junto (LGPD).
  bool firstOnce(String step) {
    final done = _prefs.getStringList(_kActivationSteps) ?? const [];
    if (done.contains(step)) return false;
    _prefs.setStringList(_kActivationSteps, [...done, step]);
    return true;
  }

  /// "Momento Uau": se a pessoa já respondeu a pergunta de percepção de melhora.
  bool get hasAnsweredAha => _prefs.getBool(_kAhaAnswered) ?? false;

  Future<void> setAhaAnswered() => _prefs.setBool(_kAhaAnswered, true);

  /// Leitura (sem consumir) se um passo de ativação já ocorreu — usado pra
  /// decidir o survey de abandono (começou mas não fechou o 1º ciclo).
  bool hasDone(String step) =>
      (_prefs.getStringList(_kActivationSteps) ?? const []).contains(step);

  /// Survey de abandono: já perguntamos por que a pessoa parou no 1º ciclo?
  bool get hasAskedAbandon => _prefs.getBool(_kAbandonAsked) ?? false;

  Future<void> setAskedAbandon() => _prefs.setBool(_kAbandonAsked, true);

  bool isLessonCompleted(String lessonId) =>
      (_prefs.getStringList(_kCompletedLessons) ?? const [])
          .contains(lessonId);

  /// Desafio de hoje: uma lição sorteada por dia (quem sorteia é a home, que
  /// conhece paywall e progressão). Null se o sorteio salvo não é de hoje.
  /// Só local, como itemIndex — é conveniência diária de UX, não a métrica
  /// norte; some sozinho ao virar o dia.
  String? get dailyChallengeLessonId {
    if (_prefs.getString(_kDailyChallengeDate) != _ymd(DateTime.now())) {
      return null;
    }
    return _prefs.getString(_kDailyChallengeLessonId);
  }

  bool get dailyChallengeCompleted =>
      dailyChallengeLessonId != null &&
      (_prefs.getBool(_kDailyChallengeCompleted) ?? false);

  Future<void> setDailyChallenge(String lessonId) async {
    await _prefs.setString(_kDailyChallengeLessonId, lessonId);
    await _prefs.setString(_kDailyChallengeDate, _ymd(DateTime.now()));
    await _prefs.setBool(_kDailyChallengeCompleted, false);
  }

  /// Variante de preço deste usuário no teste de willingness-to-pay. ESTÁVEL:
  /// a mesma pessoa sempre vê o mesmo preço — senão a conversão por preço vira
  /// ruído. Sorteia no 1º acesso ao paywall e persiste. Só local (estado de
  /// experimento, não a métrica norte); chamar FORA do build (tem efeito
  /// colateral de persistir o sorteio).
  PriceVariant assignedPriceVariant() {
    final saved = _prefs.getString(_kPriceBucket);
    for (final v in kPriceVariants) {
      if (v.bucket == saved) return v;
    }
    final picked = kPriceVariants[Random().nextInt(kPriceVariants.length)];
    _prefs.setString(_kPriceBucket, picked.bucket);
    return picked;
  }

  /// Já deixou o e-mail na lista de Fundadores (fake door do teste de WTP)?
  /// Usado pra parar de oferecer depois que a pessoa converteu.
  bool get hasLeftFounderEmail => _prefs.getBool(_kFounderEmailLeft) ?? false;

  Future<void> setLeftFounderEmail() =>
      _prefs.setBool(_kFounderEmailLeft, true);

  // --- Desafio de 21 dias (instrumento de validação do beta) ---
  // Estado só local, como dailyChallenge/priceBucket: o que vira métrica
  // (confiança inicial/final, antes/depois) sai como EVENTO de analytics
  // (events.props, jsonb flexível) — não entra no snapshot do progresso, pra
  // não exigir migração de coluna nem arriscar quebrar o upsert do progresso.

  /// Quantos dias dura o desafio. A gravação/pesquisa final e o antes/depois
  /// liberam a partir do último dia.
  static const cohortLength = 21;

  String? get cohortStartDate => _prefs.getString(_kCohortStart);

  bool get cohortStarted => cohortStartDate != null;

  /// Dia atual do desafio, 1-based (o dia em que começou é o dia 1). 0 se
  /// ainda não começou. Nunca abaixo de 1 depois de começar (protege contra
  /// relógio do aparelho voltando no tempo).
  int get cohortDay {
    final start = cohortStartDate;
    if (start == null) return 0;
    final startDate = DateTime.tryParse(start);
    if (startDate == null) return 0;
    final today = DateTime.parse(_ymd(DateTime.now()));
    final diff = today.difference(startDate).inDays;
    return diff < 0 ? 1 : diff + 1;
  }

  /// Já passou o desafio inteiro → libera a etapa final (pesquisa de confiança
  /// final + antes/depois).
  bool get cohortFinalUnlocked => cohortStarted && cohortDay >= cohortLength;

  /// Autoavaliação de confiança pra falar inglês (1–5), no começo e no fim.
  /// É o par SUBJETIVO do antes/depois (o objetivo — gravação com nota — é a
  /// próxima fatia, precisa de gravação longa + storage).
  int? get baselineConfidence => _prefs.getInt(_kBaselineConfidence);
  int? get finalConfidence => _prefs.getInt(_kFinalConfidence);
  bool get cohortBaselineDone => baselineConfidence != null;
  bool get cohortFinalDone => finalConfidence != null;

  /// Começa o desafio hoje e grava a confiança inicial.
  Future<void> startCohort(int baselineConfidence) async {
    await _prefs.setString(_kCohortStart, _ymd(DateTime.now()));
    await _prefs.setInt(_kBaselineConfidence, baselineConfidence);
  }

  Future<void> setFinalConfidence(int value) =>
      _prefs.setInt(_kFinalConfidence, value);

  /// Em que item da lição a pessoa estava (pra retomar, não recomeçar do
  /// zero ao reabrir). Só local — é conveniência de UX, não a métrica norte,
  /// não precisa espelhar no Supabase.
  int itemIndexFor(String lessonId) =>
      _prefs.getInt('$_kItemIndexPrefix$lessonId') ?? 0;

  Future<void> saveItemIndex(String lessonId, int index) =>
      _prefs.setInt('$_kItemIndexPrefix$lessonId', index);

  Future<void> clearItemIndex(String lessonId) =>
      _prefs.remove('$_kItemIndexPrefix$lessonId');

  Future<void> markLessonCompleted(String lessonId) async {
    // Antes do early-return: o desafio pode ser uma lição já concluída
    // (revisão, quando a trilha liberada está toda feita).
    if (lessonId == dailyChallengeLessonId && !dailyChallengeCompleted) {
      await _prefs.setBool(_kDailyChallengeCompleted, true);
    }
    final done = _prefs.getStringList(_kCompletedLessons) ?? [];
    if (done.contains(lessonId)) return;
    await _prefs.setStringList(_kCompletedLessons, [...done, lessonId]);
    backend?.pushProgress(_snapshot());
  }

  /// LGPD: exclusão de todos os dados do usuário. Apaga primeiro os dados
  /// remotos (Supabase) e depois os locais (progresso, streak, consentimento).
  Future<void> clearAll() async {
    await backend?.deleteRemoteData();
    await _prefs.clear();
  }

  String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

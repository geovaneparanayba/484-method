import 'package:shared_preferences/shared_preferences.dart';

import 'backend.dart';

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
  static const _kRigorousMode = 'rigorous_mode';
  static const _kThemeMode = 'theme_mode';
  static const _kActivationSteps = 'activation_steps';
  static const _kAhaAnswered = 'aha_answered';
  static const _kAbandonAsked = 'abandon_asked';
  static const _kItemIndexPrefix = 'lesson_item_index_';
  static const _kApprovedTodaySeconds = 'approved_seconds_today';
  static const _kApprovedTodayDate = 'approved_seconds_today_date';

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

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

  /// Meta do produto: 484 horas de prática aprovada.
  static const goalSeconds = 484 * 3600;

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

  /// Soma tempo aprovado e atualiza o streak conforme o dia da prática.
  Future<void> addApproved(Duration d) async {
    await _prefs.setInt(
        _kApprovedSeconds, totalApproved.inSeconds + d.inSeconds);

    final today = _ymd(DateTime.now());
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

  bool isLessonCompleted(String lessonId) =>
      (_prefs.getStringList(_kCompletedLessons) ?? const [])
          .contains(lessonId);

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

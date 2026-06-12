import 'package:shared_preferences/shared_preferences.dart';

/// Persistência local do progresso (web: localStorage; mobile: prefs).
///
/// Guarda a métrica norte do produto — segundos de prática oral APROVADA —
/// e o streak de dias consecutivos. Quando o backend (Firebase/Supabase)
/// entrar, esta classe vira a interface e ganha uma implementação remota.
class ProgressStore {
  ProgressStore(this._prefs);

  static const _kApprovedSeconds = 'approved_seconds_total';
  static const _kStreakDays = 'streak_days';
  static const _kLastPracticeDay = 'last_practice_day';
  static const _kCompletedLessons = 'completed_lessons';

  /// Meta do produto: 484 horas de prática aprovada.
  static const goalSeconds = 484 * 3600;

  final SharedPreferences _prefs;

  static Future<ProgressStore> load() async =>
      ProgressStore(await SharedPreferences.getInstance());

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
    if (lastDay == today) return; // streak já contado hoje

    final yesterday =
        _ymd(DateTime.now().subtract(const Duration(days: 1)));
    final newStreak = (lastDay == yesterday) ? streakDays + 1 : 1;
    await _prefs.setInt(_kStreakDays, newStreak);
    await _prefs.setString(_kLastPracticeDay, today);
  }

  bool isLessonCompleted(String lessonId) =>
      (_prefs.getStringList(_kCompletedLessons) ?? const [])
          .contains(lessonId);

  Future<void> markLessonCompleted(String lessonId) async {
    final done = _prefs.getStringList(_kCompletedLessons) ?? [];
    if (done.contains(lessonId)) return;
    await _prefs.setStringList(_kCompletedLessons, [...done, lessonId]);
  }

  String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

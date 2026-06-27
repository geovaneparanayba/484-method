import 'package:flutter/material.dart';

import '../services/backend.dart';

/// Painel de uso — apenas para o desenvolvedor (acessível via menu oculto).
/// A senha digitada no diálogo de acesso é verificada pela Edge Function
/// `dev-stats` (secret no servidor), não no cliente: get_dev_stats() não é
/// mais chamável direto com a anon key, então o gate não pode ser pulado
/// chamando a RPC pelo console do navegador.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key, required this.backend, required this.password});
  final Backend backend;
  final String password;

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  Map<String, dynamic>? _stats;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final stats = await widget.backend.fetchDevStats(widget.password);
      setState(() {
        _stats = stats;
        _loading = false;
      });
    } on DevStatsAuthException {
      setState(() {
        _error = 'Senha incorreta.';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel do desenvolvedor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Erro: $_error'))
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 700),
                    child: _Body(stats: _stats!, theme: theme),
                  ),
                ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.stats, required this.theme});
  final Map<String, dynamic> stats;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final totalUsers       = (stats['total_users']         as num?)?.toInt() ?? 0;
    final usersToday       = (stats['users_today']         as num?)?.toInt() ?? 0;
    final users7d          = (stats['users_7d']            as num?)?.toInt() ?? 0;
    final users30d         = (stats['users_30d']           as num?)?.toInt() ?? 0;
    final usersStreak      = (stats['users_with_streak']   as num?)?.toInt() ?? 0;
    final avgStreakDays    = (stats['avg_streak_days']     as num?)?.toDouble() ?? 0;
    final rigorousUsers    = (stats['rigorous_mode_users'] as num?)?.toInt() ?? 0;
    final retentionD1      = (stats['retention_d1_pct']    as num?)?.toDouble() ?? 0;
    final totalAttempts    = (stats['total_attempts']      as num?)?.toInt() ?? 0;
    final totalCompleted   = (stats['total_completed']     as num?)?.toInt() ?? 0;
    final avgAccuracy      = (stats['avg_accuracy']        as num?)?.toInt() ?? 0;
    final approvedMin      = (stats['total_approved_min']  as num?)?.toInt() ?? 0;
    final startedNotDone   = (stats['started_not_finished']as num?)?.toInt() ?? 0;
    final approvalRate     = (stats['approval_rate']       as num?)?.toDouble() ?? 0;
    final avgAttempts      = (stats['avg_attempts_to_approve'] as num?)?.toDouble() ?? 0;
    final avgAudioSec      = (stats['avg_audio_seconds']   as num?)?.toDouble() ?? 0;
    final maxAudioSec      = (stats['max_audio_seconds']   as num?)?.toDouble() ?? 0;
    final audioSentMin     = (stats['total_audio_sent_min'] as num?)?.toDouble() ?? 0;
    final bonusCompleted   = (stats['bonus_lessons_completed'] as num?)?.toInt() ?? 0;
    final bonusUsers       = (stats['bonus_users']         as num?)?.toInt() ?? 0;
    final funnel           = (stats['funnel'] as Map?)?.cast<String, dynamic>() ?? {};
    final dau              = (stats['dau_14d'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final hourly           = (stats['hourly_48h'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final accHistogram     = (stats['accuracy_histogram'] as Map?)?.cast<String, dynamic>() ?? {};
    final hardestWords     = (stats['hardest_words'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final avgGapSec        = (stats['avg_seconds_between_attempts'] as num?)?.toDouble() ?? 0;
    final assessFailures   = (stats['assessment_failures'] as num?)?.toInt() ?? 0;
    final discardedSilence = (stats['recordings_discarded_silence'] as num?)?.toInt() ?? 0;
    final feedbackFallback = (stats['feedback_fallback_used'] as num?)?.toInt() ?? 0;
    final paywallViews     = (stats['paywall_views'] as num?)?.toInt() ?? 0;
    final paywallClicks    = (stats['paywall_subscribe_clicks'] as num?)?.toInt() ?? 0;
    final paywallDismiss   = (stats['paywall_dismissals'] as num?)?.toInt() ?? 0;
    final obCtaClicks      = (stats['onboarding_cta_clicks'] as num?)?.toInt() ?? 0;
    final obConsentOk      = (stats['onboarding_consent_accepted'] as num?)?.toInt() ?? 0;
    final browserBreakdown = (stats['browser_breakdown'] as Map?)?.cast<String, dynamic>() ?? {};
    final osBreakdown      = (stats['os_breakdown'] as Map?)?.cast<String, dynamic>() ?? {};
    final localeBreakdown  = (stats['locale_breakdown'] as Map?)?.cast<String, dynamic>() ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Usuários ──────────────────────────────────────────────────
          _section('Usuários'),
          _grid([
            _Metric(Icons.people_outline,      '$totalUsers',   'Total',      Colors.blue.shade600),
            _Metric(Icons.today,               '$usersToday',   'Hoje',       Colors.green.shade600),
            _Metric(Icons.date_range,          '$users7d',      'Últimos 7d', Colors.orange.shade700),
            _Metric(Icons.calendar_month,      '$users30d',     'Últimos 30d',Colors.purple.shade600),
          ]),
          const SizedBox(height: 8),
          _row(theme, Icons.local_fire_department, 'Com streak ativo', '$usersStreak usuários'),
          _row(theme, Icons.show_chart, 'Streak médio', '${avgStreakDays.toStringAsFixed(1)} dias'),
          _row(theme, Icons.repeat, 'Voltaram no dia seguinte (D1)', '${retentionD1.toStringAsFixed(1)}%'),
          _row(theme, Icons.shield_outlined, 'Modo rigoroso ativado', '$rigorousUsers usuários'),
          _row(theme, Icons.exit_to_app, 'Iniciaram mas não concluíram nenhuma lição', '$startedNotDone usuários'),

          // ── Engajamento ───────────────────────────────────────────────
          const SizedBox(height: 24),
          _section('Engajamento'),
          _grid([
            _Metric(Icons.mic_outlined,        '$totalAttempts','Gravações',  Colors.indigo.shade600),
            _Metric(Icons.check_circle_outline,'$totalCompleted','Lições OK', Colors.green.shade700),
            _Metric(Icons.grade_outlined,      '$avgAccuracy',  'Média /100', Colors.amber.shade700),
            _Metric(Icons.timer_outlined,      '${approvedMin}min','Aprovados',Colors.teal.shade600),
          ]),
          const SizedBox(height: 8),
          _row(theme, Icons.percent, 'Taxa de aprovação por tentativa', '${approvalRate.toStringAsFixed(1)}%'),
          _row(theme, Icons.replay, 'Tentativas médias até aprovar', avgAttempts.toStringAsFixed(1)),

          // ── Distribuição de notas ────────────────────────────────────
          if (accHistogram.isNotEmpty) ...[
            const SizedBox(height: 24),
            _section('Distribuição de notas (accuracy)'),
            const SizedBox(height: 8),
            ...['0-49', '50-69', '70-84', '85-94', '95-100'].map((bucket) {
              final n = (accHistogram[bucket] as num?)?.toInt() ?? 0;
              final maxN = accHistogram.values
                  .map((v) => (v as num).toInt())
                  .fold(0, (a, b) => a > b ? a : b);
              final frac = maxN > 0 ? n / maxN : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  SizedBox(width: 56, child: Text(bucket, style: theme.textTheme.bodySmall)),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: frac,
                      minHeight: 12,
                      borderRadius: BorderRadius.circular(4),
                      color: Colors.amber.shade700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(width: 28, child: Text('$n', style: theme.textTheme.bodySmall)),
                ]),
              );
            }),
          ],

          // ── Áudio / custo ─────────────────────────────────────────────
          const SizedBox(height: 24),
          _section('Áudio enviado (custo Azure)'),
          _grid([
            _Metric(Icons.graphic_eq,    '${avgAudioSec.toStringAsFixed(1)}s', 'Média/tentativa', Colors.cyan.shade700),
            _Metric(Icons.warning_amber, '${maxAudioSec.toStringAsFixed(0)}s', 'Pico (máx)',       Colors.red.shade600),
            _Metric(Icons.cloud_upload,  '${audioSentMin.toStringAsFixed(1)}min', 'Total enviado',Colors.deepPurple.shade400),
          ]),
          const SizedBox(height: 8),
          _row(theme, Icons.timer, 'Tempo médio entre tentativas (mesma lição)', '${avgGapSec.toStringAsFixed(1)}s'),

          // ── Palavras mais difíceis ──────────────────────────────────────
          if (hardestWords.isNotEmpty) ...[
            const SizedBox(height: 24),
            _section('Palavras mais difíceis (min. 3 tentativas)'),
            const SizedBox(height: 8),
            ...hardestWords.map((w) {
              final word = w['word'] as String? ?? '';
              final acc  = (w['avg_accuracy'] as num?)?.toInt() ?? 0;
              final att  = (w['attempts'] as num?)?.toInt() ?? 0;
              return _row(theme, Icons.translate, '$word ($att tentativas)', '$acc/100');
            }),
          ],

          // ── Saúde operacional ────────────────────────────────────────────
          const SizedBox(height: 24),
          _section('Saúde operacional'),
          _row(theme, Icons.error_outline, 'Falhas de avaliação (Azure)', '$assessFailures'),
          _row(theme, Icons.mic_off_outlined, 'Gravações descartadas (silêncio)', '$discardedSilence'),
          _row(theme, Icons.smart_toy_outlined, 'Feedback no fallback fixo (sem Claude)', '$feedbackFallback'),

          // ── Funil de paywall ──────────────────────────────────────────────
          const SizedBox(height: 24),
          _section('Funil de paywall'),
          _row(theme, Icons.visibility_outlined, 'Visualizações', '$paywallViews'),
          _row(theme, Icons.touch_app_outlined, 'Cliques em assinar', '$paywallClicks'),
          _row(theme, Icons.close, 'Dispensou ("Agora não")', '$paywallDismiss'),

          // ── Funil de onboarding ────────────────────────────────────────────
          const SizedBox(height: 24),
          _section('Funil de onboarding'),
          _row(theme, Icons.play_circle_outline, 'Clicou no CTA da landing', '$obCtaClicks'),
          _row(theme, Icons.check_circle_outline, 'Aceitou o consentimento de voz', '$obConsentOk'),

          // ── Dispositivo ─────────────────────────────────────────────────
          if (browserBreakdown.isNotEmpty || osBreakdown.isNotEmpty || localeBreakdown.isNotEmpty) ...[
            const SizedBox(height: 24),
            _section('Dispositivo (agregado, sem identificar ninguém)'),
            const SizedBox(height: 8),
            if (browserBreakdown.isNotEmpty) ..._breakdownRows(theme, 'Navegador', browserBreakdown),
            if (osBreakdown.isNotEmpty) ..._breakdownRows(theme, 'Sistema', osBreakdown),
            if (localeBreakdown.isNotEmpty) ..._breakdownRows(theme, 'Idioma', localeBreakdown),
          ],

          // ── Bônus ─────────────────────────────────────────────────────
          const SizedBox(height: 24),
          _section('Lições bônus'),
          _row(theme, Icons.star_outline, 'Lições bônus concluídas', '$bonusCompleted'),
          _row(theme, Icons.star_outline, 'Usuários que fizeram bônus', '$bonusUsers'),

          // ── Funil por lição ───────────────────────────────────────────
          if (funnel.isNotEmpty) ...[
            const SizedBox(height: 24),
            _section('Funil — usuários que completaram cada lição'),
            const SizedBox(height: 8),
            ...funnel.entries.map((e) {
              final users = (e.value as num).toInt();
              final frac  = totalUsers > 0 ? users / totalUsers : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(e.key, style: theme.textTheme.bodySmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                        Text('$users usuários (${(frac * 100).round()}%)',
                            style: theme.textTheme.bodySmall),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: frac,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                      color: Colors.green.shade600,
                    ),
                  ],
                ),
              );
            }),
          ],

          // ── DAU últimos 14 dias ───────────────────────────────────────
          if (dau.isNotEmpty) ...[
            const SizedBox(height: 24),
            _section('Usuários ativos — últimos 14 dias'),
            const SizedBox(height: 8),
            ...dau.map((d) {
              final day  = d['day'] as String? ?? '';
              final u    = (d['users'] as num?)?.toInt() ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  SizedBox(
                    width: 90,
                    child: Text(day.length > 10 ? day.substring(5, 10) : day,
                        style: theme.textTheme.bodySmall),
                  ),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: u / (totalUsers > 0 ? totalUsers : 1),
                      minHeight: 14,
                      borderRadius: BorderRadius.circular(4),
                      color: Colors.blue.shade400,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('$u', style: theme.textTheme.bodySmall),
                ]),
              );
            }),
          ],

          // ── Usuários ativos por hora (últimas 48h) ─────────────────────
          if (hourly.isNotEmpty) ...[
            const SizedBox(height: 24),
            _section('Usuários ativos por hora — últimas 48h'),
            const SizedBox(height: 8),
            ...() {
              final maxHourly = hourly.fold<int>(
                  0, (m, h) => ((h['users'] as num?)?.toInt() ?? 0) > m ? (h['users'] as num).toInt() : m);
              return hourly.map((h) {
                final ts = h['hour_ts'] as String? ?? '';
                final label = ts.length >= 13
                    ? '${ts.substring(8, 10)}/${ts.substring(5, 7)} ${ts.substring(11, 13)}h'
                    : ts;
                final u = (h['users'] as num?)?.toInt() ?? 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    SizedBox(
                      width: 80,
                      child: Text(label, style: theme.textTheme.bodySmall),
                    ),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: u / (maxHourly > 0 ? maxHourly : 1),
                        minHeight: 14,
                        borderRadius: BorderRadius.circular(4),
                        color: Colors.teal.shade400,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('$u', style: theme.textTheme.bodySmall),
                  ]),
                );
              });
            }(),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(title,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
      );

  Widget _row(ThemeData t, IconData icon, String label, String value) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Icon(icon, size: 16, color: t.colorScheme.outline),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: t.textTheme.bodySmall)),
          Text(value,
              style: t.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _grid(List<_Metric> items) => GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.4,
        children: items.map((m) => _Card(m)).toList(),
      );

  /// Linha de rótulo + um _row por chave, ordenado do mais comum ao menos.
  List<Widget> _breakdownRows(ThemeData t, String label, Map<String, dynamic> breakdown) {
    final total = breakdown.values.fold<int>(0, (a, b) => a + (b as num).toInt());
    final entries = breakdown.entries.toList()
      ..sort((a, b) => (b.value as num).compareTo(a.value as num));
    return [
      Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 2),
        child: Text(label, style: t.textTheme.labelSmall
            ?.copyWith(color: t.colorScheme.outline)),
      ),
      ...entries.map((e) {
        final n = (e.value as num).toInt();
        final pct = total > 0 ? (n / total * 100).round() : 0;
        return _row(t, Icons.circle, e.key, '$n ($pct%)');
      }),
    ];
  }
}

class _Metric {
  const _Metric(this.icon, this.value, this.label, this.color);
  final IconData icon;
  final String value;
  final String label;
  final Color color;
}

class _Card extends StatelessWidget {
  const _Card(this.m);
  final _Metric m;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: m.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: m.color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(m.icon, color: m.color, size: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(m.value,
                  style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold, color: m.color)),
              Text(m.label, style: theme.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

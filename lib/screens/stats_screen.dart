import 'package:flutter/material.dart';

import '../services/backend.dart';
import 'cohort_rating_screen.dart';

/// Painel de uso — apenas para o desenvolvedor (acessível via menu oculto).
/// A senha digitada no diálogo de acesso é verificada pela Edge Function
/// `dev-stats` (secret no servidor), não no cliente: get_dev_stats() não é
/// mais chamável direto com a anon key, então o gate não pode ser pulado
/// chamando a RPC pelo console do navegador.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key, required this.backend, required this.password});
  final Backend backend;
  final String password;

  /// Diálogo de senha + navegação para o painel. Compartilhado entre o menu
  /// oculto da home e a saída de dev da tela de manutenção — a validação real
  /// acontece no servidor quando o painel carrega.
  static Future<void> openWithPasswordGate(
      BuildContext context, Backend backend) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Acesso restrito'),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Senha'),
          onSubmitted: (_) => Navigator.of(ctx).pop(true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Entrar'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          StatsScreen(backend: backend, password: controller.text),
    ));
  }

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  Map<String, dynamic>? _stats;
  bool _loading = true;
  bool _toggling = false;
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

  /// Liga/desliga o app para TODOS os usuários (flag no servidor). Desligar
  /// pede confirmação — quem estiver no meio de um treino continua até
  /// recarregar, mas ninguém novo entra.
  Future<void> _setAppOnline(bool online) async {
    if (_toggling) return;
    if (!online) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Desligar o app?'),
          content: const Text(
              'Todos os usuários passam a ver a tela "em ajustes" ao abrir '
              'o app. Para religar, volte a este painel (na tela de '
              'manutenção, segure o ícone de obra).'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Desligar'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    setState(() => _toggling = true);
    try {
      final stats =
          await widget.backend.setMaintenanceMode(widget.password, !online);
      if (!mounted) return;
      setState(() => _stats = stats);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao alterar: $e')),
      );
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maintenanceOn = _stats?['maintenance_mode'] == true;
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
                    child: Column(
                      children: [
                        // ── Controle do app (fase de construção) ──────────
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                          child: Card(
                            color: maintenanceOn
                                ? theme.colorScheme.errorContainer
                                : null,
                            child: SwitchListTile(
                              value: !maintenanceOn,
                              onChanged:
                                  _toggling ? null : (v) => _setAppOnline(v),
                              title: Text(
                                maintenanceOn
                                    ? 'App DESLIGADO (em ajustes)'
                                    : 'App no ar',
                                style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(maintenanceOn
                                  ? 'Usuários veem a tela "em ajustes" ao abrir.'
                                  : 'Desligue para bloquear o acesso durante a construção.'),
                              secondary: Icon(maintenanceOn
                                  ? Icons.construction
                                  : Icons.check_circle_outline),
                            ),
                          ),
                        ),
                        // ── Rating cego das gravações do desafio de 21 dias ─
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                          child: Card(
                            child: ListTile(
                              leading: const Icon(Icons.graphic_eq),
                              title: const Text('Rating cego de fala'),
                              subtitle: const Text(
                                  'Ouça baseline/final às cegas e compare o '
                                  'antes/depois.'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => CohortRatingScreen(
                                    backend: widget.backend,
                                    password: widget.password,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(child: _Body(stats: _stats!, theme: theme)),
                      ],
                    ),
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
    final lessonDuration    = (stats['lesson_duration'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final avgGapSec        = (stats['avg_seconds_between_attempts'] as num?)?.toDouble() ?? 0;
    final assessFailures   = (stats['assessment_failures'] as num?)?.toInt() ?? 0;
    final discardedSilence = (stats['recordings_discarded_silence'] as num?)?.toInt() ?? 0;
    final feedbackFallback = (stats['feedback_fallback_used'] as num?)?.toInt() ?? 0;
    final paywallViews     = (stats['paywall_views'] as num?)?.toInt() ?? 0;
    final paywallClicks    = (stats['paywall_subscribe_clicks'] as num?)?.toInt() ?? 0;
    final paywallDismiss   = (stats['paywall_dismissals'] as num?)?.toInt() ?? 0;
    final browserBreakdown = (stats['browser_breakdown'] as Map?)?.cast<String, dynamic>() ?? {};
    final osBreakdown      = (stats['os_breakdown'] as Map?)?.cast<String, dynamic>() ?? {};
    final localeBreakdown  = (stats['locale_breakdown'] as Map?)?.cast<String, dynamic>() ?? {};
    final stickiness       = (stats['stickiness_pct'] as num?)?.toDouble() ?? 0;
    final retention        = (stats['retention'] as Map?)?.cast<String, dynamic>() ?? {};
    final activation       = (stats['activation'] as Map?)?.cast<String, dynamic>() ?? {};
    final newUsers         = (stats['new_users_14d'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final northStar        = (stats['north_star_14d'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final lessonsPerUser   = (stats['lessons_per_active_user'] as num?)?.toDouble() ?? 0;
    final recordingsPerUser= (stats['recordings_per_user'] as num?)?.toDouble() ?? 0;
    final azureCost        = (stats['azure_cost_usd'] as num?)?.toDouble() ?? 0;
    final azureCostPerUser = (stats['azure_cost_per_user_usd'] as num?)?.toDouble() ?? 0;
    final acqFunnel        = (stats['acquisition_funnel'] as Map?)?.cast<String, dynamic>() ?? {};
    final sourceBreakdown  = (stats['source_breakdown'] as Map?)?.cast<String, dynamic>() ?? {};
    final phase0           = (stats['phase0_activation'] as Map?)?.cast<String, dynamic>() ?? {};
    final ahaBreakdown     = (stats['aha_breakdown'] as Map?)?.cast<String, dynamic>() ?? {};
    final abandonBreakdown = (stats['abandon_breakdown'] as Map?)?.cast<String, dynamic>() ?? {};

    // "15.4% (n=39)" ou "— (n=0)" quando o cohort é pequeno/vazio.
    String fmtRet(String key) {
      final r = (retention[key] as Map?)?.cast<String, dynamic>() ?? {};
      final pct = (r['pct'] as num?)?.toDouble();
      final n = (r['n'] as num?)?.toInt() ?? 0;
      final p = pct == null ? '—' : '${pct.toStringAsFixed(1)}%';
      return '$p (n=$n)';
    }

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
          _row(theme, Icons.shield_outlined, 'Modo rigoroso ativado', '$rigorousUsers usuários'),
          _row(theme, Icons.exit_to_app, 'Iniciaram mas não concluíram nenhuma lição', '$startedNotDone usuários'),
          _row(theme, Icons.bolt, 'Stickiness (DAU/MAU)', '${stickiness.toStringAsFixed(1)}%'),

          // ── Retenção & ativação ───────────────────────────────────────
          const SizedBox(height: 24),
          _section('Retenção & ativação'),
          _row(theme, Icons.repeat, 'D1 — voltou em até 1 dia', fmtRet('d1')),
          _row(theme, Icons.repeat, 'D7 — voltou em até 7 dias', fmtRet('d7')),
          _row(theme, Icons.repeat, 'D30 — voltou em até 30 dias', fmtRet('d30')),
          _row(theme, Icons.rocket_launch_outlined,
              'Ativação (concluiu ≥1 lição / iniciou ≥1)',
              '${(activation['pct'] as num?)?.toStringAsFixed(1) ?? '0'}%  '
              '(${(activation['activated'] as num?)?.toInt() ?? 0}/${(activation['started'] as num?)?.toInt() ?? 0})'),

          // ── Fase 0 — funil de ativação (eventos first_*) ──────────────
          const SizedBox(height: 24),
          _section('Fase 0 — funil de ativação (usuários únicos)'),
          _row(theme, Icons.hearing, '1 · Ouviu', '${(phase0['listen'] as num?)?.toInt() ?? 0}'),
          _row(theme, Icons.mic_none, '2 · Gravou', '${(phase0['recording'] as num?)?.toInt() ?? 0}'),
          _row(theme, Icons.feedback_outlined, '3 · Viu feedback', '${(phase0['feedback'] as num?)?.toInt() ?? 0}'),
          _row(theme, Icons.replay, '4 · Regravou', '${(phase0['retry'] as num?)?.toInt() ?? 0}'),
          _row(theme, Icons.compare_arrows, '5 · Viu antes/depois', '${(phase0['before_after'] as num?)?.toInt() ?? 0}'),
          _row(theme, Icons.verified_outlined, 'activation_completed',
              '${(phase0['completed'] as num?)?.toInt() ?? 0} '
              '(${(phase0['completed_pct'] as num?)?.toStringAsFixed(1) ?? '0'}%)'),
          _row(theme, Icons.timer_outlined, '1º minuto aprovado', '${(phase0['approved_minute'] as num?)?.toInt() ?? 0}'),
          if (ahaBreakdown.isNotEmpty) ...[
            const SizedBox(height: 8),
            _section('Sentiu melhora? (Momento Uau)'),
            for (final e in ahaBreakdown.entries)
              _row(theme, Icons.psychology_outlined, e.key, '${(e.value as num?)?.toInt() ?? 0}'),
          ],
          if (abandonBreakdown.isNotEmpty) ...[
            const SizedBox(height: 8),
            _section('Motivos de abandono'),
            for (final e in abandonBreakdown.entries)
              _row(theme, Icons.exit_to_app, e.key, '${(e.value as num?)?.toInt() ?? 0}'),
          ],

          // ── Crescimento: novos usuários por dia ───────────────────────
          if (newUsers.isNotEmpty) ...[
            const SizedBox(height: 24),
            _section('Novos usuários por dia (14d)'),
            const SizedBox(height: 8),
            ..._timeSeriesRows(theme, newUsers, 'day', 'users', Colors.green.shade500,
                labelFmt: (s) => s.length > 10 ? s.substring(5, 10) : s),
          ],

          // ── North star: minutos de prática aprovada por dia ───────────
          if (northStar.isNotEmpty) ...[
            const SizedBox(height: 24),
            _section('North star — min. de prática aprovada/dia (14d)'),
            const SizedBox(height: 8),
            ..._timeSeriesRows(theme, northStar, 'day', 'approved_min', Colors.teal.shade600,
                labelFmt: (s) => s.length > 10 ? s.substring(5, 10) : s,
                valueFmt: (v) => '${v.toStringAsFixed(1)}min'),
          ],

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
          _row(theme, Icons.menu_book_outlined, 'Lições concluídas por usuário ativo', lessonsPerUser.toStringAsFixed(1)),
          _row(theme, Icons.mic_none, 'Gravações por usuário', recordingsPerUser.toStringAsFixed(1)),

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
          _row(theme, Icons.attach_money, 'Custo Azure total (est. US\$1/h, tarifa S0)', 'US\$ ${azureCost.toStringAsFixed(2)}'),
          _row(theme, Icons.person_outline, 'Custo Azure por usuário', 'US\$ ${azureCostPerUser.toStringAsFixed(4)}'),

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

          // ── Tempo parado em cada lição ───────────────────────────────────
          if (lessonDuration.isNotEmpty) ...[
            const SizedBox(height: 24),
            _section('Tempo até concluir cada lição (início → fim)'),
            const SizedBox(height: 8),
            ...lessonDuration.map((l) {
              final lesson = l['lesson_id'] as String? ?? '';
              final sec    = (l['avg_seconds'] as num?)?.toInt() ?? 0;
              final n      = (l['n'] as num?)?.toInt() ?? 0;
              final fmt = sec >= 60 ? '${sec ~/ 60}min ${sec % 60}s' : '${sec}s';
              return _row(theme, Icons.timer_outlined, '$lesson ($n concluídas)', fmt);
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

          // ── Funil de aquisição (landing → CTA → consentimento → 1ª lição) ─
          const SizedBox(height: 24),
          _section('Funil de aquisição'),
          ...() {
            final landing  = (acqFunnel['landing_views'] as num?)?.toInt() ?? 0;
            final cta      = (acqFunnel['cta_clicks'] as num?)?.toInt() ?? 0;
            final consent  = (acqFunnel['consent_accepted'] as num?)?.toInt() ?? 0;
            final firstDone= (acqFunnel['first_lesson_done'] as num?)?.toInt() ?? 0;
            String conv(int num, int den) =>
                den > 0 ? '  (${(100.0 * num / den).toStringAsFixed(0)}%)' : '';
            return [
              _row(theme, Icons.visibility_outlined,
                  'Viu a landing', landing > 0 ? '$landing' : '— (instrumentando)'),
              _row(theme, Icons.play_circle_outline,
                  'Clicou no CTA', '$cta${conv(cta, landing)}'),
              _row(theme, Icons.check_circle_outline,
                  'Aceitou consentimento de voz', '$consent${conv(consent, cta)}'),
              _row(theme, Icons.school_outlined,
                  'Concluiu a 1ª lição', '$firstDone${conv(firstDone, consent)}'),
            ];
          }(),

          // ── Aquisição: de onde vêm ───────────────────────────────────────
          if (sourceBreakdown.isNotEmpty) ...[
            const SizedBox(height: 24),
            _section('De onde vêm (fonte de aquisição)'),
            const SizedBox(height: 8),
            ..._breakdownRows(theme, 'Fonte', sourceBreakdown),
          ],

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

  /// Mini gráfico de barras horizontal de uma série temporal (barra
  /// proporcional ao pico da janela). Usado por novos usuários e north star.
  List<Widget> _timeSeriesRows(
    ThemeData t,
    List<Map<String, dynamic>> data,
    String dayKey,
    String valKey,
    Color color, {
    String Function(String)? labelFmt,
    String Function(double)? valueFmt,
  }) {
    final maxV = data.fold<double>(0, (m, d) {
      final v = (d[valKey] as num?)?.toDouble() ?? 0;
      return v > m ? v : m;
    });
    return data.map((d) {
      final rawDay = d[dayKey] as String? ?? '';
      final label = labelFmt != null ? labelFmt(rawDay) : rawDay;
      final v = (d[valKey] as num?)?.toDouble() ?? 0;
      final valStr = valueFmt != null
          ? valueFmt(v)
          : (v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1));
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          SizedBox(width: 90, child: Text(label, style: t.textTheme.bodySmall)),
          Expanded(
            child: LinearProgressIndicator(
              value: maxV > 0 ? v / maxV : 0,
              minHeight: 14,
              borderRadius: BorderRadius.circular(4),
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Text(valStr, style: t.textTheme.bodySmall),
        ]),
      );
    }).toList();
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

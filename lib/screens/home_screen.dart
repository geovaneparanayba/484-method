import 'package:flutter/material.dart';

import '../data/fase1.dart';
import '../models/lesson.dart';
import '../services/analytics_service.dart';
import '../services/entitlement_service.dart';
import '../services/progress_store.dart';
import '../services/pronunciation_assessor.dart';
import '../services/backend.dart';
import 'lesson_screen.dart';
import 'paywall_screen.dart';
import 'privacy_policy_screen.dart';
import 'stats_screen.dart';

/// Dashboard: a barra das 484 horas, o streak e a porta de entrada das
/// lições. É a tela que o aluno vê todo dia — precisa mostrar progresso
/// real em segundos, não conclusão de telas.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.store,
    required this.entitlement,
    required this.assessor,
    this.analytics,
    this.onDataCleared,
    this.autostartFirstLesson = false,
  });

  final ProgressStore store;
  final EntitlementService entitlement;
  final PronunciationAssessor assessor;
  final AnalyticsService? analytics;

  /// Chamado após a exclusão de dados (o app volta ao onboarding).
  final VoidCallback? onDataCleared;

  /// Logo após o onboarding: abre a 1ª lição automaticamente (conserto do
  /// funil consentimento→1ª lição), em vez de deixar o novato na dashboard.
  final bool autostartFirstLesson;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Conserto do funil: quem acabou de consentir entra direto na 1ª lição,
    // em vez de cair na dashboard vazia ("0 de 484h" assusta e não tem CTA).
    // Só no 1º acesso (progresso zero); initState roda 1x, sem repetir.
    if (widget.autostartFirstLesson &&
        widget.store.totalApproved == Duration.zero) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openLesson(fase1Lessons.first);
      });
    }
  }

  Future<void> _confirmClearData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apagar todos os seus dados?'),
        content: const Text(
            'Progresso, streak, lições concluídas e o consentimento de '
            'gravação serão apagados deste dispositivo e da nuvem. Essa '
            'ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Apagar tudo'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.store.clearAll();
    widget.onDataCleared?.call();
  }

  /// Abre a oferta Beta Fundador. A compra real (RevenueCat) só existe no
  /// mobile; aqui o CTA anuncia a disponibilidade, e o menu de dev libera o
  /// acesso para teste na web.
  void _openPaywall() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PaywallScreen(
        analytics: widget.analytics,
        onSubscribe: () => showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Em breve'),
            content: const Text(
                'A assinatura Beta Fundador entra quando o app chegar à '
                'App Store. Obrigado por querer fazer parte desde o começo!'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Entendi'),
              ),
            ],
          ),
        ),
      ),
    ));
  }

  void _openPrivacyPolicy() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const PrivacyPolicyScreen(),
    ));
  }

  Future<void> _openStats() async {
    final backend = Backend.instance;
    if (backend == null) return;
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
    if (ok != true) return;
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          StatsScreen(backend: backend, password: controller.text),
    ));
  }

  /// Alterna o acesso na implementação fake (web/dev) para testar os dois
  /// estados do gating sem loja. Some quando a impl real (RevenueCat) entrar.
  Future<void> _toggleFounderAccess() async {
    await widget.entitlement
        .setFounderAccess(!widget.entitlement.hasFounderAccess);
    if (mounted) setState(() {});
  }

  /// Explica o efeito antes de ligar: o critério mais rígido vale para
  /// qualquer tentativa a partir de agora (lições já concluídas continuam
  /// concluídas, mas refazê-las ou seguir adiante usa o novo critério) —
  /// sem isso, a mesma pronúncia passar antes e reprovar depois confunde.
  Future<bool> _confirmEnableRigorous() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ativar modo desafio?'),
        content: const Text(
            'A partir de agora, toda gravação — inclusive em lições que '
            'você já concluiu, se refizer — só é aprovada com pronúncia '
            'bem próxima da nativa. O que já está concluído continua '
            'concluído; só o critério das próximas tentativas muda.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Ativar'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _openLesson(Lesson lesson) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => LessonScreen(
        lesson: lesson,
        assessor: widget.assessor,
        store: widget.store,
        analytics: widget.analytics,
        rigorous: widget.store.rigorousMode,
      ),
    ));
    setState(() {}); // progresso pode ter mudado
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = widget.store.totalApproved;
    return Scaffold(
      appBar: AppBar(
        title: const Text('484 Method'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'clear') _confirmClearData();
              if (v == 'toggle_founder') _toggleFounderAccess();
              if (v == 'privacy') _openPrivacyPolicy();
              if (v == 'stats') _openStats();
            },
            itemBuilder: (_) => [
              if (Backend.instance != null)
                const PopupMenuItem(
                  value: 'stats',
                  child: Text('Painel de uso'),
                ),
              const PopupMenuItem(
                value: 'privacy',
                child: Text('Política de privacidade'),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Text('Apagar meus dados'),
              ),
            ],
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (total.inSeconds == 0) ...[
                Card(
                  color: theme.colorScheme.secondaryContainer,
                  child: InkWell(
                    onTap: () => _openLesson(fase1Lessons.first),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Comece sua primeira lição',
                                    style: theme.textTheme.titleMedium),
                                const SizedBox(height: 4),
                                Text(
                                    'Ouça, repita e receba seu retorno em '
                                    '~5 minutos.',
                                    style: theme.textTheme.bodyMedium),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.play_circle_fill,
                              size: 40, color: theme.colorScheme.secondary),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sua jornada de 484 horas',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: widget.store.goalFraction,
                        minHeight: 12,
                        borderRadius: BorderRadius.circular(6),
                        color: theme.colorScheme.secondary,
                        backgroundColor: theme.colorScheme.secondary.withValues(alpha: 0.15),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        total.inSeconds > 0
                            ? '${_format(total)} de treino aprovado'
                            : 'Comece o primeiro treino hoje.',
                        style: theme.textTheme.bodyLarge,
                      ),
                      if (widget.store.streakDays > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          '🔥 ${widget.store.streakDays} '
                          '${widget.store.streakDays == 1 ? "dia" : "dias"} seguidos',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: SwitchListTile(
                  value: widget.store.rigorousMode,
                  onChanged: (v) async {
                    if (v && !await _confirmEnableRigorous()) return;
                    await widget.store.setRigorousMode(v);
                    setState(() {});
                  },
                  title: const Text('Modo desafio'),
                  subtitle: const Text(
                      'Só aprova com pronúncia bem próxima da nativa — '
                      'vale para qualquer tentativa a partir de agora.'),
                  secondary: const Icon(Icons.fitness_center),
                ),
              ),
              const SizedBox(height: 16),
              Text('Fase 1 — Inglês que Você Já Conhece',
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              // Dois gates: o de pagamento (lições além das grátis exigem
              // Beta Fundador) e o progressivo (a lição N abre quando a N-1
              // foi concluída; a primeira está sempre aberta).
              for (final (i, lesson) in fase1Lessons.indexed) ...[
                if (i == 0 || i == 6 || i == 11 || i == 18)
                  Padding(
                    padding: EdgeInsets.only(top: i == 0 ? 0 : 16, bottom: 4),
                    child: Text(
                      switch (i) {
                        0 => 'Bloco 1 — Reconhecimento e confiança',
                        6 => 'Bloco 2 — Som e sílaba forte',
                        11 => 'Bloco 3 — Da palavra à frase',
                        _ => 'Bloco 4 — Conversa do dia a dia',
                      },
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                Builder(builder: (context) {
                  final completed =
                      widget.store.isLessonCompleted(lesson.id);
                  final paywalled = i >= kFreeLessonCount &&
                      !widget.entitlement.hasFounderAccess;
                  // O pré-requisito é a lição anterior NÃO bônus — lições
                  // bônus nunca bloqueiam (nem precisam de) progressão.
                  int prereq = i - 1;
                  while (prereq >= 0 && fase1Lessons[prereq].bonus) {
                    prereq--;
                  }
                  final progressionUnlocked = prereq < 0 ||
                      widget.store.isLessonCompleted(fase1Lessons[prereq].id);
                  final unlocked = !paywalled && progressionUnlocked;
                  final String subtitle;
                  if (paywalled) {
                    subtitle = 'Beta Fundador';
                  } else if (!progressionUnlocked) {
                    subtitle = 'Conclua a lição anterior para desbloquear';
                  } else if (lesson.bonus) {
                    subtitle =
                        'Bônus opcional · ${lesson.items.length} palavras · ~5 min';
                  } else {
                    subtitle = '${lesson.items.length} palavras · ~5 min';
                  }
                  final IconData trailing;
                  if (paywalled) {
                    trailing = Icons.workspace_premium_outlined;
                  } else if (!progressionUnlocked) {
                    trailing = Icons.lock_outline;
                  } else {
                    trailing = completed ? Icons.replay : Icons.play_arrow;
                  }
                  return Card(
                    child: ListTile(
                      // Paywalled fica tocável para mostrar o aviso do gate.
                      enabled: unlocked || paywalled,
                      leading: CircleAvatar(
                        backgroundColor: completed
                            ? theme.colorScheme.secondary.withValues(alpha: 0.18)
                            : theme.colorScheme.surfaceContainerHighest,
                        foregroundColor: completed
                            ? theme.colorScheme.secondary
                            : theme.colorScheme.onSurface,
                        child: completed
                            ? const Icon(Icons.check, size: 20)
                            : Text('${i + 1}'),
                      ),
                      title: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(child: Text(lesson.title)),
                          if (lesson.bonus) ...[
                            const SizedBox(width: 6),
                            Icon(Icons.star,
                                size: 16, color: theme.colorScheme.secondary),
                          ],
                        ],
                      ),
                      subtitle: Text(subtitle),
                      trailing: Icon(trailing),
                      onTap: paywalled
                          ? _openPaywall
                          : unlocked
                              ? () => _openLesson(lesson)
                              : null,
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _format(Duration d) {
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}min';
    if (d.inMinutes > 0) return '${d.inMinutes}min ${d.inSeconds % 60}s';
    return '${d.inSeconds}s';
  }
}

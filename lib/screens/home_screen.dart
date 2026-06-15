import 'package:flutter/material.dart';

import '../data/fase1.dart';
import '../models/lesson.dart';
import '../services/analytics_service.dart';
import '../services/progress_store.dart';
import '../services/pronunciation_assessor.dart';
import 'lesson_screen.dart';
import 'practice_screen.dart';

/// Dashboard: a barra das 484 horas, o streak e a porta de entrada das
/// lições. É a tela que o aluno vê todo dia — precisa mostrar progresso
/// real em segundos, não conclusão de telas.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.store,
    required this.assessor,
    this.analytics,
    this.onDataCleared,
  });

  final ProgressStore store;
  final PronunciationAssessor assessor;
  final AnalyticsService? analytics;

  /// Chamado após a exclusão de dados (o app volta ao onboarding).
  final VoidCallback? onDataCleared;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<void> _confirmClearData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apagar todos os seus dados?'),
        content: const Text(
            'Progresso, streak, lições concluídas e o consentimento de '
            'gravação serão apagados deste dispositivo. Essa ação não '
            'pode ser desfeita.'),
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
          IconButton(
            tooltip: 'Bancada de testes',
            icon: const Icon(Icons.science_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => PracticeScreen(assessor: widget.assessor),
            )),
          ),
          PopupMenuButton<String>(
            onSelected: (_) => _confirmClearData(),
            itemBuilder: (_) => const [
              PopupMenuItem(
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
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${_format(total)} de treino aprovado',
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.store.streakDays > 0
                            ? '🔥 ${widget.store.streakDays} '
                                '${widget.store.streakDays == 1 ? "dia" : "dias"} seguidos'
                            : 'Pratique hoje para começar seu streak.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: SwitchListTile(
                  value: widget.store.rigorousMode,
                  onChanged: (v) async {
                    await widget.store.setRigorousMode(v);
                    setState(() {});
                  },
                  title: const Text('Modo desafio'),
                  subtitle: const Text(
                      'Só aprova com pronúncia bem próxima da nativa. '
                      'Mais difícil, para quem quer cobrança.'),
                  secondary: const Icon(Icons.fitness_center),
                ),
              ),
              const SizedBox(height: 16),
              Text('Fase 1 — Inglês que Você Já Conhece',
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              // Desbloqueio progressivo: a lição N abre quando a N-1 foi
              // concluída (a primeira está sempre aberta).
              for (final (i, lesson) in fase1Lessons.indexed)
                Builder(builder: (context) {
                  final completed =
                      widget.store.isLessonCompleted(lesson.id);
                  final unlocked = i == 0 ||
                      widget.store
                          .isLessonCompleted(fase1Lessons[i - 1].id);
                  return Card(
                    child: ListTile(
                      enabled: unlocked,
                      leading: CircleAvatar(
                        backgroundColor: completed
                            ? Colors.green.shade100
                            : null,
                        child: completed
                            ? const Icon(Icons.check, color: Colors.green)
                            : Text('${i + 1}'),
                      ),
                      title: Text(lesson.title),
                      subtitle: Text(unlocked
                          ? '${lesson.items.length} palavras · ~5 min'
                          : 'Conclua a lição anterior para desbloquear'),
                      trailing: Icon(unlocked
                          ? (completed ? Icons.replay : Icons.play_arrow)
                          : Icons.lock_outline),
                      onTap: unlocked ? () => _openLesson(lesson) : null,
                    ),
                  );
                }),
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

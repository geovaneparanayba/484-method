import 'package:flutter/material.dart';

import '../data/fase1.dart';
import '../models/lesson.dart';
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
  });

  final ProgressStore store;
  final PronunciationAssessor assessor;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<void> _openLesson(Lesson lesson) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => LessonScreen(
        lesson: lesson,
        assessor: widget.assessor,
        store: widget.store,
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
                        '${_format(total)} de prática aprovada',
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

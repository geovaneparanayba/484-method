import 'package:flutter/material.dart';

import '../data/fase1.dart';
import '../services/analytics_service.dart';
import '../services/progress_store.dart';

/// Escala de autoconfiança pra falar inglês (1–5). É o par SUBJETIVO do
/// antes/depois do desafio de 21 dias: medimos no começo e no fim pra ver se
/// a pessoa PERCEBE melhora. O par objetivo (gravação com nota) é a fatia
/// seguinte (precisa de gravação longa + storage + rating cego).
const List<(int, String, String)> kConfidenceScale = [
  (1, '😰', 'Travo, não consigo falar'),
  (2, '😟', 'Falo com muita dificuldade'),
  (3, '😐', 'Me viro no básico'),
  (4, '🙂', 'Falo com alguma segurança'),
  (5, '😎', 'Falo com tranquilidade'),
];

String _confidenceLabel(int? score) {
  for (final (value, _, label) in kConfidenceScale) {
    if (value == score) return label;
  }
  return '—';
}

/// Pergunta a autoconfiança (1–5) num bottom sheet. Devolve o valor escolhido
/// ou null se a pessoa fechou sem responder.
Future<int?> showConfidenceSurvey(
  BuildContext context, {
  required String title,
  required String question,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(question, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 16),
              for (final (value, emoji, label) in kConfidenceScale)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(value),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Text(emoji, style: const TextStyle(fontSize: 22)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(label,
                                textAlign: TextAlign.left,
                                style: theme.textTheme.bodyLarge),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

/// Antes/depois do desafio de 21 dias: junta o delta de confiança (subjetivo)
/// com os dados de prática que já rastreamos (minutos aprovados, lições
/// concluídas). Também pede um depoimento — o sinal de outcome mais forte pra
/// o beta (memo §18). O par objetivo por gravação entra na próxima fatia.
class CohortReviewScreen extends StatefulWidget {
  const CohortReviewScreen({
    super.key,
    required this.store,
    this.analytics,
  });

  final ProgressStore store;
  final AnalyticsService? analytics;

  @override
  State<CohortReviewScreen> createState() => _CohortReviewScreenState();
}

class _CohortReviewScreenState extends State<CohortReviewScreen> {
  final _testimonialController = TextEditingController();
  bool _testimonialSent = false;

  @override
  void initState() {
    super.initState();
    final before = widget.store.baselineConfidence;
    final after = widget.store.finalConfidence;
    widget.analytics?.log('before_after_review_completed', {
      'confidence_before': before,
      'confidence_after': after,
      'confidence_delta': (before != null && after != null)
          ? after - before
          : null,
      'approved_seconds': widget.store.totalApproved.inSeconds,
      'cohort_day': widget.store.cohortDay,
    });
  }

  @override
  void dispose() {
    _testimonialController.dispose();
    super.dispose();
  }

  void _sendTestimonial() {
    final text = _testimonialController.text.trim();
    if (text.isEmpty) return;
    widget.analytics?.log('testimonial_submitted', {
      'text': text,
      'confidence_after': widget.store.finalConfidence,
    });
    setState(() => _testimonialSent = true);
  }

  int _completedLessonCount() {
    var n = 0;
    for (final l in fase1Lessons) {
      if (widget.store.isLessonCompleted(l.id)) n++;
    }
    return n;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final before = widget.store.baselineConfidence;
    final after = widget.store.finalConfidence;
    final delta = (before != null && after != null) ? after - before : 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Seu antes e depois')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text('21 dias depois',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                delta > 0
                    ? 'Sua confiança pra falar subiu. Veja o caminho que você fez.'
                    : 'Veja o caminho que você fez nesses dias.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              _confidenceCard(theme, before, after, delta),
              const SizedBox(height: 12),
              _practiceCard(theme),
              const SizedBox(height: 20),
              _testimonialCard(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _confidenceCard(ThemeData theme, int? before, int? after, int delta) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Como você se sente falando inglês',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            _confidenceRow(theme, 'No começo', before),
            const SizedBox(height: 8),
            _confidenceRow(theme, 'Agora', after),
            if (delta > 0) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.trending_up, color: theme.colorScheme.secondary),
                  const SizedBox(width: 8),
                  Text('+$delta ${delta == 1 ? "nível" : "níveis"} de confiança',
                      style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.secondary,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _confidenceRow(ThemeData theme, String when, int? score) {
    return Row(
      children: [
        SizedBox(
            width: 80,
            child: Text(when, style: theme.textTheme.bodySmall)),
        Expanded(
          child: Text(_confidenceLabel(score),
              style: theme.textTheme.bodyLarge),
        ),
      ],
    );
  }

  Widget _practiceCard(ThemeData theme) {
    final total = widget.store.totalApproved;
    final minutes = total.inMinutes;
    final lessons = _completedLessonCount();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('O que você treinou', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            _statRow(theme, Icons.mic, '$minutes',
                minutes == 1 ? 'minuto de fala aprovada' : 'minutos de fala aprovada'),
            const SizedBox(height: 8),
            _statRow(theme, Icons.check_circle_outline, '$lessons',
                lessons == 1 ? 'lição concluída' : 'lições concluídas'),
          ],
        ),
      ),
    );
  }

  Widget _statRow(ThemeData theme, IconData icon, String value, String label) {
    return Row(
      children: [
        Icon(icon, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Text(value,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
      ],
    );
  }

  Widget _testimonialCard(ThemeData theme) {
    if (_testimonialSent) {
      return Card(
        color: theme.colorScheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Icon(Icons.favorite, color: theme.colorScheme.secondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Obrigado! Seu relato ajuda a construir o 484.',
                  style: theme.textTheme.bodyMedium),
            ),
          ]),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Conta pra gente', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('O que mudou na sua fala nesses 21 dias?',
                style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _testimonialController,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Seu relato em uma ou duas frases…',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _sendTestimonial,
              child: const Text('Enviar depoimento'),
            ),
          ],
        ),
      ),
    );
  }
}

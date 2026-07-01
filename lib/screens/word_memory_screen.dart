import 'package:flutter/material.dart';

import '../services/backend.dart';

/// Categoria do ponto de fala a revisar — derivada de dado real (o app só
/// mede pronúncia/accuracy e ritmo/prosódia; não há sinal pra "estrutura de
/// frase" ou "tradução mental", então essas não viram categorias falsas).
enum SpeechCategory { pronunciation, rhythm }

/// Estatística por palavra no mapa de fala: melhor accuracy, tentativas, se já
/// foi dominada (aprovada alguma vez) e, quando a revisar, qual a dimensão
/// fraca (pronúncia x ritmo).
class WordStat {
  const WordStat({
    required this.word,
    required this.attempts,
    required this.bestAccuracy,
    required this.mastered,
    required this.category,
  });

  final String word;
  final int attempts;
  final double bestAccuracy;
  final bool mastered;
  final SpeechCategory category;
}

/// Agrega as tentativas (`attempt_assessed`) do usuário. "A revisar" = nunca
/// aprovadas (pior accuracy primeiro), categorizadas por dimensão fraca:
/// ritmo quando a prosódia é o ponto baixo, senão pronúncia. "Dominadas" =
/// aprovadas alguma vez. Função pura — testável sem rede.
({List<WordStat> review, List<WordStat> mastered}) aggregateWordMemory(
    List<Map<String, dynamic>> rows) {
  final byWord = <String, List<Map<String, dynamic>>>{};
  for (final r in rows) {
    final props = r['props'];
    if (props is! Map) continue;
    final word = props['item'];
    if (word is! String || word.isEmpty) continue;
    byWord.putIfAbsent(word, () => []).add(props.cast<String, dynamic>());
  }

  final stats = <WordStat>[];
  byWord.forEach((word, attempts) {
    var bestAcc = 0.0;
    double? bestPros;
    var mastered = false;
    for (final a in attempts) {
      final acc = (a['accuracy'] as num?)?.toDouble() ?? 0;
      if (acc > bestAcc) bestAcc = acc;
      final pros = (a['prosody'] as num?)?.toDouble();
      if (pros != null && (bestPros == null || pros > bestPros)) bestPros = pros;
      if (a['approved'] == true) mastered = true;
    }
    // Ritmo só quando a prosódia é claramente o elo fraco (e há dado dela).
    final isRhythm =
        bestPros != null && bestPros < 75 && bestPros < bestAcc;
    stats.add(WordStat(
      word: word,
      attempts: attempts.length,
      bestAccuracy: bestAcc,
      mastered: mastered,
      category:
          isRhythm ? SpeechCategory.rhythm : SpeechCategory.pronunciation,
    ));
  });

  final review = stats.where((s) => !s.mastered).toList()
    ..sort((a, b) => a.bestAccuracy.compareTo(b.bestAccuracy));
  final mastered = stats.where((s) => s.mastered).toList()
    ..sort((a, b) => b.bestAccuracy.compareTo(a.bestAccuracy));
  return (review: review, mastered: mastered);
}

/// "Meu mapa de fala": a memória de fala do aluno — onde ele trava (por
/// pronúncia ou ritmo) e o que já domina, a partir do histórico de tentativas.
/// Read-only; as palavras já passaram do Livro Aberto, então exibi-las não
/// fere o princípio som-first.
class WordMemoryScreen extends StatefulWidget {
  const WordMemoryScreen({super.key, this.onReviewWord});

  /// Chamado ao tocar num ponto "a revisar" → abre o treino daquela palavra.
  final void Function(String word)? onReviewWord;

  @override
  State<WordMemoryScreen> createState() => _WordMemoryScreenState();
}

class _WordMemoryScreenState extends State<WordMemoryScreen> {
  late final Future<List<Map<String, dynamic>>> _future =
      Backend.instance?.fetchAttemptHistory() ?? Future.value(const []);

  Color _colorFor(double accuracy) {
    if (accuracy >= 80) return Colors.green.shade600;
    if (accuracy >= 60) return Colors.orange.shade700;
    return Colors.red.shade600;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Meu mapa de fala')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final mem = aggregateWordMemory(snap.data ?? const []);
          if (mem.review.isEmpty && mem.mastered.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Faça alguns treinos e seu mapa de fala aparece aqui — '
                  'onde você trava (pronúncia, ritmo) e o que já domina.',
                  style: theme.textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final pron = mem.review
              .where((s) => s.category == SpeechCategory.pronunciation)
              .toList();
          final rhythm = mem.review
              .where((s) => s.category == SpeechCategory.rhythm)
              .toList();
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    'Onde você trava na fala — e o que já domina.',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  ..._section(theme, 'Pronúncia a revisar', pron),
                  ..._section(theme, 'Ritmo a revisar', rhythm),
                  ..._section(theme, 'Palavras dominadas', mem.mastered),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _section(ThemeData theme, String label, List<WordStat> items) {
    if (items.isEmpty) return const [];
    return [
      Text('$label (${items.length})',
          style: theme.textTheme.titleMedium
              ?.copyWith(color: theme.colorScheme.secondary)),
      const SizedBox(height: 8),
      for (final s in items) _wordTile(theme, s),
      const SizedBox(height: 24),
    ];
  }

  Widget _wordTile(ThemeData theme, WordStat s) {
    final color = _colorFor(s.bestAccuracy);
    final canReview = !s.mastered && widget.onReviewWord != null;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(s.mastered ? Icons.check : Icons.refresh,
              color: color, size: 20),
        ),
        title: Text(s.word),
        subtitle: Text(canReview
            ? 'Toque para treinar de novo'
            : '${s.attempts} ${s.attempts == 1 ? "tentativa" : "tentativas"}'),
        trailing: Text(
          '${s.bestAccuracy.round()}',
          style: theme.textTheme.titleMedium
              ?.copyWith(color: color, fontWeight: FontWeight.bold),
        ),
        onTap: canReview ? () => widget.onReviewWord!(s.word) : null,
      ),
    );
  }
}

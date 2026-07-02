import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../services/backend.dart';

/// Rating CEGO das gravações do desafio de 21 dias (painel do dev). O
/// avaliador ouve as falas em ordem embaralhada, SEM saber se é do início
/// (baseline) ou do fim (final), e dá uma nota de clareza 1–5. A comparação
/// antes/depois é calculada depois, juntando a nota com o `kind` guardado —
/// assim a expectativa "tem que ter melhorado" não enviesa a nota.
///
/// URLs assinadas e escrita das notas passam pela Edge Function `dev-stats`
/// (service role + gate de senha) — ver Backend.fetchCohortRecordings/saveCohortRating.
class CohortRatingScreen extends StatefulWidget {
  const CohortRatingScreen({
    super.key,
    required this.backend,
    required this.password,
  });

  final Backend backend;
  final String password;

  @override
  State<CohortRatingScreen> createState() => _CohortRatingScreenState();
}

class _CohortRatingScreenState extends State<CohortRatingScreen> {
  final AudioPlayer _player = AudioPlayer();
  List<Map<String, dynamic>> _recordings = [];
  bool _loading = true;
  String? _error;
  String? _playingId;
  String? _savingId;

  @override
  void initState() {
    super.initState();
    _load();
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playingId = null);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final recs = await widget.backend.fetchCohortRecordings(widget.password);
      // Embaralha 1x pra ordem não denunciar baseline vs final (o cego real).
      recs.shuffle();
      if (!mounted) return;
      setState(() {
        _recordings = recs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _togglePlay(Map<String, dynamic> rec) async {
    final id = rec['id'] as String;
    final url = rec['url'] as String?;
    if (url == null) return;
    if (_playingId == id) {
      await _player.stop();
      if (mounted) setState(() => _playingId = null);
      return;
    }
    await _player.stop();
    setState(() => _playingId = id);
    try {
      await _player.play(UrlSource(url));
    } catch (_) {
      if (mounted) setState(() => _playingId = null);
    }
  }

  Future<void> _rate(Map<String, dynamic> rec, int score) async {
    final id = rec['id'] as String;
    setState(() => _savingId = id);
    try {
      await widget.backend.saveCohortRating(widget.password, id, score, null);
      if (!mounted) return;
      setState(() => rec['score'] = score); // atualiza local; sai da fila
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Falha ao salvar: $e')));
    } finally {
      if (mounted) setState(() => _savingId = null);
    }
  }

  double? _avgFor(String kind) {
    final scores = [
      for (final r in _recordings)
        if (r['kind'] == kind && r['score'] != null) (r['score'] as num),
    ];
    if (scores.isEmpty) return null;
    return scores.reduce((a, b) => a + b) / scores.length;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pending = [for (final r in _recordings) if (r['score'] == null) r];
    final rated = [for (final r in _recordings) if (r['score'] != null) r];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rating cego de fala'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Erro: $_error')))
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 700),
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        _summaryCard(theme, rated.length),
                        const SizedBox(height: 16),
                        if (_recordings.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Nenhuma gravação ainda. Elas aparecem quando '
                              'alguém grava o baseline ou o final do desafio.',
                              style: theme.textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        if (pending.isNotEmpty) ...[
                          Text('Para avaliar (${pending.length})',
                              style: theme.textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text(
                            'Ouça e dê a nota de clareza da fala. Você não sabe '
                            'se é do início ou do fim — de propósito.',
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 8),
                          for (final (i, rec) in pending.indexed)
                            _pendingRow(theme, rec, i + 1),
                        ],
                        if (rated.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text('Já avaliadas (${rated.length})',
                              style: theme.textTheme.titleMedium),
                          const SizedBox(height: 8),
                          for (final (i, rec) in rated.indexed)
                            _ratedRow(theme, rec, i + 1),
                        ],
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _summaryCard(ThemeData theme, int ratedCount) {
    final before = _avgFor('baseline');
    final after = _avgFor('final');
    final baselineTotal =
        _recordings.where((r) => r['kind'] == 'baseline').length;
    final finalTotal = _recordings.where((r) => r['kind'] == 'final').length;
    String fmt(double? v) => v == null ? '—' : v.toStringAsFixed(1);
    final delta = (before != null && after != null) ? after - before : null;
    return Card(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Antes/depois (nota cega de clareza)',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Início (baseline): ${fmt(before)}   ·   '
                'Fim (final): ${fmt(after)}',
                style: theme.textTheme.bodyLarge),
            if (delta != null) ...[
              const SizedBox(height: 4),
              Text(
                delta > 0
                    ? 'Melhora média de +${delta.toStringAsFixed(1)} ponto(s).'
                    : delta == 0
                        ? 'Sem diferença média até agora.'
                        : 'Queda média de ${delta.toStringAsFixed(1)} ponto(s).',
                style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: delta > 0 ? theme.colorScheme.primary : null),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              '$baselineTotal baseline · $finalTotal final · '
              '$ratedCount avaliada(s)',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pendingRow(ThemeData theme, Map<String, dynamic> rec, int n) {
    final id = rec['id'] as String;
    final ms = (rec['duration_ms'] as num?)?.toInt() ?? 0;
    final secs = (ms / 1000).round();
    final hasUrl = rec['url'] != null;
    final saving = _savingId == id;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton.filledTonal(
                  onPressed: hasUrl ? () => _togglePlay(rec) : null,
                  icon: Icon(_playingId == id ? Icons.stop : Icons.play_arrow),
                ),
                const SizedBox(width: 8),
                Text('Áudio $n · ${secs}s',
                    style: theme.textTheme.titleSmall),
                if (!hasUrl) ...[
                  const SizedBox(width: 8),
                  Text('(áudio indisponível)',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.error)),
                ],
              ],
            ),
            const SizedBox(height: 8),
            saving
                ? const Padding(
                    padding: EdgeInsets.all(8),
                    child: SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (var s = 1; s <= 5; s++)
                        OutlinedButton(
                          onPressed: () => _rate(rec, s),
                          child: Text('$s'),
                        ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  Widget _ratedRow(ThemeData theme, Map<String, dynamic> rec, int n) {
    final id = rec['id'] as String;
    final ms = (rec['duration_ms'] as num?)?.toInt() ?? 0;
    final secs = (ms / 1000).round();
    final score = (rec['score'] as num).toInt();
    return Card(
      child: ListTile(
        leading: IconButton(
          onPressed: rec['url'] != null ? () => _togglePlay(rec) : null,
          icon: Icon(_playingId == id ? Icons.stop : Icons.play_arrow),
        ),
        title: Text('Áudio $n · ${secs}s'),
        subtitle: Text('Nota: $score'),
        trailing: Wrap(
          spacing: 2,
          children: [
            for (var s = 1; s <= 5; s++)
              InkWell(
                onTap: () => _rate(rec, s),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Icon(
                    s <= score ? Icons.star : Icons.star_border,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

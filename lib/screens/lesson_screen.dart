import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../models/lesson.dart';
import '../services/analytics_service.dart';
import '../services/audio_recorder_service.dart';
import '../services/backend.dart';
import '../services/feedback_messages.dart';
import '../services/progress_store.dart';
import '../services/pronunciation_assessor.dart';

/// Fluxo som-first de uma microlição (template de 8 etapas do método):
/// ouvir sem texto → repetir de ouvido → feedback → Livro Aberto →
/// regravação final → minutos aprovados.
///
/// Regra inegociável: o texto da palavra NUNCA aparece antes da primeira
/// tentativa oral avaliada.
class LessonScreen extends StatefulWidget {
  const LessonScreen({
    super.key,
    required this.lesson,
    required this.assessor,
    this.store,
    this.analytics,
    this.rigorous = false,
  });

  final Lesson lesson;
  final PronunciationAssessor assessor;

  /// Modo desafio: aprovação exige pronúncia próxima da nativa.
  final bool rigorous;

  /// Quando presente, o tempo aprovado é persistido (barra das 484h).
  final ProgressStore? store;

  final AnalyticsService? analytics;

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

enum _Step {
  intro,
  listen, // áudio sem texto + 1ª gravação
  feedbackFirst,
  livroAberto, // texto liberado + regravação final
  resultFinal,
  finished,
}

enum _RecPhase { idle, preparing, recording, sending }

class _LessonScreenState extends State<LessonScreen> {
  final AudioRecorderService _recorder = AudioRecorderService();
  AudioPlayer? _player;

  var _step = _Step.intro;
  var _recPhase = _RecPhase.idle;
  int _index = 0;
  bool _hasListened = false;
  PronunciationResult? _result;
  double? _firstAccuracy; // accuracy da 1ª tentativa, p/ medir a melhora
  String? _error;

  /// Feedback gerado pela Claude (Edge Function) para o resultado atual.
  /// null = ainda não chegou (ou indisponível) → usa a mensagem fixa.
  String? _aiFeedback;
  // Invalida respostas atrasadas: só a última tentativa pode setar o texto.
  int _feedbackToken = 0;
  Duration _approved = Duration.zero;
  Duration _audioSent = Duration.zero;

  LessonItem get _item => widget.lesson.items[_index];
  bool get _isLastItem => _index == widget.lesson.items.length - 1;

  @override
  void dispose() {
    _player?.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _play() async {
    // Libera a gravação imediatamente: o destrave da UI não pode depender
    // do ciclo de vida do player (no web, stop/play podem demorar).
    if (!_hasListened) setState(() => _hasListened = true);
    try {
      _player ??= AudioPlayer();
      if (_player!.state == PlayerState.playing) await _player!.stop();
      await _player!.play(AssetSource(_item.audioAsset));
    } catch (e) {
      debugPrint('[licao] falha ao tocar áudio: $e');
      setState(() => _error = 'Não consegui tocar o áudio. Tente de novo.');
    }
  }

  Future<void> _toggleRecording() async {
    switch (_recPhase) {
      case _RecPhase.idle:
        if (!await _recorder.hasPermission()) {
          setState(() => _error = 'Permita o acesso ao microfone.');
          return;
        }
        setState(() {
          _recPhase = _RecPhase.preparing;
          _error = null;
        });
        await _recorder.start(onAutoStop: _stopAndAssess);
        if (mounted && _recPhase == _RecPhase.preparing) {
          setState(() => _recPhase = _RecPhase.recording);
        }
      case _RecPhase.recording:
        await _stopAndAssess();
      case _RecPhase.preparing:
      case _RecPhase.sending:
        break;
    }
  }

  Future<void> _stopAndAssess() async {
    if (_recPhase != _RecPhase.recording) return;
    setState(() => _recPhase = _RecPhase.sending);

    final audio = await _recorder.stop();
    if (audio == null) {
      setState(() {
        _recPhase = _RecPhase.idle;
        _error = 'Não ouvi nada — fale mais perto do microfone.';
      });
      return;
    }

    try {
      final result = await widget.assessor.assess(
        wavAudio: audio.wavBytes,
        referenceText: _item.text,
      );
      final attempt = _step == _Step.listen ? 1 : 2;
      final approved = widget.lesson.approves(
          result.accuracy, result.minPhoneme, result.prosody,
          rigorous: widget.rigorous);
      widget.analytics?.log('attempt_assessed', {
        'lesson': widget.lesson.id,
        'item': _item.text,
        'attempt': attempt,
        'accuracy': result.accuracy,
        'min_phoneme': result.minPhoneme,
        'prosody': result.prosody,
        'approved': approved,
        'audio_seconds': audio.duration.inMilliseconds / 1000,
      });
      setState(() {
        _result = result;
        _aiFeedback = null; // nova tentativa: descarta feedback anterior
        _audioSent += audio.duration;
        _recPhase = _RecPhase.idle;
        if (_step == _Step.listen) {
          _firstAccuracy = result.accuracy;
          _step = _Step.feedbackFirst;
        } else if (_step == _Step.livroAberto) {
          if (approved) {
            _approved += audio.duration;
            widget.store?.addApproved(audio.duration);
          }
          _step = _Step.resultFinal;
        }
      });
      _maybeFetchAiFeedback(result, attempt, approved);
    } catch (e) {
      debugPrint('[licao] avaliação falhou: $e');
      setState(() {
        _audioSent += audio.duration;
        _error = 'Não consegui avaliar sua gravação agora. '
            'Confira sua conexão e grave de novo.';
        _recPhase = _RecPhase.idle;
      });
    }
  }

  /// Mensagem a exibir: a da Claude quando chegou, senão a fixa (fallback
  /// imediato e offline). Mantém a regra de produto mesmo sem rede/chave.
  String _feedbackText(PronunciationResult r) =>
      _aiFeedback ??
      feedbackFor(r, widget.lesson, rigorous: widget.rigorous);

  /// Dispara o feedback da Claude em segundo plano. Só busca quando a
  /// mensagem realmente será mostrada (1ª tentativa sempre; tentativa final
  /// só quando reprovou) — aprovação na final exibe o selo, não o texto.
  void _maybeFetchAiFeedback(
      PronunciationResult r, int attempt, bool approved) {
    final backend = Backend.instance;
    if (backend == null) return; // modo local-only: fica na mensagem fixa
    if (attempt == 2 && approved) return; // texto não aparece → não gasta
    final token = ++_feedbackToken;
    backend.generateFeedback({
      'word': _item.text,
      'attempt': attempt,
      'approved': approved,
      'accuracy': r.accuracy.round(),
      'fluency': r.fluency.round(),
      'completeness': r.completeness.round(),
      'prosody': r.prosody?.round(),
      'minPhoneme': r.minPhoneme.round(),
      'worstSyllable': r.worstSyllable?.grapheme,
    }).then((msg) {
      if (!mounted || token != _feedbackToken || msg == null) return;
      setState(() => _aiFeedback = msg);
    });
  }

  void _nextItem() {
    setState(() {
      if (_isLastItem) {
        _step = _Step.finished;
        widget.store?.markLessonCompleted(widget.lesson.id);
        widget.analytics?.log('lesson_completed', {
          'lesson': widget.lesson.id,
          'approved_seconds': _approved.inSeconds,
          'audio_sent_seconds': _audioSent.inSeconds,
        });
      } else {
        _index++;
        _step = _Step.listen;
        _hasListened = false;
        _result = null;
        _aiFeedback = null;
        _firstAccuracy = null;
        _error = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.lesson.title),
        actions: [
          if (_step != _Step.intro && _step != _Step.finished)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${_index + 1}/${widget.lesson.items.length}',
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildStep(theme)),
                if (_error != null)
                  Card(
                    color: theme.colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(_error!),
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  'Minutos aprovados: ${_formatMin(_approved)} · '
                  'áudio enviado: ${_audioSent.inSeconds}s',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep(ThemeData theme) {
    switch (_step) {
      case _Step.intro:
        return _centered([
          Text('Lição ${widget.lesson.title}',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Text(widget.lesson.objective,
              style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            'Regra do jogo: primeiro você OUVE e repete. '
            'A escrita só aparece depois da sua primeira tentativa.',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              widget.analytics
                  ?.log('lesson_started', {'lesson': widget.lesson.id});
              setState(() => _step = _Step.listen);
            },
            child: const Text('Começar'),
          ),
        ]);

      case _Step.listen:
        return _centered([
          Text('Palavra ${_index + 1}',
              style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('Ouça com atenção — sem ler nada — e repita do seu jeito.',
              style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _play,
            icon: const Icon(Icons.volume_up, size: 32),
            label: const Text('Ouvir'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 20),
            ),
          ),
          const SizedBox(height: 16),
          if (_hasListened) _recordButton(label: 'Repetir (gravar)'),
        ]);

      case _Step.feedbackFirst:
        final r = _result!;
        return _centered([
          Text('Sua primeira tentativa',
              style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          _scoreBadge(theme, r.accuracy),
          const SizedBox(height: 16),
          Text(_feedbackText(r),
              style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => setState(() => _step = _Step.livroAberto),
            icon: const Icon(Icons.menu_book),
            label: const Text('Abrir o Livro — ver a palavra'),
          ),
        ]);

      case _Step.livroAberto:
        return _centered([
          Text(_item.text,
              style: theme.textTheme.displayMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          Text(_item.translation,
              style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                Text(_item.example,
                    style: theme.textTheme.bodyLarge,
                    textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Text(_item.exampleTranslation,
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _play,
            icon: const Icon(Icons.volume_up),
            label: const Text('Ouvir de novo'),
          ),
          const SizedBox(height: 12),
          _recordButton(label: 'Gravação final'),
        ]);

      case _Step.resultFinal:
        final r = _result!;
        final approved =
            widget.lesson.approves(r.accuracy, r.minPhoneme, r.prosody,
                rigorous: widget.rigorous);
        // Melhora da 1ª tentativa (de ouvido) para a final (com apoio):
        // é o que o método chama de "transformar repetição em progresso".
        final gain = _firstAccuracy == null
            ? 0.0
            : r.accuracy - _firstAccuracy!;
        return _centered([
          _scoreBadge(theme, r.accuracy),
          const SizedBox(height: 12),
          // Mapa de sílabas colorido: a escrita já foi liberada no Livro
          // Aberto, então mostrar os grafemas aqui não fere o som-first.
          _SyllableMap(result: r),
          const SizedBox(height: 12),
          if (gain >= 5)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '📈 Você melhorou ${gain.toStringAsFixed(0)} pontos da '
                'primeira tentativa para esta. É exatamente isso que treina '
                'o ouvido.',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
          if (gain >= 5) const SizedBox(height: 12),
          if (!approved)
            Text(_feedbackText(r),
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center),
          Text(
            approved
                ? '✅ Aprovada! Esse tempo conta para as suas 484 horas.'
                : 'Ainda não bateu o critério — mas você concluiu, '
                    'e amanhã ela aparece de novo.',
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _nextItem,
            child: Text(_isLastItem ? 'Concluir lição' : 'Próxima palavra'),
          ),
        ]);

      case _Step.finished:
        return _centered([
          Text('🎉 Lição concluída!',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Text(
            'Você praticou ${widget.lesson.items.length} palavras e somou '
            '${_formatMin(_approved)} de treino aprovado.',
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () => setState(() {
              _index = 0;
              _step = _Step.intro;
              _hasListened = false;
              _result = null;
              _approved = Duration.zero;
            }),
            child: const Text('Praticar de novo'),
          ),
        ]);
    }
  }

  Widget _recordButton({required String label}) {
    return FilledButton.icon(
      onPressed: _recPhase == _RecPhase.sending ||
              _recPhase == _RecPhase.preparing
          ? null
          : _toggleRecording,
      icon: Icon(switch (_recPhase) {
        _RecPhase.idle => Icons.mic,
        _RecPhase.preparing => Icons.hourglass_top,
        _RecPhase.recording => Icons.stop,
        _RecPhase.sending => Icons.hourglass_top,
      }),
      label: Text(switch (_recPhase) {
        _RecPhase.idle => label,
        _RecPhase.preparing => 'Preparando microfone...',
        _RecPhase.recording => 'FALE AGORA — toque para parar',
        _RecPhase.sending => 'Avaliando...',
      }),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 20),
        backgroundColor: _recPhase == _RecPhase.recording ? Colors.red : null,
      ),
    );
  }

  Widget _scoreBadge(ThemeData theme, double score) {
    return Column(children: [
      Text(score.toStringAsFixed(0), style: theme.textTheme.displayMedium),
      LinearProgressIndicator(value: score / 100, minHeight: 8),
    ]);
  }

  Widget _centered(List<Widget> children) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  String _formatMin(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m}min ${s}s';
  }
}

/// Mapa de pronúncia por sílaba: mostra cada pedaço da palavra colorido
/// pela accuracy (verde = nativo, amarelo = quase, vermelho = som de
/// português). Torna visível ONDE o som falhou, não só a nota geral.
class _SyllableMap extends StatelessWidget {
  const _SyllableMap({required this.result});

  final PronunciationResult result;

  static Color _colorFor(double accuracy) {
    if (accuracy >= 80) return Colors.green.shade600;
    if (accuracy >= 60) return Colors.orange.shade700;
    return Colors.red.shade600;
  }

  @override
  Widget build(BuildContext context) {
    final syllables = [
      for (final w in result.words)
        ...w.syllables.where((s) => s.grapheme.isNotEmpty)
    ];
    if (syllables.isEmpty) return const SizedBox.shrink();
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final s in syllables)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _colorFor(s.accuracy).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _colorFor(s.accuracy)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(s.grapheme,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _colorFor(s.accuracy),
                    )),
                Text(s.accuracy.toStringAsFixed(0),
                    style: const TextStyle(fontSize: 11)),
              ],
            ),
          ),
      ],
    );
  }
}

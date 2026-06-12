import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../models/lesson.dart';
import '../services/audio_recorder_service.dart';
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
  });

  final Lesson lesson;
  final PronunciationAssessor assessor;

  /// Quando presente, o tempo aprovado é persistido (barra das 484h).
  final ProgressStore? store;

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
  String? _error;
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
      setState(() => _error = 'Erro ao tocar o áudio: $e');
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
      setState(() {
        _result = result;
        _audioSent += audio.duration;
        _recPhase = _RecPhase.idle;
        if (_step == _Step.listen) {
          _step = _Step.feedbackFirst;
        } else if (_step == _Step.livroAberto) {
          if (result.pronScore >= widget.lesson.approvalThreshold) {
            _approved += audio.duration;
            widget.store?.addApproved(audio.duration);
          }
          _step = _Step.resultFinal;
        }
      });
    } catch (e) {
      setState(() {
        _audioSent += audio.duration;
        _error = '$e';
        _recPhase = _RecPhase.idle;
      });
    }
  }

  void _nextItem() {
    setState(() {
      if (_isLastItem) {
        _step = _Step.finished;
        widget.store?.markLessonCompleted(widget.lesson.id);
      } else {
        _index++;
        _step = _Step.listen;
        _hasListened = false;
        _result = null;
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
            onPressed: () => setState(() => _step = _Step.listen),
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
          _scoreBadge(theme, r.pronScore),
          const SizedBox(height: 16),
          Text(feedbackFor(r, widget.lesson.approvalThreshold),
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
        final approved = r.pronScore >= widget.lesson.approvalThreshold;
        return _centered([
          _scoreBadge(theme, r.pronScore),
          const SizedBox(height: 12),
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
            '${_formatMin(_approved)} de prática aprovada.',
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

import 'package:flutter/material.dart';

import '../services/audio_recorder_service.dart';
import '../services/pronunciation_assessor.dart';

/// Fatia vertical do loop core: palavra-alvo → gravar → Azure → score.
///
/// Esta tela é deliberadamente crua: o objetivo é validar a cadeia técnica
/// (mic no Chrome → WAV → Pronunciation Assessment) e a qualidade do score
/// com voz brasileira, antes de qualquer trabalho de UI ou pedagogia.
class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key, required this.assessor});

  final PronunciationAssessor assessor;

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

enum _Phase { idle, preparing, recording, sending }

class _PracticeScreenState extends State<PracticeScreen> {
  final AudioRecorderService _recorder = AudioRecorderService();

  /// Editável na tela para testar qualquer palavra sem recompilar.
  final TextEditingController _wordController =
      TextEditingController(text: 'apple');

  _Phase _phase = _Phase.idle;
  PronunciationResult? _result;
  String? _error;
  String? _lastDiagnostics;

  /// Total de áudio enviado ao Azure nesta sessão — a métrica de custo.
  Duration _audioSent = Duration.zero;

  @override
  void dispose() {
    _wordController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    switch (_phase) {
      case _Phase.idle:
        if (!await _recorder.hasPermission()) {
          setState(() => _error = 'Permita o acesso ao microfone no navegador.');
          return;
        }
        setState(() {
          _phase = _Phase.preparing;
          _result = null;
          _error = null;
        });
        // start() só retorna quando o áudio está realmente fluindo.
        await _recorder.start(onAutoStop: _stopAndAssess);
        if (mounted && _phase == _Phase.preparing) {
          setState(() => _phase = _Phase.recording);
        }
      case _Phase.recording:
        await _stopAndAssess();
      case _Phase.preparing:
      case _Phase.sending:
        break; // aguarde
    }
  }

  Future<void> _stopAndAssess() async {
    if (_phase != _Phase.recording) return;
    setState(() => _phase = _Phase.sending);

    final audio = await _recorder.stop();
    if (audio == null) {
      setState(() {
        _phase = _Phase.idle;
        _error = 'Não ouvi nada — fale mais perto do microfone. '
            '(Nada foi enviado ao Azure.)';
      });
      return;
    }

    try {
      final result = await widget.assessor.assess(
        wavAudio: audio.wavBytes,
        referenceText: _wordController.text.trim().toLowerCase(),
      );
      setState(() {
        _result = result;
        _audioSent += audio.duration;
        _lastDiagnostics = audio.diagnostics;
        _phase = _Phase.idle;
      });
    } catch (e) {
      setState(() {
        _audioSent += audio.duration;
        _lastDiagnostics = audio.diagnostics;
        _error = '$e';
        _phase = _Phase.idle;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('484 Method — protótipo do loop')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Fale a palavra:', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                TextField(
                  controller: _wordController,
                  enabled: _phase == _Phase.idle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.displayMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'digite a palavra',
                  ),
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: _phase == _Phase.sending ||
                          _phase == _Phase.preparing
                      ? null
                      : _toggleRecording,
                  icon: Icon(switch (_phase) {
                    _Phase.idle => Icons.mic,
                    _Phase.preparing => Icons.hourglass_top,
                    _Phase.recording => Icons.stop,
                    _Phase.sending => Icons.hourglass_top,
                  }),
                  label: Text(switch (_phase) {
                    _Phase.idle => 'Gravar',
                    _Phase.preparing => 'Preparando microfone...',
                    _Phase.recording => 'FALE AGORA — toque para parar',
                    _Phase.sending => 'Avaliando...',
                  }),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    backgroundColor:
                        _phase == _Phase.recording ? Colors.red : null,
                  ),
                ),
                const SizedBox(height: 24),
                if (_error != null)
                  Card(
                    color: theme.colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(_error!),
                    ),
                  ),
                if (_result != null) _ResultCard(result: _result!),
                const Spacer(),
                Text(
                  'Áudio enviado ao Azure nesta sessão: '
                  '${_audioSent.inSeconds}s'
                  '${_lastDiagnostics != null ? '\n$_lastDiagnostics' : ''}',
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
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final PronunciationResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Entendi: "${result.recognizedText}"',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            _scoreRow('Pronúncia (geral)', result.pronScore),
            _scoreRow('Accuracy', result.accuracy),
            _scoreRow('Fluency', result.fluency),
            _scoreRow('Completeness', result.completeness),
            if (result.words.isNotEmpty) ...[
              const Divider(),
              for (final w in result.words)
                Text(
                  '${w.word}: ${w.accuracy.toStringAsFixed(0)}'
                  '${w.errorType != null ? ' (${w.errorType})' : ''}',
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _scoreRow(String label, double score) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 150, child: Text(label)),
          Expanded(
            child: LinearProgressIndicator(value: score / 100, minHeight: 8),
          ),
          SizedBox(
            width: 48,
            child: Text(
              score.toStringAsFixed(0),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

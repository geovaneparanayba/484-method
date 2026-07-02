import 'dart:async';

import 'package:flutter/material.dart';

import '../services/analytics_service.dart';
import '../services/audio_recorder_service.dart';
import '../services/backend.dart';
import '../services/progress_store.dart';

/// Gravação de fala aberta (~30s) do desafio de 21 dias: baseline no começo,
/// final no fim. É o par OBJETIVO do antes/depois — o áudio vai pro Storage
/// privado pra um avaliador cego pontuar depois (o Azure não pontua fala
/// aberta sem texto de referência). Best-effort: se o upload falhar ou a
/// pessoa pular, o desafio segue com a autoavaliação de confiança.
class CohortRecordingScreen extends StatefulWidget {
  const CohortRecordingScreen({
    super.key,
    required this.kind,
    required this.store,
    this.backend,
    this.analytics,
  });

  /// 'baseline' (dia 0) ou 'final' (dia 21).
  final String kind;
  final ProgressStore store;
  final Backend? backend;
  final AnalyticsService? analytics;

  @override
  State<CohortRecordingScreen> createState() => _CohortRecordingScreenState();
}

enum _Phase { intro, preparing, recording, uploading, done, error }

class _CohortRecordingScreenState extends State<CohortRecordingScreen> {
  final AudioRecorderService _recorder = AudioRecorderService.longForm();
  _Phase _phase = _Phase.intro;
  Timer? _ticker;
  int _elapsed = 0;
  String? _error;

  bool get _isBaseline => widget.kind == 'baseline';

  String get _prompt => _isBaseline
      ? 'Fale por ~30 segundos em inglês. Pode ser simples: diga seu nome, o '
          'que você faz, por que quer melhorar seu inglês e uma situação em que '
          'você trava.'
      : 'Fale por ~30 segundos em inglês. Diga o que você praticou, quais '
          'palavras ficaram mais fáceis e como você se sente falando inglês '
          'agora.';

  @override
  void dispose() {
    _ticker?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (!await _recorder.hasPermission()) {
      setState(() {
        _phase = _Phase.error;
        _error = 'Sem acesso ao microfone. Libere o microfone no navegador e '
            'tente de novo.';
      });
      return;
    }
    setState(() {
      _phase = _Phase.preparing;
      _error = null;
    });
    await _recorder.start(onAutoStop: _stopAndUpload);
    if (!mounted || _phase != _Phase.preparing) return;
    setState(() {
      _phase = _Phase.recording;
      _elapsed = 0;
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed++);
    });
  }

  Future<void> _stopAndUpload() async {
    if (_phase != _Phase.recording) return;
    _ticker?.cancel();
    setState(() => _phase = _Phase.uploading);

    final audio = await _recorder.stop();
    if (audio == null) {
      setState(() {
        _phase = _Phase.error;
        _error = 'Não ouvi nada. Fale mais perto do microfone e tente de novo.';
      });
      return;
    }

    final ok = await widget.backend?.uploadCohortRecording(
          kind: widget.kind,
          wavBytes: audio.wavBytes,
          durationMs: audio.duration.inMilliseconds,
          cohortDay: widget.store.cohortDay,
        ) ??
        false;
    widget.analytics?.log('cohort_recording_saved', {
      'kind': widget.kind,
      'uploaded': ok,
      'duration_ms': audio.duration.inMilliseconds,
    });
    if (!mounted) return;
    setState(() => _phase = _Phase.done);
  }

  void _skip() {
    widget.analytics?.log('cohort_recording_skipped', {'kind': widget.kind});
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isBaseline ? 'Sua fala de hoje' : 'Sua fala de agora'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: switch (_phase) {
              _Phase.done => _doneView(theme),
              _ => _recordView(theme),
            },
          ),
        ),
      ),
    );
  }

  Widget _recordView(ThemeData theme) {
    final recording = _phase == _Phase.recording;
    final busy = _phase == _Phase.preparing || _phase == _Phase.uploading;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _isBaseline
              ? 'Antes de começar, registre sua fala de hoje. No fim dos 21 '
                  'dias você grava de novo e compara.'
              : 'Você chegou ao fim! Registre sua fala agora pra ver o quanto '
                  'evoluiu desde o começo.',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        Card(
          color: theme.colorScheme.secondaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(_prompt, style: theme.textTheme.bodyLarge),
          ),
        ),
        const SizedBox(height: 32),
        Icon(
          recording ? Icons.mic : Icons.mic_none,
          size: 72,
          color: recording ? theme.colorScheme.error : theme.colorScheme.primary,
        ),
        const SizedBox(height: 8),
        Text(
          recording
              ? 'Gravando… ${_elapsed}s'
              : busy
                  ? 'Um instante…'
                  : 'Toque para gravar',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.error)),
        ],
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: busy
              ? null
              : recording
                  ? _stopAndUpload
                  : _start,
          icon: Icon(recording ? Icons.stop : Icons.fiber_manual_record),
          label: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(recording ? 'Parar e enviar' : 'Gravar'),
          ),
        ),
        TextButton(
          onPressed: busy ? null : _skip,
          child: const Text('Pular por agora'),
        ),
      ],
    );
  }

  Widget _doneView(ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.check_circle, size: 72, color: theme.colorScheme.secondary),
        const SizedBox(height: 16),
        Text(
          _isBaseline
              ? 'Fala registrada! Agora é treinar todo dia.'
              : 'Fala registrada! Vamos ver seu antes e depois.',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Continuar'),
          ),
        ),
      ],
    );
  }
}

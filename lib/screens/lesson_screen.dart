import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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
    this.startItemIndex,
  });

  final Lesson lesson;
  final PronunciationAssessor assessor;

  /// Modo desafio: aprovação exige pronúncia próxima da nativa.
  final bool rigorous;

  /// Quando presente, o tempo aprovado é persistido (barra das 484h).
  final ProgressStore? store;

  final AnalyticsService? analytics;

  /// Quando presente, começa neste item — usado por "Revisar agora" do mapa
  /// de fala, em vez de retomar o índice salvo.
  final int? startItemIndex;

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

class _LessonScreenState extends State<LessonScreen>
    with SingleTickerProviderStateMixin {
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

  /// Tempo da regravação final quando aprovada — exibido no antes/depois.
  Duration? _lastApprovedDuration;
  /// Duração do áudio enviado na regravação final (microcopy de conclusão).
  Duration? _lastAudioDuration;
  // "Momento Uau": esconde a pergunta de percepção quando já respondida.
  late bool _ahaAnswered = widget.store?.hasAnsweredAha ?? true;

  /// Accuracy final de cada palavra (capturada ao avançar). Usada para
  /// calcular a média exibida na tela de conclusão.
  final List<double> _wordAccuracies = [];

  LessonItem get _item => widget.lesson.items[_index];
  bool get _isLastItem => _index == widget.lesson.items.length - 1;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    // Retoma de onde parou em vez de recomeçar do item 1 — sem isso, quem
    // fecha a lição na metade e volta depois é jogado de volta pro início
    // (achado real: usuários que já tinham passado 3-4 palavras reabriram a
    // lição, caíram na 1ª palavra de novo, reprovaram e desistiram).
    final saved = widget.startItemIndex ??
        widget.store?.itemIndexFor(widget.lesson.id) ??
        0;
    _index = saved.clamp(0, widget.lesson.items.length - 1);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _pulseScale = Tween<double>(begin: 1.0, end: 1.07).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _player?.dispose();
    _recorder.dispose();
    super.dispose();
  }

  /// Dispara um evento de ativação (Fase 0) só na 1ª vez (gating no store).
  /// Sem store (testes) não dispara.
  void _logFirst(String event, [Map<String, Object?> extra = const {}]) {
    if (widget.store?.firstOnce(event) ?? false) {
      widget.analytics?.log(event, {'lesson': widget.lesson.id, ...extra});
    }
  }

  Future<void> _play() async {
    if (_recPhase == _RecPhase.recording || _recPhase == _RecPhase.preparing) return;
    // Libera a gravação imediatamente: o destrave da UI não pode depender
    // do ciclo de vida do player (no web, stop/play podem demorar).
    if (!_hasListened) {
      setState(() => _hasListened = true);
      _logFirst('first_listen_completed');
    }
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
          setState(() => _error =
              'Sem acesso ao microfone. Clique no ícone de cadeado ou '
              'câmera ao lado do endereço do site, permita o microfone e '
              'toque no botão de gravar de novo.');
          return;
        }
        if (_player?.state == PlayerState.playing) await _player!.stop();
        setState(() {
          _recPhase = _RecPhase.preparing;
          _error = null;
        });
        await _recorder.start(onAutoStop: _stopAndAssess);
        if (mounted && _recPhase == _RecPhase.preparing) {
          setState(() => _recPhase = _RecPhase.recording);
          _pulseController.repeat(reverse: true);
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
    _pulseController.stop();
    _pulseController.reset();

    final audio = await _recorder.stop();
    if (audio == null) {
      widget.analytics?.log('recording_discarded_silence', {
        'lesson': widget.lesson.id,
        'item': _item.text,
      });
      setState(() {
        _recPhase = _RecPhase.idle;
        _error = 'Não ouvi nada — fale mais perto do microfone.';
      });
      return;
    }

    // Calcula attempt antes do assess — o servidor precisa para gerar feedback.
    final attempt = _step == _Step.listen ? 1 : 2;
    try {
      final result = await widget.assessor.assess(
        wavAudio: audio.wavBytes,
        referenceText: _item.text,
        attempt: attempt,
      );
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
        _aiFeedback = null;
        _audioSent += audio.duration;
        _recPhase = _RecPhase.idle;
        if (_step == _Step.listen) {
          _firstAccuracy = result.accuracy;
          _step = _Step.feedbackFirst;
        } else if (_step == _Step.livroAberto) {
          _lastAudioDuration = audio.duration;
          if (approved) {
            _approved += audio.duration;
            _lastApprovedDuration = audio.duration;
            widget.store?.addApproved(audio.duration);
          }
          _step = _Step.resultFinal;
        }
      });
      // Eventos de ativação (Fase 0) — só na 1ª vez (gating no store).
      _logFirst('first_recording_completed');
      if (attempt == 1) {
        _logFirst('first_feedback_seen');
      } else {
        _logFirst('first_retry_completed');
        _logFirst('first_before_after_seen');
        if (approved) _logFirst('first_approved_minute_earned');
      }
      _maybeFetchAiFeedback(result, attempt, approved);
    } catch (e) {
      debugPrint('[licao] avaliação falhou: $e');
      widget.analytics?.log('assessment_failed', {
        'lesson': widget.lesson.id,
        'item': _item.text,
        'attempt': attempt,
        'error': e.toString(),
      });
      setState(() {
        _audioSent += audio.duration;
        // PronunciationAssessmentException já distingue erro do servidor
        // (código HTTP) de falha de conexão na própria mensagem; exceções
        // genéricas (sem rede, timeout) caem no texto fixo de conectividade.
        _error = e is PronunciationAssessmentException
            ? e.message
            : 'Não consegui avaliar sua gravação agora. '
                'Confira sua conexão e grave de novo.';
        _recPhase = _RecPhase.idle;
      });
    }
  }

  /// Mensagem a exibir: a da Claude quando chegou, senão a fixa (fallback
  /// imediato e offline). Mantém a regra de produto mesmo sem rede/chave.
  String _feedbackText(PronunciationResult r) =>
      _aiFeedback ?? feedbackFor(r, widget.lesson, rigorous: widget.rigorous);

  /// Dispara o feedback da Claude em segundo plano. Só busca quando a
  /// mensagem realmente será mostrada (1ª tentativa sempre; tentativa final
  /// só quando reprovou) — aprovação na final exibe o selo, não o texto.
  /// Sem backend (modo local) ou acima do teto diário (429), fica na fixa.
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

  /// Regrava a tentativa final: volta ao Livro Aberto (palavra visível, dá
  /// pra ouvir de novo). Mantém _firstAccuracy para a melhora seguir medida
  /// desde a 1ª tentativa de ouvido. Sem prender — é sempre opcional.
  void _retryFinal() {
    setState(() => _step = _Step.livroAberto);
  }

  void _nextItem() {
    if (_result != null) _wordAccuracies.add(_result!.accuracy);
    setState(() {
      if (_isLastItem) {
        _step = _Step.finished;
        // Antes de marcar: markLessonCompleted também dá baixa no desafio.
        final wasDailyChallenge =
            widget.store?.dailyChallengeLessonId == widget.lesson.id &&
                widget.store?.dailyChallengeCompleted == false;
        widget.store?.markLessonCompleted(widget.lesson.id);
        widget.store?.clearItemIndex(widget.lesson.id);
        widget.analytics?.log('lesson_completed', {
          'lesson': widget.lesson.id,
          'approved_seconds': _approved.inSeconds,
          'audio_sent_seconds': _audioSent.inSeconds,
          'daily_challenge': wasDailyChallenge,
        });
      } else {
        _index++;
        widget.store?.saveItemIndex(widget.lesson.id, _index);
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
      body: Column(
        children: [
          if (_step != _Step.intro && _step != _Step.finished)
            LinearProgressIndicator(
              value: (_index + 1) / widget.lesson.items.length,
              minHeight: 4,
              borderRadius: BorderRadius.zero,
              color: theme.colorScheme.secondary,
              backgroundColor:
                  theme.colorScheme.secondary.withValues(alpha: 0.15),
            ),
          Expanded(
            child: Center(
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
          ),
        ],
      ),
    );
  }

  /// Comparação antes/depois forte (tentativa 1 → 2): o "momento de
  /// transformação" do método. Mostra notas, diferença, ponto trabalhado,
  /// minutos ganhos e um trecho do feedback.
  Widget _beforeAfterCard(
      ThemeData theme, PronunciationResult r, double gain, bool approved) {
    final cs = theme.colorScheme;
    final point = r.worstSyllable?.grapheme;
    return Card(
      color: cs.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _scorePill(theme, 'Tentativa 1', _firstAccuracy?.round() ?? 0),
              Icon(Icons.arrow_forward, color: cs.onSecondaryContainer),
              _scorePill(theme, 'Tentativa 2', r.accuracy.round()),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${gain >= 0 ? "+" : ""}${gain.toStringAsFixed(0)} pontos',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: gain > 0 ? Colors.green.shade600 : cs.onSecondaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (point != null) ...[
            const SizedBox(height: 8),
            Text('Ponto trabalhado: o som "$point"',
                style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
          ],
          if (approved && _lastApprovedDuration != null) ...[
            const SizedBox(height: 4),
            Text('✅ +${_lastApprovedDuration!.inSeconds}s de fala aprovada',
                style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
          ],
          const SizedBox(height: 8),
          Text(_feedbackText(r),
              style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Widget _scorePill(ThemeData theme, String label, int score) => Column(
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          Text('$score',
              style: theme.textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
        ],
      );

  /// Pergunta de "Momento Uau" (Fase 0): a percepção subjetiva de melhora é
  /// o sinal de ativação mais forte. Aparece uma vez, após o 1º antes/depois.
  Widget _ahaQuestion(ThemeData theme) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Você sentiu melhora entre a primeira e a segunda tentativa?',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              for (final (val, label) in const [
                ('sim_claramente', 'Sim, claramente'),
                ('um_pouco', 'Um pouco'),
                ('nao_percebi', 'Não percebi'),
                ('nao_consegui_comparar', 'Não consegui comparar'),
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: OutlinedButton(
                    onPressed: () => _answerAha(val),
                    child: Text(label),
                  ),
                ),
            ],
          ),
        ),
      );

  void _answerAha(String answer) {
    final before = _firstAccuracy?.round();
    final after = _result?.accuracy.round();
    widget.analytics?.log('aha_moment_answered', {
      'answer': answer,
      'lessonId': widget.lesson.id,
      'item': _item.text,
      'scoreBefore': before,
      'scoreAfter': after,
      'delta': (before != null && after != null) ? after - before : null,
      'approvedSeconds': _lastApprovedDuration?.inSeconds ?? 0,
      'challengeModeEnabled': widget.rigorous,
    });
    widget.store?.setAhaAnswered();
    setState(() => _ahaAnswered = true);
  }

  /// Linhas explicativas do resultado (#1): normal / revisão / precisão.
  Widget _criteriaLines(ThemeData theme, bool approvedNormal) {
    final st = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Column(children: [
      Text('Critério normal: ${approvedNormal ? "aprovado" : "em revisão"}',
          style: st),
      Text(
          'Revisão futura: ${approvedNormal ? "não necessária" : "necessária"}',
          style: st),
      Text('Modo precisão: opcional', style: st),
    ]);
  }

  /// Bloco expansível "Por que este resultado?" (#2): critérios com checkmarks.
  Widget _criteriaExpansion(ThemeData theme, PronunciationResult r,
      bool approvedNormal, bool approvedChallenge) {
    final l = widget.lesson;
    Widget line(bool ok, String label) => Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text('${ok ? "✓" : "•"} $label',
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: ok
                        ? Colors.green.shade700
                        : theme.colorScheme.secondary)),
          ),
        );
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        title: Text('Por que este resultado?',
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        children: [
          line(r.accuracy >= l.approvalThreshold,
              'Clareza geral: ${r.accuracy.round()}/100'),
          if (r.prosody != null)
            line(l.minProsody == null || r.prosody! >= l.minProsody!,
                'Ritmo: ${r.prosody!.round()}/100'),
          line(r.minPhoneme >= l.minPhoneme,
              'Pronúncia (som mais fraco): ${r.minPhoneme.round()}/100'),
          line(true, 'Completeness: ${r.completeness.round()}/100'),
          line(true, 'Fluency: ${r.fluency.round()}/100'),
          if (widget.rigorous)
            line(approvedChallenge,
                'Modo precisão: critério mais exigente de clareza, ritmo e pronúncia'),
          if (!approvedNormal)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Você melhorou muito, mas este som ainda apareceu instável. '
                'Por isso, ele volta em revisão.',
                style: theme.textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }

  /// Microcopy de tempo aprovado vs áudio enviado (#11).
  Widget _minutesMicrocopy(ThemeData theme) {
    final st = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Column(children: [
      if (_lastApprovedDuration != null)
        Text(
            'Tempo aprovado nesta tentativa: '
            '${_lastApprovedDuration!.inSeconds}s',
            style: st),
      if (_lastAudioDuration != null)
        Text('Áudio enviado: ${_lastAudioDuration!.inSeconds}s', style: st),
      const SizedBox(height: 2),
      Text(
        'Só conta como aprovado o trecho em que sua fala bateu os critérios '
        'do treino.',
        style: st?.copyWith(fontStyle: FontStyle.italic),
        textAlign: TextAlign.center,
      ),
    ]);
  }

  Widget _buildStep(ThemeData theme) {
    switch (_step) {
      case _Step.intro:
        return _centered([
          Text('Treino: ${widget.lesson.title}',
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
            onPressed: _recPhase == _RecPhase.idle ? _play : null,
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
          // Fonética: IPA (preciso) + simplificada PT-BR (acessível). Só aqui,
          // depois da 1ª tentativa de ouvido — nunca antes (regra som-first).
          if (_item.ipa != null)
            Text(_item.ipa!,
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: theme.colorScheme.primary),
                textAlign: TextAlign.center),
          if (_item.phonetic != null)
            Text(_item.phonetic!,
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center),
          const SizedBox(height: 8),
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
            onPressed: _recPhase == _RecPhase.idle ? _play : null,
            icon: const Icon(Icons.volume_up),
            label: const Text('Ouvir de novo'),
          ),
          const SizedBox(height: 12),
          _recordButton(label: 'Gravação final'),
        ]);

      case _Step.resultFinal:
        final r = _result!;
        final approvedNormal = widget.lesson
            .approves(r.accuracy, r.minPhoneme, r.prosody, rigorous: false);
        final approvedChallenge = widget.lesson
            .approves(r.accuracy, r.minPhoneme, r.prosody, rigorous: true);
        final approved = widget.rigorous ? approvedChallenge : approvedNormal;
        final gain =
            _firstAccuracy == null ? 0.0 : r.accuracy - _firstAccuracy!;
        // Três estados — nunca "não bateu o critério" sem explicar (#1).
        final String stTitle, stMessage, secondaryLabel;
        final Color stColor;
        if (widget.rigorous && !approvedChallenge && approvedNormal) {
          stTitle = 'Modo precisão ainda não aprovado';
          stMessage = 'Você concluiu o treino normal, mas o critério do modo '
              'precisão é mais exigente. Tente de novo se quiser buscar '
              'precisão máxima.';
          secondaryLabel = 'Tentar modo precisão de novo';
          stColor = theme.colorScheme.tertiary;
        } else if (approved) {
          stTitle = 'Treino aprovado';
          stMessage = 'Você não apenas completou um exercício. Você melhorou '
              'uma tentativa real de fala.';
          secondaryLabel = 'Gravar de novo';
          stColor = Colors.green.shade700;
        } else {
          stTitle = 'Treino concluído com revisão';
          stMessage = 'Sua fala melhorou nesta tentativa. Este ponto ainda vai '
              'voltar para revisão amanhã, para fixar melhor.';
          secondaryLabel = 'Gravar de novo para tentar dominar';
          stColor = theme.colorScheme.secondary;
        }
        final nextLabel = _isLastItem ? 'Concluir treino' : 'Próxima palavra';
        return _centered([
          if (_firstAccuracy != null) ...[
            _beforeAfterCard(theme, r, gain, approved),
            const SizedBox(height: 16),
          ] else ...[
            _scoreBadge(theme, r.accuracy),
            const SizedBox(height: 12),
          ],
          // Mapa de sílabas colorido: a escrita já foi liberada no Livro
          // Aberto, então mostrar os grafemas aqui não fere o som-first.
          _SyllableMap(result: r),
          const SizedBox(height: 16),
          Text(stTitle,
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: stColor, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(stMessage,
              style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
          const SizedBox(height: 10),
          _criteriaLines(theme, approvedNormal),
          const SizedBox(height: 6),
          _criteriaExpansion(theme, r, approvedNormal, approvedChallenge),
          if (_lastApprovedDuration != null || _lastAudioDuration != null) ...[
            const SizedBox(height: 10),
            _minutesMicrocopy(theme),
          ],
          if (!_ahaAnswered) ...[
            const SizedBox(height: 16),
            _ahaQuestion(theme),
          ],
          const SizedBox(height: 24),
          // CTA (#15): seguir é sempre o principal; regravar é o secundário,
          // com rótulo conforme o estado.
          FilledButton(onPressed: _nextItem, child: Text(nextLabel)),
          TextButton.icon(
            onPressed: _retryFinal,
            icon: const Icon(Icons.refresh),
            label: Text(secondaryLabel),
          ),
        ]);

      case _Step.finished:
        final approvedSecs = _approved.inSeconds;
        final avgAccuracy = _wordAccuracies.isEmpty
            ? null
            : _wordAccuracies.reduce((a, b) => a + b) /
                _wordAccuracies.length;
        return _centered([
          Text('🎉', style: theme.textTheme.displayLarge),
          const SizedBox(height: 8),
          Text(
            'Lição concluída!',
            style: theme.textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _statRow(theme, '🗣️', 'Palavras praticadas',
              '${widget.lesson.items.length}'),
          const SizedBox(height: 8),
          if (avgAccuracy != null) ...[
            _statRow(theme, '🎯', 'Média de pronúncia',
                '${avgAccuracy.round()}/100'),
            const SizedBox(height: 8),
          ],
          _statRow(theme, '⏱️', 'Treino aprovado',
              approvedSecs > 0 ? _formatMin(_approved) : '—'),
          const SizedBox(height: 32),
          Text(
            approvedSecs > 0
                ? 'Esse tempo já conta para as suas 484 horas. Continue amanhã para manter o ritmo.'
                : 'Você completou a lição. Cada repetição treina o ouvido.',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Ver meu progresso'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _shareWhatsApp(avgAccuracy),
            icon: const Icon(Icons.share, size: 18),
            label: const Text('Compartilhar no WhatsApp'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF25D366),
              side: const BorderSide(color: Color(0xFF25D366)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => setState(() {
              _index = 0;
              widget.store?.clearItemIndex(widget.lesson.id);
              _step = _Step.intro;
              _hasListened = false;
              _result = null;
              _aiFeedback = null;
              _approved = Duration.zero;
              _firstAccuracy = null;
              _wordAccuracies.clear();
              _error = null;
            }),
            child: const Text('Praticar de novo'),
          ),
        ]);
    }
  }

  Future<void> _shareWhatsApp(double? avgAccuracy) async {
    final score = avgAccuracy != null ? '${avgAccuracy.round()}/100' : null;
    final scoreLine = score != null ? '\nMinha pronúncia: $score 🎯' : '';
    final text =
        'Acabei de treinar inglês no 484 Method 🎙️\n'
        'Lição: "${widget.lesson.title}"$scoreLine\n\n'
        'Experimenta você (grátis): https://484method.github.io/484-method';
    final uri = Uri.parse(
        'https://wa.me/?text=${Uri.encodeComponent(text)}');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Widget _statRow(ThemeData theme, String emoji, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Text(label, style: theme.textTheme.bodyMedium),
          ]),
          Text(value,
              style: theme.textTheme.bodyLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _recordButton({required String label}) {
    final button = FilledButton.icon(
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
    if (_recPhase == _RecPhase.recording) {
      return ScaleTransition(scale: _pulseScale, child: button);
    }
    if (_recPhase == _RecPhase.sending) {
      final theme = Theme.of(context);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          button,
          const SizedBox(height: 12),
          LinearProgressIndicator(
            borderRadius: BorderRadius.circular(4),
            color: theme.colorScheme.secondary,
            backgroundColor: theme.colorScheme.secondary.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 6),
          Text(
            'Analisando sua pronúncia...',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }
    return button;
  }

  Widget _scoreBadge(ThemeData theme, double score) {
    return TweenAnimationBuilder<double>(
      key: ValueKey('score_${_step.name}_${score.round()}'),
      tween: Tween(begin: 0, end: score),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOut,
      builder: (context, value, _) => Column(children: [
        Text(value.toStringAsFixed(0), style: theme.textTheme.displayMedium),
        LinearProgressIndicator(value: value / 100, minHeight: 8),
      ]),
    );
  }

  Widget _centered(List<Widget> children) {
    // Centraliza quando o conteúdo cabe; rola quando não cabe (telas baixas
    // e paisagem) — evita overflow na tela de resultado, que é a mais alta.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
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
    // Para palavras monossilábicas o mapa duplica o placar principal com um
    // valor ligeiramente diferente (Azure calcula word e syllable de forma
    // independente), o que confunde. Só mostra quando há ≥2 sílabas.
    if (syllables.length <= 1) return const SizedBox.shrink();
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

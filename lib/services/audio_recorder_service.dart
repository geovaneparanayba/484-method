import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

/// Grava do microfone em PCM 16 kHz mono (formato que o Azure exige) e
/// devolve um WAV pronto para envio.
///
/// Regras de custo embutidas (o Azure cobra por segundo de áudio enviado):
/// - auto-stop quando detecta [_silenceStopDelay] de silêncio depois que a
///   pessoa já começou a falar — dispensa o clique manual de "parar" na
///   maioria das tentativas, sem precisar adivinhar a duração certa pra
///   palavra curta vs. frase longa;
/// - [maxDuration] é só um teto de segurança (ruído contínuo, mic aberto);
/// - gravação que é só silêncio retorna null e não deve ser enviada.
class AudioRecorderService {
  /// [maxDuration] é o teto de segurança da gravação; [autoStopOnSilence]
  /// encerra sozinho após um trecho de silêncio depois da fala.
  ///
  /// Default = modo "palavra/chunk" do loop de lição (10s, auto-stop ligado).
  /// Pra fala aberta longa (gravação de baseline/final do desafio de 21 dias)
  /// use [AudioRecorderService.longForm]: teto maior e SEM auto-stop por
  /// silêncio — pausas naturais no meio de uma fala de 30s não podem encerrar.
  AudioRecorderService({
    this.maxDuration = const Duration(seconds: 10),
    this.autoStopOnSilence = true,
  });

  /// Fala aberta longa: até 60s e o encerramento é manual (ou pelo teto).
  factory AudioRecorderService.longForm() => AudioRecorderService(
        maxDuration: const Duration(seconds: 60),
        autoStopOnSilence: false,
      );

  final Duration maxDuration;
  final bool autoStopOnSilence;

  final AudioRecorder _recorder = AudioRecorder();
  final BytesBuilder _chunks = BytesBuilder(copy: false);
  StreamSubscription<Uint8List>? _subscription;
  Timer? _autoStopTimer;
  Timer? _silenceStopTimer;
  bool? _liveIsFloat32;

  static const int sampleRate = 16000;

  /// Silêncio contínuo depois da fala que encerra a gravação sozinha.
  /// Curto o suficiente pra não atrasar palavras isoladas, longo o
  /// suficiente pra não cortar pausas naturais dentro de uma frase.
  static const Duration _silenceStopDelay = Duration(milliseconds: 700);

  /// RMS mínimo (int16) que a janela mais alta do áudio precisa atingir
  /// para contar como fala. Ruído ambiente fica tipicamente abaixo de ~150;
  /// fala, mesmo baixa, passa de 300. Usado só na checagem pós-gravação
  /// (descarta tentativa que é silêncio puro).
  static const double _silenceRmsThreshold = 250;
  static const int _windowMs = 100;

  /// Limiar usado em tempo real pra (re)armar o timer de auto-stop. Mais
  /// alto que [_silenceRmsThreshold] de propósito: ruído de ambiente (fan,
  /// sala) passa fácil de 250 e nunca deixaria o timer de silêncio disparar.
  static const double _liveSpeechRmsThreshold = 600;

  Future<bool> hasPermission() => _recorder.hasPermission();

  DateTime? _startedAt;

  /// Só retorna quando o primeiro chunk de áudio chega — o navegador leva
  /// ~1s para começar a entregar áudio de verdade, e falar antes disso
  /// perde o início da palavra. A UI deve mostrar "fale agora" somente
  /// depois que este future completar.
  Future<void> start({required void Function() onAutoStop}) async {
    _chunks.clear();
    _liveIsFloat32 = null;
    final firstChunk = Completer<void>();
    final stream = await _recorder.startStream(const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: sampleRate,
      numChannels: 1,
    ));
    _subscription = stream.listen((chunk) {
      if (!firstChunk.isCompleted) firstChunk.complete();
      _chunks.add(chunk);
      // Só decide o formato (int16 vs float32) num chunk com sinal real —
      // num chunk de silêncio puro (bytes zerados) a heurística sempre bate
      // como "float32" (0.0 está em qualquer faixa), travando a leitura
      // errada pro resto da gravação.
      if (_liveIsFloat32 == null && chunk.any((b) => b != 0)) {
        _liveIsFloat32 = _looksLikeFloat32(chunk);
      }
      if (_liveIsFloat32 != null) {
        _feedSilenceDetector(chunk, _liveIsFloat32!, onAutoStop);
      }
    });
    await firstChunk.future;
    _startedAt = DateTime.now();
    _autoStopTimer = Timer(maxDuration, onAutoStop);
  }

  /// A cada chunk que chega, mede o volume; se passar do limiar de fala,
  /// (re)arma o timer de silêncio. Sem fala detectada ainda, não arma nada
  /// — silêncio antes da pessoa começar a falar não deve parar a gravação.
  void _feedSilenceDetector(
    Uint8List chunk,
    bool isFloat32,
    void Function() onAutoStop,
  ) {
    if (!autoStopOnSilence) return; // fala aberta: só para no manual/teto
    final rms = _chunkRms(chunk, isFloat32);
    if (kDebugMode) debugPrint('[silence-calibration] rms=${rms.round()}');
    if (rms < _liveSpeechRmsThreshold) return;
    _silenceStopTimer?.cancel();
    _silenceStopTimer = Timer(_silenceStopDelay, onAutoStop);
  }

  double _chunkRms(Uint8List chunk, bool isFloat32) {
    final buffer = Uint8List.fromList(chunk).buffer;
    if (isFloat32) {
      final floats = buffer.asFloat32List(0, chunk.length ~/ 4);
      if (floats.isEmpty) return 0;
      var sumSquares = 0.0;
      for (final v in floats) {
        sumSquares += v * v;
      }
      return math.sqrt(sumSquares / floats.length) * 32768;
    }
    final ints = buffer.asInt16List(0, chunk.length ~/ 2);
    if (ints.isEmpty) return 0;
    var sumSquares = 0.0;
    for (final v in ints) {
      sumSquares += v * v;
    }
    return math.sqrt(sumSquares / ints.length);
  }

  /// Encerra a gravação e devolve o WAV, ou null se for silêncio.
  Future<RecordedAudio?> stop() async {
    _autoStopTimer?.cancel();
    _silenceStopTimer?.cancel();
    await _recorder.stop();
    await _subscription?.cancel();
    final raw = _chunks.takeBytes();
    final wallSeconds =
        DateTime.now().difference(_startedAt!).inMilliseconds / 1000;
    if (raw.length < 64 || wallSeconds <= 0) return null;

    final (pcm, sourceInfo) = _normalizePcm(raw, wallSeconds);
    final audioSeconds = pcm.length / (sampleRate * 2);
    final diagnostics = 'fonte $sourceInfo · relógio '
        '${wallSeconds.toStringAsFixed(1)}s · '
        'áudio ${audioSeconds.toStringAsFixed(1)}s';
    debugPrint('[rec] $diagnostics');
    if (_isSilence(pcm)) return null;
    return RecordedAudio(
      wavBytes: _wavFromPcm(pcm),
      duration: Duration(milliseconds: (audioSeconds * 1000).round()),
      diagnostics: diagnostics,
    );
  }

  /// O navegador nem sempre entrega o que o plugin pede: dependendo da
  /// versão, o stream chega como Float32 na taxa nativa do microfone
  /// (ex.: 44,1 kHz) em vez de Int16 a 16 kHz. Detecta o formato real pelos
  /// bytes, estima a taxa pelo relógio e converte para Int16 16 kHz mono.
  (Uint8List, String) _normalizePcm(Uint8List raw, double wallSeconds) {
    final isFloat32 = _looksLikeFloat32(raw);
    List<double> samples;
    if (isFloat32) {
      final floats = raw.buffer.asFloat32List(0, raw.length ~/ 4);
      samples = [for (final v in floats) v];
    } else {
      final ints = raw.buffer.asInt16List(0, raw.length ~/ 2);
      samples = [for (final v in ints) v / 32768];
    }

    // O navegador também pode ignorar numChannels e entregar estéreo
    // intercalado. Procura a combinação taxa × canais que melhor explica a
    // vazão medida (ex.: 88.200 amostras/s = 2 canais a 44,1 kHz).
    const standardRates = [16000.0, 22050.0, 24000.0, 32000.0, 44100.0, 48000.0];
    final estimated = samples.length / wallSeconds;
    var sourceRate = standardRates.first;
    var channels = 1;
    var bestDiff = double.infinity;
    for (final rate in standardRates) {
      for (final ch in [1, 2]) {
        final diff = (estimated - rate * ch).abs();
        if (diff < bestDiff) {
          bestDiff = diff;
          sourceRate = rate;
          channels = ch;
        }
      }
    }
    if (channels == 2) {
      samples = [
        for (var i = 0; i + 1 < samples.length; i += 2)
          (samples[i] + samples[i + 1]) / 2
      ];
    }

    final outLength = (samples.length * sampleRate / sourceRate).floor();
    final out = Int16List(outLength);
    for (var i = 0; i < outLength; i++) {
      final pos = i * sourceRate / sampleRate;
      final i0 = pos.floor();
      final i1 = math.min(i0 + 1, samples.length - 1);
      final frac = pos - i0;
      final v = samples[i0] * (1 - frac) + samples[i1] * frac;
      out[i] = (v.clamp(-1.0, 1.0) * 32767).round();
    }
    final format = isFloat32 ? 'float32' : 'int16';
    return (
      out.buffer.asUint8List(),
      '$format@${sourceRate.round()}Hz ${channels}ch',
    );
  }

  /// Amostras Float32 de áudio ficam quase todas em [-1, 1]; bytes Int16
  /// reinterpretados como Float32 viram valores absurdos. Essa diferença
  /// identifica o formato com segurança.
  bool _looksLikeFloat32(Uint8List raw) {
    final floats = raw.buffer.asFloat32List(0, raw.length ~/ 4);
    final step = math.max(1, floats.length ~/ 1000);
    var inRange = 0;
    var checked = 0;
    for (var i = 0; i < floats.length; i += step) {
      checked++;
      final v = floats[i];
      if (v.isFinite && v.abs() <= 1.0) inRange++;
    }
    return inRange / checked > 0.95;
  }

  Future<void> dispose() {
    _autoStopTimer?.cancel();
    _silenceStopTimer?.cancel();
    return _recorder.dispose();
  }

  bool _isSilence(Uint8List pcm) {
    final samples = pcm.buffer.asInt16List(0, pcm.length ~/ 2);
    final windowSize = sampleRate * _windowMs ~/ 1000;
    var maxRms = 0.0;
    for (var start = 0; start + windowSize <= samples.length;
        start += windowSize) {
      var sumSquares = 0.0;
      for (var i = start; i < start + windowSize; i++) {
        sumSquares += samples[i] * samples[i];
      }
      final rms = math.sqrt(sumSquares / windowSize);
      if (rms > maxRms) maxRms = rms;
    }
    return maxRms < _silenceRmsThreshold;
  }

  Uint8List _wavFromPcm(Uint8List pcm) {
    const channels = 1;
    const bitsPerSample = 16;
    const byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    final header = ByteData(44);
    void writeAscii(int offset, String s) {
      for (var i = 0; i < s.length; i++) {
        header.setUint8(offset + i, s.codeUnitAt(i));
      }
    }

    writeAscii(0, 'RIFF');
    header.setUint32(4, 36 + pcm.length, Endian.little);
    writeAscii(8, 'WAVE');
    writeAscii(12, 'fmt ');
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little); // PCM
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, channels * bitsPerSample ~/ 8, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);
    writeAscii(36, 'data');
    header.setUint32(40, pcm.length, Endian.little);

    final wav = BytesBuilder(copy: false)
      ..add(header.buffer.asUint8List())
      ..add(pcm);
    return wav.takeBytes();
  }
}

class RecordedAudio {
  const RecordedAudio({
    required this.wavBytes,
    required this.duration,
    required this.diagnostics,
  });

  final Uint8List wavBytes;
  final Duration duration;

  /// Linha de diagnóstico (relógio vs duração do áudio) exibida na UI do
  /// protótipo enquanto investigamos a captura de áudio na web.
  final String diagnostics;
}

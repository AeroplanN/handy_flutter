import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../models/asr_model.dart';
import 'audio_capture.dart' show kSampleRate;
import 'engine_config.dart';

/// Результат распознавания одной записи.
class TranscriptionResult {
  const TranscriptionResult({
    required this.text,
    required this.elapsed,
    this.language = '',
  });

  final String text;

  /// Сколько заняло само распознавание — показываем в интерфейсе.
  final Duration elapsed;

  /// Язык, если модель его определила.
  final String language;
}

class TranscriptionException implements Exception {
  TranscriptionException(this.message);

  final String message;

  @override
  String toString() => message;
}

// ── Протокол общения с изолятом ────────────────────────────────────────────

class _LoadCommand {
  const _LoadCommand(this.config);

  final EngineConfig config;
}

class _TranscribeCommand {
  const _TranscribeCommand(this.samples, this.sampleRate);

  final Float32List samples;
  final int sampleRate;
}

class _UnloadCommand {
  const _UnloadCommand();
}

class _ShutdownCommand {
  const _ShutdownCommand();
}

class _Ok {
  const _Ok([this.payload]);

  final Object? payload;
}

class _Err {
  const _Err(this.message);

  final String message;
}

/// Распознавание речи на отдельном изоляте.
///
/// Модель весит сотни мегабайт и декодирует секундами, поэтому всё держится
/// вне UI-изолята: интерфейс не подвисает даже на длинных записях.
/// Модель загружается один раз и переиспользуется, пока не сменится конфиг
/// или не сработает выгрузка по простою.
class Transcriber {
  Isolate? _isolate;
  SendPort? _commands;
  ReceivePort? _responses;
  StreamQueue<dynamic>? _replies;

  String? _loadedSignature;
  Timer? _idleTimer;

  /// Через сколько простоя выгрузить модель из памяти.
  /// Аналог `ModelUnloadTimeout` в десктопном Handy; на телефоне важнее,
  /// потому что система убивает приложения за аппетит к памяти.
  Duration idleTimeout = const Duration(minutes: 5);

  bool get isLoaded => _loadedSignature != null;

  String? get loadedModelId => _loadedSignature?.split('|').first;

  Future<void> _spawn() async {
    if (_isolate != null) return;

    final responses = ReceivePort();
    _isolate = await Isolate.spawn(_isolateMain, responses.sendPort);
    _responses = responses;
    _replies = StreamQueue<dynamic>(responses);

    // Первое сообщение изолята — его SendPort.
    _commands = await _replies!.next as SendPort;
  }

  Future<void> load(EngineConfig config) async {
    await _spawn();
    if (_loadedSignature == config.signature) {
      _restartIdleTimer();
      return;
    }

    _commands!.send(_LoadCommand(config));
    final reply = await _replies!.next;
    if (reply is _Err) {
      _loadedSignature = null;
      throw TranscriptionException(reply.message);
    }

    _loadedSignature = config.signature;
    _restartIdleTimer();
  }

  /// Распознаёт запись целиком. Модель поднимается сама, если ещё не загружена.
  Future<TranscriptionResult> transcribe(
    EngineConfig config,
    Float32List samples, {
    int sampleRate = kSampleRate,
  }) async {
    if (samples.isEmpty) {
      return const TranscriptionResult(text: '', elapsed: Duration.zero);
    }

    await load(config);
    _idleTimer?.cancel();

    final started = DateTime.now();
    _commands!.send(_TranscribeCommand(samples, sampleRate));
    final reply = await _replies!.next;
    _restartIdleTimer();

    if (reply is _Err) throw TranscriptionException(reply.message);

    final payload = (reply as _Ok).payload as Map<String, dynamic>;
    return TranscriptionResult(
      text: payload['text'] as String? ?? '',
      language: payload['language'] as String? ?? '',
      elapsed: DateTime.now().difference(started),
    );
  }

  /// Освобождает память модели, но оставляет изолят живым.
  Future<void> unload() async {
    _idleTimer?.cancel();
    if (_commands == null || _loadedSignature == null) return;

    _commands!.send(const _UnloadCommand());
    await _replies!.next;
    _loadedSignature = null;
  }

  Future<void> dispose() async {
    _idleTimer?.cancel();
    _idleTimer = null;

    if (_commands != null) {
      _commands!.send(const _ShutdownCommand());
      // Ответа не ждём: изолят закрывается сам.
    }
    await _replies?.cancel(immediate: true);
    _responses?.close();
    _isolate?.kill(priority: Isolate.immediate);

    _replies = null;
    _responses = null;
    _commands = null;
    _isolate = null;
    _loadedSignature = null;
  }

  void _restartIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(idleTimeout, () {
      unload();
    });
  }
}

// ── Код изолята ────────────────────────────────────────────────────────────

Future<void> _isolateMain(SendPort toMain) async {
  final commands = ReceivePort();
  toMain.send(commands.sendPort);

  // FFI-биндинги живут в каждом изоляте отдельно.
  sherpa.initBindings();

  sherpa.OfflineRecognizer? recognizer;
  sherpa.OnlineRecognizer? streamingRecognizer;
  sherpa.VoiceActivityDetector? vad;
  EngineConfig? config;

  void release() {
    recognizer?.free();
    recognizer = null;
    streamingRecognizer?.free();
    streamingRecognizer = null;
    vad?.free();
    vad = null;
    config = null;
  }

  await for (final message in commands) {
    try {
      switch (message) {
        case _LoadCommand(config: final newConfig):
          release();
          if (newConfig.arch == ModelArch.nemotronStreaming) {
            streamingRecognizer = _createStreamingRecognizer(newConfig);
          } else {
            recognizer = _createRecognizer(newConfig);
          }
          vad = _createVad(newConfig);
          config = newConfig;
          toMain.send(const _Ok());

        case _TranscribeCommand(samples: final samples, sampleRate: final rate):
          if (recognizer == null && streamingRecognizer == null) {
            toMain.send(const _Err('Модель не загружена'));
            break;
          }
          final result = _run(
            recognizer,
            streamingRecognizer,
            vad,
            samples,
            rate,
            config,
          );
          toMain.send(_Ok(result));

        case _UnloadCommand():
          release();
          toMain.send(const _Ok());

        case _ShutdownCommand():
          release();
          commands.close();
          return;
      }
    } catch (e) {
      toMain.send(_Err(e.toString()));
    }
  }
}

/// Nemotron 3.5 — потоковая модель: её поднимает streaming-API sherpa-onnx.
/// Запись всё равно распознаётся целиком, просто кусками по мере поступления.
sherpa.OnlineRecognizer _createStreamingRecognizer(EngineConfig config) {
  return sherpa.OnlineRecognizer(
    sherpa.OnlineRecognizerConfig(
      // У Nemotron 128-мерные фильтр-банки вместо привычных 80.
      feat: const sherpa.FeatureConfig(
        sampleRate: kSampleRate,
        featureDim: 128,
      ),
      model: sherpa.OnlineModelConfig(
        transducer: sherpa.OnlineTransducerModelConfig(
          encoder: config.encoder,
          decoder: config.decoder,
          joiner: config.joiner,
        ),
        tokens: config.tokens,
        numThreads: config.numThreads,
        debug: false,
      ),
      // Запись уже нарезана VAD: делить её ещё и по правилам эндпойнта незачем.
      enableEndpoint: false,
    ),
  );
}

sherpa.OfflineRecognizer _createRecognizer(EngineConfig config) {
  final model = switch (config.arch) {
    ModelArch.nemoTransducer => sherpa.OfflineModelConfig(
        transducer: sherpa.OfflineTransducerModelConfig(
          encoder: config.encoder,
          decoder: config.decoder,
          joiner: config.joiner,
        ),
        tokens: config.tokens,
        modelType: 'nemo_transducer',
        numThreads: config.numThreads,
        debug: false,
      ),
    ModelArch.nemoCtc => sherpa.OfflineModelConfig(
        nemoCtc: sherpa.OfflineNemoEncDecCtcModelConfig(model: config.model),
        tokens: config.tokens,
        modelType: 'nemo_ctc',
        numThreads: config.numThreads,
        debug: false,
      ),
    ModelArch.nemotronStreaming =>
      throw StateError('Nemotron распознаётся через streaming-API'),
    ModelArch.whisper => sherpa.OfflineModelConfig(
        whisper: sherpa.OfflineWhisperModelConfig(
          encoder: config.encoder,
          decoder: config.decoder,
          language: config.language,
          task: config.translate ? 'translate' : 'transcribe',
        ),
        tokens: config.tokens,
        modelType: 'whisper',
        numThreads: config.numThreads,
        debug: false,
      ),
  };

  return sherpa.OfflineRecognizer(sherpa.OfflineRecognizerConfig(model: model));
}

sherpa.VoiceActivityDetector? _createVad(EngineConfig config) {
  if (!config.vadEnabled || config.vadModelPath.isEmpty) return null;

  try {
    return sherpa.VoiceActivityDetector(
      config: sherpa.VadModelConfig(
        sileroVad: sherpa.SileroVadModelConfig(
          model: config.vadModelPath,
          threshold: config.vadThreshold,
          minSilenceDuration: config.minSilenceDuration,
          minSpeechDuration: 0.25,
          // Длинную реплику режем на куски, а не теряем.
          maxSpeechDuration: 30.0,
        ),
        sampleRate: kSampleRate,
        numThreads: 1,
        debug: false,
      ),
      bufferSizeInSeconds: 60,
    );
  } catch (_) {
    // Без VAD распознавание всё равно работает, просто по всей записи.
    return null;
  }
}

Map<String, dynamic> _run(
  sherpa.OfflineRecognizer? recognizer,
  sherpa.OnlineRecognizer? streamingRecognizer,
  sherpa.VoiceActivityDetector? vad,
  Float32List samples,
  int sampleRate,
  EngineConfig? config,
) {
  final segments = vad == null
      ? <Float32List>[samples]
      : _splitBySpeech(vad, samples);

  // VAD не услышал речи — пробуем распознать всё целиком, вдруг говорили тихо.
  final chunks = segments.isEmpty ? <Float32List>[samples] : segments;

  final texts = <String>[];
  var language = '';

  for (final chunk in chunks) {
    if (chunk.isEmpty) continue;

    if (streamingRecognizer != null) {
      final text = _decodeStreaming(
        streamingRecognizer,
        chunk,
        sampleRate,
        config?.language ?? '',
      );
      if (text.isNotEmpty) texts.add(text);
      continue;
    }

    final stream = recognizer!.createStream();
    try {
      stream.acceptWaveform(samples: chunk, sampleRate: sampleRate);
      recognizer.decode(stream);
      final result = recognizer.getResult(stream);
      final text = result.text.trim();
      if (text.isNotEmpty) texts.add(text);
      if (language.isEmpty) language = result.lang;
    } finally {
      stream.free();
    }
  }

  // Streaming-результат языка не сообщает: показываем тот, что выбран в
  // настройках (пустая строка — значит модель определяла язык сама).
  if (streamingRecognizer != null && config != null) {
    language = config.language;
  }

  return {'text': texts.join(' ').trim(), 'language': language};
}

/// Скармливает кусок речи потоковой модели и дожидается финального текста.
///
/// Пустая [language] означает автоопределение: модель сама поймёт язык и
/// уберёт служебный языковой тег из результата.
String _decodeStreaming(
  sherpa.OnlineRecognizer recognizer,
  Float32List chunk,
  int sampleRate,
  String language,
) {
  final stream = recognizer.createStream();
  try {
    if (language.isNotEmpty) {
      stream.setOption(key: 'language', value: language);
    }

    stream.acceptWaveform(samples: chunk, sampleRate: sampleRate);

    // Хвост тишины: без него модель придержит последние слова,
    // ожидая продолжения потока.
    stream.acceptWaveform(
      samples: Float32List((sampleRate * 0.5).round()),
      sampleRate: sampleRate,
    );
    stream.inputFinished();

    while (recognizer.isReady(stream)) {
      recognizer.decode(stream);
    }

    return recognizer.getResult(stream).text.trim();
  } finally {
    stream.free();
  }
}

/// Прогоняет запись через Silero VAD и возвращает только куски с речью.
List<Float32List> _splitBySpeech(
  sherpa.VoiceActivityDetector vad,
  Float32List samples,
) {
  const window = 512; // размер окна Silero VAD

  vad.reset();
  final segments = <Float32List>[];

  for (var offset = 0; offset < samples.length; offset += window) {
    final end = math.min(offset + window, samples.length);
    vad.acceptWaveform(Float32List.sublistView(samples, offset, end));

    while (!vad.isEmpty()) {
      segments.add(vad.front().samples);
      vad.pop();
    }
  }

  // Хвост: последняя фраза могла не закрыться тишиной.
  vad.flush();
  while (!vad.isEmpty()) {
    segments.add(vad.front().samples);
    vad.pop();
  }

  return segments;
}

/// Минимальная очередь поверх [ReceivePort]: ответы изолята читаются строго
/// по одному, в том же порядке, в каком отправлялись команды.
class StreamQueue<T> {
  StreamQueue(Stream<T> source) {
    _subscription = source.listen(
      (event) {
        if (_pending.isNotEmpty) {
          _pending.removeAt(0).complete(event);
        } else {
          _buffered.add(event);
        }
      },
      onError: (Object error) {
        if (_pending.isNotEmpty) _pending.removeAt(0).completeError(error);
      },
    );
  }

  late final StreamSubscription<T> _subscription;
  final _pending = <Completer<T>>[];
  final _buffered = <T>[];

  Future<T> get next {
    if (_buffered.isNotEmpty) return Future.value(_buffered.removeAt(0));
    final completer = Completer<T>();
    _pending.add(completer);
    return completer.future;
  }

  Future<void> cancel({bool immediate = false}) async {
    for (final completer in _pending) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('Изолят распознавания остановлен'));
      }
    }
    _pending.clear();
    await _subscription.cancel();
  }
}

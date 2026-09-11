import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:record/record.dart';

/// Частота, которую ждут все модели sherpa-onnx.
const int kSampleRate = 16000;

/// Предохранитель: дольше этого не пишем, иначе буфер и время распознавания
/// растут бесконтрольно.
const Duration kMaxRecordingDuration = Duration(minutes: 10);

/// Захват микрофона: PCM 16 кГц моно в память.
///
/// Сырые сэмплы копятся в буфере и отдаются целиком по [stop] — ровно то, что
/// нужно офлайн-распознаванию, которое работает по всей фразе сразу.
class AudioCapture {
  final AudioRecorder _recorder = AudioRecorder();

  final BytesBuilder _pcm = BytesBuilder(copy: false);
  StreamSubscription<Uint8List>? _subscription;
  final StreamController<double> _levels = StreamController<double>.broadcast();

  DateTime? _startedAt;
  Timer? _limitTimer;
  bool _recording = false;

  /// Громкость 0.0–1.0 для визуализации волны.
  Stream<double> get levels => _levels.stream;

  bool get isRecording => _recording;

  Duration get elapsed => _startedAt == null
      ? Duration.zero
      : DateTime.now().difference(_startedAt!);

  Future<bool> hasPermission() => _recorder.hasPermission();

  /// Начинает запись. [onLimitReached] вызывается, если упёрлись в
  /// [kMaxRecordingDuration] — контроллер сам решает, что делать дальше.
  Future<void> start({void Function()? onLimitReached}) async {
    if (_recording) return;

    _pcm.clear();
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: kSampleRate,
        numChannels: 1,
        echoCancel: true,
        noiseSuppress: true,
        autoGain: true,
      ),
    );

    _recording = true;
    _startedAt = DateTime.now();

    _subscription = stream.listen(
      (chunk) {
        _pcm.add(chunk);
        if (!_levels.isClosed) _levels.add(_rms(chunk));
      },
      onError: (Object _) {
        // Ошибку записи видно по пустому результату; поток просто обрываем.
      },
      cancelOnError: false,
    );

    _limitTimer = Timer(kMaxRecordingDuration, () {
      if (_recording) onLimitReached?.call();
    });
  }

  /// Останавливает запись и отдаёт накопленные сэмплы в формате,
  /// который принимает sherpa-onnx: моно float в диапазоне [-1, 1].
  Future<Float32List> stop() async {
    if (!_recording) return Float32List(0);

    _limitTimer?.cancel();
    _limitTimer = null;
    _recording = false;

    await _recorder.stop();
    await _subscription?.cancel();
    _subscription = null;
    _startedAt = null;

    return _toFloat32(_pcm.takeBytes());
  }

  /// Останавливает запись и выбрасывает накопленное.
  Future<void> cancel() async {
    if (!_recording) return;

    _limitTimer?.cancel();
    _limitTimer = null;
    _recording = false;

    await _recorder.stop();
    await _subscription?.cancel();
    _subscription = null;
    _startedAt = null;
    _pcm.clear();
  }

  Future<void> dispose() async {
    _limitTimer?.cancel();
    await _subscription?.cancel();
    await _levels.close();
    await _recorder.dispose();
  }

  /// PCM16 little-endian → float [-1, 1].
  static Float32List _toFloat32(Uint8List bytes) {
    final sampleCount = bytes.lengthInBytes ~/ 2;
    final view = ByteData.view(
      bytes.buffer,
      bytes.offsetInBytes,
      sampleCount * 2,
    );
    final out = Float32List(sampleCount);
    for (var i = 0; i < sampleCount; i++) {
      out[i] = view.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return out;
  }

  /// Среднеквадратичная громкость чанка, слегка поджатая для наглядности.
  static double _rms(Uint8List chunk) {
    final sampleCount = chunk.lengthInBytes ~/ 2;
    if (sampleCount == 0) return 0;

    final view = ByteData.view(
      chunk.buffer,
      chunk.offsetInBytes,
      sampleCount * 2,
    );
    var sum = 0.0;
    for (var i = 0; i < sampleCount; i++) {
      final sample = view.getInt16(i * 2, Endian.little) / 32768.0;
      sum += sample * sample;
    }

    final rms = math.sqrt(sum / sampleCount);
    // Корень растягивает тихую часть шкалы — полоски заметнее шевелятся.
    return math.sqrt(rms).clamp(0.0, 1.0);
  }
}

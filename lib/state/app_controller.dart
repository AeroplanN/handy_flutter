import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/asr_model.dart';
import '../models/history_entry.dart';
import '../models/settings.dart';
import '../services/app_paths.dart';
import '../services/audio_capture.dart';
import '../services/engine_config.dart';
import '../services/feedback_service.dart';
import '../services/history_service.dart';
import '../services/model_manager.dart';
import '../services/output_service.dart';
import '../services/settings_service.dart';
import '../services/text_post_process.dart';
import '../services/transcriber.dart';

enum RecordingState { idle, recording, transcribing }

/// Общее состояние приложения: настройки, запись, распознавание, история.
///
/// Один контроллер на всё — приложение небольшое, а связка «запись → модель →
/// история → буфер обмена» всё равно неразрывна.
class AppController extends ChangeNotifier {
  AppController({
    SettingsService? settingsService,
    HistoryService? historyService,
    ModelManager? modelManager,
    AudioCapture? audioCapture,
    Transcriber? transcriber,
    OutputService? output,
    FeedbackService? feedbackService,
  })  : _settingsService = settingsService ?? SettingsService(),
        _history = historyService ?? HistoryService(),
        models = modelManager ?? ModelManager(),
        _audio = audioCapture ?? AudioCapture(),
        _transcriber = transcriber ?? Transcriber(),
        _output = output ?? OutputService(),
        _feedback = feedbackService ?? FeedbackService();

  final SettingsService _settingsService;
  final HistoryService _history;
  final AudioCapture _audio;
  final Transcriber _transcriber;
  final OutputService _output;
  final FeedbackService _feedback;

  /// Публично — экраны моделей слушают его напрямую.
  final ModelManager models;

  Settings _settings = const Settings();
  Settings get settings => _settings;

  RecordingState _state = RecordingState.idle;
  RecordingState get state => _state;

  String _currentText = '';
  String get currentText => _currentText;

  Duration? _lastElapsed;

  /// Сколько заняло последнее распознавание.
  Duration? get lastElapsed => _lastElapsed;

  String? _error;
  String? get error => _error;

  double _level = 0;

  /// Текущая громкость 0.0–1.0 для визуализации.
  double get level => _level;

  Duration _recordingElapsed = Duration.zero;
  Duration get recordingElapsed => _recordingElapsed;

  List<HistoryEntry> _entries = const [];
  List<HistoryEntry> get entries => _entries;

  bool _ready = false;

  /// Инициализация завершена, интерфейс можно показывать.
  bool get ready => _ready;

  StreamSubscription<double>? _levelSub;
  Timer? _tick;

  /// Выбранная модель из каталога.
  AsrModel? get selectedModel => _settings.model;

  /// Модель выбрана и целиком скачана — можно писать.
  bool get canRecord {
    final model = selectedModel;
    return model != null && models.isReady(model.id) && models.vadReady;
  }

  Future<void> init() async {
    _settings = await _settingsService.load();
    _feedback.settings = _settings;

    await AppPaths.instance();
    await models.refresh();
    await _history.applyRetention(_settings);
    _entries = await _history.list();

    _levelSub = _audio.levels.listen((value) {
      _level = value;
      notifyListeners();
    });

    _ready = true;
    notifyListeners();
  }

  // ── Настройки ────────────────────────────────────────────────────────────

  Future<void> updateSettings(Settings next) async {
    final previous = _settings;
    _settings = next;
    _feedback.settings = next;
    notifyListeners();

    await _settingsService.save(next);

    // Сменилась модель или её параметры — старая в памяти больше не нужна.
    if (previous.modelId != next.modelId ||
        previous.language != next.language ||
        previous.translateToEnglish != next.translateToEnglish ||
        previous.numThreads != next.numThreads ||
        previous.vadEnabled != next.vadEnabled) {
      await _transcriber.unload();
    }

    if (previous.historyLimit != next.historyLimit ||
        previous.recordingRetention != next.recordingRetention) {
      await _history.applyRetention(next);
      _entries = await _history.list();
      notifyListeners();
    }
  }

  // ── Запись ───────────────────────────────────────────────────────────────

  Future<bool> requestMicrophonePermission() => _audio.hasPermission();

  Future<void> startRecording() async {
    if (_state != RecordingState.idle) return;

    final model = selectedModel;
    if (model == null) {
      _fail('Модель не выбрана');
      return;
    }
    if (!models.isReady(model.id)) {
      _fail('Модель «${model.name}» ещё не скачана');
      return;
    }

    if (!await _audio.hasPermission()) {
      _fail('Нужен доступ к микрофону');
      return;
    }

    _error = null;
    _currentText = '';

    try {
      await _audio.start(onLimitReached: stopAndTranscribe);
    } catch (e) {
      _fail('Не удалось начать запись: $e');
      return;
    }

    _state = RecordingState.recording;
    _recordingElapsed = Duration.zero;
    notifyListeners();

    if (_settings.keepScreenAwake) {
      unawaited(WakelockPlus.enable());
    }
    unawaited(_feedback.recordingStarted());

    _tick = Timer.periodic(const Duration(milliseconds: 200), (_) {
      _recordingElapsed = _audio.elapsed;
      notifyListeners();
    });

    // Пока пишется звук, поднимаем модель в память — к концу фразы
    // распознавание стартует без паузы на загрузку.
    unawaited(_preloadModel(model));
  }

  Future<void> stopAndTranscribe() async {
    if (_state != RecordingState.recording) return;

    _tick?.cancel();
    _tick = null;

    final samples = await _audio.stop();
    _level = 0;
    _state = RecordingState.transcribing;
    notifyListeners();

    unawaited(_feedback.recordingStopped());

    final model = selectedModel;
    if (model == null) {
      _finishRecording();
      _fail('Модель не выбрана');
      return;
    }

    // Меньше четверти секунды — почти наверняка случайное касание.
    if (samples.length < kSampleRate ~/ 4) {
      _finishRecording();
      _state = RecordingState.idle;
      _error = 'Слишком короткая запись';
      notifyListeners();
      return;
    }

    try {
      final config = await EngineConfig.build(
        model: model,
        settings: _settings,
      );
      final result = await _transcriber.transcribe(config, samples);

      final text = postProcess(
        result.text,
        removeFillerWords: _settings.removeFillerWords,
        customWords: _settings.customWords,
      );

      _currentText = text;
      _lastElapsed = result.elapsed;
      _state = RecordingState.idle;
      notifyListeners();

      if (text.isNotEmpty) {
        await _deliver(text);
        await _saveToHistory(
          text: text,
          samples: samples,
          modelId: model.id,
        );
      } else {
        _error = 'Речь не распознана';
        notifyListeners();
      }
    } catch (e) {
      _state = RecordingState.idle;
      _fail('Ошибка распознавания: $e');
      unawaited(_feedback.failed());
    } finally {
      _finishRecording();
    }
  }

  Future<void> cancelRecording() async {
    if (_state != RecordingState.recording) return;

    _tick?.cancel();
    _tick = null;
    await _audio.cancel();

    _level = 0;
    _state = RecordingState.idle;
    _recordingElapsed = Duration.zero;
    notifyListeners();

    _finishRecording();
  }

  void _finishRecording() {
    _recordingElapsed = Duration.zero;
    if (_settings.keepScreenAwake) {
      unawaited(WakelockPlus.disable());
    }
  }

  Future<void> _preloadModel(AsrModel model) async {
    try {
      final config = await EngineConfig.build(
        model: model,
        settings: _settings,
      );
      await _transcriber.load(config);
    } catch (_) {
      // Не страшно: настоящую ошибку покажем при распознавании.
    }
  }

  /// Отдаёт текст наружу так, как просил пользователь.
  Future<void> _deliver(String text) async {
    unawaited(_feedback.transcriptionReady());

    switch (_settings.afterTranscribe) {
      case AfterTranscribe.nothing:
        break;
      case AfterTranscribe.copy:
        await _output.copy(text);
      case AfterTranscribe.copyAndShare:
        await _output.copy(text);
        await _output.share(text);
    }
  }

  Future<void> _saveToHistory({
    required String text,
    required Float32List samples,
    required String modelId,
  }) async {
    String? fileName;

    if (_settings.recordingRetention != RecordingRetention.never) {
      final paths = await AppPaths.instance();
      fileName = 'rec_${DateTime.now().millisecondsSinceEpoch}.wav';
      try {
        sherpa.writeWave(
          filename: paths.recordingPath(fileName),
          samples: samples,
          sampleRate: kSampleRate,
        );
      } catch (_) {
        fileName = null;
      }
    }

    final entry = await _history.add(
      HistoryEntry(
        id: null,
        timestamp: DateTime.now(),
        text: text,
        modelId: modelId,
        fileName: fileName,
        durationMs: (samples.length / kSampleRate * 1000).round(),
      ),
    );

    _entries = [entry, ..._entries];
    notifyListeners();

    await _history.applyRetention(_settings);
  }

  void _fail(String message) {
    _error = message;
    notifyListeners();
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  // ── Текущий текст ────────────────────────────────────────────────────────

  Future<void> copyCurrent() => _output.copy(_currentText);

  Future<void> shareCurrent() => _output.share(_currentText);

  void clearCurrent() {
    _currentText = '';
    _lastElapsed = null;
    notifyListeners();
  }

  // ── История ──────────────────────────────────────────────────────────────

  Future<void> reloadHistory() async {
    _entries = await _history.list();
    notifyListeners();
  }

  Future<List<HistoryEntry>> searchHistory(String query) =>
      query.trim().isEmpty ? _history.list() : _history.search(query);

  Future<void> deleteEntry(HistoryEntry entry) async {
    await _history.delete(entry);
    _entries = _entries.where((e) => e.id != entry.id).toList();
    notifyListeners();
  }

  Future<void> toggleSaved(HistoryEntry entry) async {
    if (entry.id == null) return;
    await _history.toggleSaved(entry.id!, !entry.saved);
    _entries = _entries
        .map((e) => e.id == entry.id ? e.copyWith(saved: !e.saved) : e)
        .toList();
    notifyListeners();
  }

  Future<void> clearHistory() async {
    await _history.clear();
    _entries = const [];
    notifyListeners();
  }

  Future<void> copyEntry(HistoryEntry entry) => _output.copy(entry.text);

  Future<void> shareEntry(HistoryEntry entry) => _output.share(entry.text);

  // ── Модели ───────────────────────────────────────────────────────────────

  Future<void> downloadModel(AsrModel model) async {
    await models.download(model);
    notifyListeners();
  }

  Future<void> removeModel(AsrModel model) async {
    if (_transcriber.loadedModelId == model.id) {
      await _transcriber.unload();
    }
    await models.remove(model);
    notifyListeners();
  }

  Future<void> selectModel(AsrModel model) =>
      updateSettings(_settings.copyWith(modelId: model.id));

  @override
  void dispose() {
    _tick?.cancel();
    _levelSub?.cancel();
    _audio.dispose();
    _transcriber.dispose();
    super.dispose();
  }
}

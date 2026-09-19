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
import 'home_phase.dart';

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

  /// Запись истории, которой соответствует текст на экране. В режиме заметки
  /// сюда переписывается весь накопленный текст, чтобы правки не потерялись.
  int? _currentEntryId;
  int? get currentEntryId => _currentEntryId;

  /// Текст правили руками и ещё не сохранили.
  bool _currentDirty = false;
  bool get currentDirty => _currentDirty;

  /// Язык, который определила модель в последней расшифровке.
  String _lastLanguage = '';
  String get lastLanguage => _lastLanguage;

  Duration? _lastElapsed;

  /// Сколько заняло последнее распознавание.
  Duration? get lastElapsed => _lastElapsed;

  String? _error;
  String? get error => _error;

  /// Громкость 0.0–1.0 и длительность записи меняются по несколько раз в
  /// секунду. Через `notifyListeners()` это перерисовывало бы весь экран
  /// вместе с полем ввода текста, поэтому они живут отдельными
  /// уведомителями: подписывается только волна и таймер.
  final ValueNotifier<double> levelNotifier = ValueNotifier(0);
  final ValueNotifier<Duration> elapsedNotifier = ValueNotifier(Duration.zero);

  /// Текущая громкость 0.0–1.0 для визуализации.
  double get level => levelNotifier.value;

  Duration get recordingElapsed => elapsedNotifier.value;

  List<HistoryEntry> _entries = const [];
  List<HistoryEntry> get entries => _entries;

  /// Сколько расшифровок в базе всего. `entries` держит только последние —
  /// для счётчика в шапке этого мало.
  int _historyTotal = 0;
  int get historyTotal => _historyTotal;

  bool _ready = false;

  /// Инициализация завершена, интерфейс можно показывать.
  bool get ready => _ready;

  StreamSubscription<double>? _levelSub;
  Timer? _tick;
  Timer? _autosave;

  /// Выбранная модель из каталога.
  AsrModel? get selectedModel => _settings.model;

  /// Модель выбрана и целиком скачана — можно писать.
  bool get canRecord {
    final model = selectedModel;
    return model != null && models.isReady(model.id) && models.vadReady;
  }

  /// Что показывать на главном экране. Ошибка сюда не входит: она рисуется
  /// баннером поверх любой фазы.
  HomePhase get phase {
    final model = selectedModel;

    return computeHomePhase(
      recording: _state == RecordingState.recording,
      transcribing: _state == RecordingState.transcribing,
      modelDownloading: model != null &&
          models.statusOf(model.id) == ModelStatus.downloading,
      canRecord: canRecord,
      hasText: _currentText.isNotEmpty,
    );
  }

  Future<void> init() async {
    _settings = await _settingsService.load();
    _feedback.settings = _settings;

    await AppPaths.instance();
    await models.refresh();
    await _history.applyRetention(_settings);
    _entries = await _history.list();
    _historyTotal = await _history.count();

    _levelSub = _audio.levels.listen((value) => levelNotifier.value = value);

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
      _historyTotal = await _history.count();
      notifyListeners();
    }
  }

  /// Возвращает настройки к значениям по умолчанию, оставляя выбранную
  /// модель: скачанное на диске никуда не делось, и терять его незачем.
  Future<void> resetSettings() async {
    await _settingsService.reset();
    await updateSettings(Settings(
      modelId: _settings.modelId,
      onboardingDone: _settings.onboardingDone,
    ));
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

    // Правки предыдущего текста могли не успеть сохраниться: в режиме
    // «заменять» новая расшифровка их затрёт, поэтому фиксируем сейчас.
    await saveCurrentToHistory();

    try {
      await _audio.start(onLimitReached: stopAndTranscribe);
    } catch (e) {
      _fail('Не удалось начать запись: $e');
      return;
    }

    _state = RecordingState.recording;
    elapsedNotifier.value = Duration.zero;
    notifyListeners();

    if (_settings.keepScreenAwake) {
      unawaited(WakelockPlus.enable());
    }
    unawaited(_feedback.recordingStarted());

    _tick = Timer.periodic(const Duration(milliseconds: 200), (_) {
      elapsedNotifier.value = _audio.elapsed;
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
    levelNotifier.value = 0;
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

      _lastElapsed = result.elapsed;
      _lastLanguage = result.language;
      _state = RecordingState.idle;

      if (text.isEmpty) {
        _error = 'Речь не распознана';
        notifyListeners();
        return;
      }

      final append = _settings.composeMode == ComposeMode.append;
      if (append) {
        _appendChunk(text);
      } else {
        _currentText = text;
        _currentEntryId = null;
        _currentDirty = false;
      }
      notifyListeners();

      // В режиме заметки не копируем и не открываем «Поделиться» на каждую
      // диктовку: человек ещё пишет. Отклик оставляем.
      if (append) {
        unawaited(_feedback.transcriptionReady());
      } else {
        await _deliver(text);
      }

      // Каждая диктовка остаётся в истории отдельной записью со своим
      // аудио — так работают и хранение записей, и их удаление по сроку.
      final entry = await _saveToHistory(
        text: text,
        samples: samples,
        modelId: model.id,
      );

      if (append && _currentEntryId != null) {
        // Заметка уже начата: её первая запись хранит текст целиком.
        await _syncNoteText();
      } else {
        _currentEntryId = entry.id;
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

    levelNotifier.value = 0;
    _state = RecordingState.idle;
    elapsedNotifier.value = Duration.zero;
    notifyListeners();

    _finishRecording();
  }

  void _finishRecording() {
    elapsedNotifier.value = Duration.zero;
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

  Future<HistoryEntry> _saveToHistory({
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
    _historyTotal += 1;
    notifyListeners();

    await _history.applyRetention(_settings);
    return entry;
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

  /// Правка текста руками. Сохранение отложенное: пишем в историю не на
  /// каждую букву, а через паузу после того, как человек остановился.
  void editCurrent(String text) {
    if (text == _currentText) return;
    _currentText = text;
    _currentDirty = true;
    notifyListeners();

    _autosave?.cancel();
    _autosave = Timer(const Duration(milliseconds: 1500), () {
      unawaited(saveCurrentToHistory());
    });
  }

  /// Дописывает распознанный кусок к тому, что уже на экране.
  ///
  /// Разделитель всегда абзац: он предсказуем и убирается одним Backspace,
  /// а угадывать «точка или пробел» за пользователя мы не беремся.
  static const _paragraphBreak = '\n\n';

  void _appendChunk(String chunk) {
    _currentText = _currentText.isEmpty
        ? chunk
        : '${_currentText.trimRight()}$_paragraphBreak$chunk';
  }

  /// Сохраняет текст на экране в его запись истории.
  Future<void> saveCurrentToHistory() async {
    _autosave?.cancel();
    _autosave = null;

    if (!_currentDirty || _currentEntryId == null) return;
    await _syncNoteText();
  }

  /// Переписывает текст заметки в её запись истории.
  Future<void> _syncNoteText() async {
    final id = _currentEntryId;
    if (id == null) return;

    await _history.updateText(id, _currentText);
    _currentDirty = false;

    _entries = [
      for (final entry in _entries)
        entry.id == id ? entry.copyWith(text: _currentText) : entry,
    ];
    notifyListeners();
  }

  /// Начать с чистого листа, не потеряв текущую заметку.
  Future<void> startNewNote() async {
    await saveCurrentToHistory();
    clearCurrent();
  }

  /// Открыть запись истории в редакторе на главном экране и продолжить её.
  Future<void> loadEntryIntoCurrent(HistoryEntry entry) async {
    await saveCurrentToHistory();

    _currentText = entry.text;
    _currentEntryId = entry.id;
    _currentDirty = false;
    _lastElapsed = null;
    _error = null;
    notifyListeners();
  }

  /// Правка текста записи прямо в истории.
  Future<void> updateEntryText(HistoryEntry entry, String text) async {
    final id = entry.id;
    if (id == null || entry.text == text) return;

    await _history.updateText(id, text);
    _entries = [
      for (final e in _entries) e.id == id ? e.copyWith(text: text) : e,
    ];
    if (_currentEntryId == id) _currentText = text;
    notifyListeners();
  }

  Future<void> copyCurrent() => _output.copy(_currentText);

  Future<void> shareCurrent() => _output.share(_currentText);

  void clearCurrent() {
    _autosave?.cancel();
    _autosave = null;
    _currentText = '';
    _currentEntryId = null;
    _currentDirty = false;
    _lastLanguage = '';
    _lastElapsed = null;
    notifyListeners();
  }

  // ── История ──────────────────────────────────────────────────────────────

  Future<void> reloadHistory() async {
    _entries = await _history.list();
    _historyTotal = await _history.count();
    notifyListeners();
  }

  /// Страница истории с поиском и фильтром. Поиск идёт запросом к базе, а
  /// не фильтрацией загруженного куска, поэтому находит и старые записи.
  Future<List<HistoryEntry>> loadHistoryPage({
    int offset = 0,
    int limit = 50,
    String query = '',
    bool pinnedOnly = false,
    bool withAudioOnly = false,
  }) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return _history.list(
        offset: offset,
        limit: limit,
        pinnedOnly: pinnedOnly,
        withAudioOnly: withAudioOnly,
      );
    }
    return _history.search(
      trimmed,
      offset: offset,
      limit: limit,
      pinnedOnly: pinnedOnly,
      withAudioOnly: withAudioOnly,
    );
  }

  Future<void> deleteEntry(HistoryEntry entry) async {
    await _history.delete(entry);
    _entries = _entries.where((e) => e.id != entry.id).toList();
    _historyTotal = (_historyTotal - 1).clamp(0, _historyTotal);
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
    _historyTotal = 0;
    notifyListeners();
  }

  Future<void> copyEntry(HistoryEntry entry) => _output.copy(entry.text);

  Future<void> shareEntry(HistoryEntry entry) => _output.share(entry.text);

  // ── Модели ───────────────────────────────────────────────────────────────

  Future<void> downloadModel(AsrModel model) async {
    await models.download(model);
    notifyListeners();
  }

  /// Удаляет модель с диска. Если удалили активную — переключаемся на любую
  /// другую готовую, иначе приложение уверяло бы, что моделей нет вовсе.
  Future<void> removeModel(AsrModel model) async {
    if (_transcriber.loadedModelId == model.id) {
      await _transcriber.unload();
    }
    await models.remove(model);

    if (_settings.modelId == model.id) {
      final fallback = kModelCatalog
          .where((m) => m.id != model.id && models.isReady(m.id))
          .firstOrNull;
      if (fallback != null) {
        await selectModel(fallback);
        return;
      }
    }

    notifyListeners();
  }

  Future<void> selectModel(AsrModel model) =>
      updateSettings(_settings.copyWith(modelId: model.id));

  @override
  void dispose() {
    _autosave?.cancel();
    levelNotifier.dispose();
    elapsedNotifier.dispose();
    _tick?.cancel();
    _levelSub?.cancel();
    _audio.dispose();
    _transcriber.dispose();
    super.dispose();
  }
}

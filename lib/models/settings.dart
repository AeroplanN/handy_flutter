import 'asr_model.dart';

/// Как кнопка записи реагирует на нажатие — мобильный аналог
/// `ShortcutActivation` из десктопного Handy.
enum RecordMode {
  /// Держать палец — идёт запись, отпустил — распознавание.
  hold,

  /// Тап — начать, ещё тап — закончить.
  toggle,
}

/// Как новая расшифровка ложится на то, что уже есть на экране.
enum ComposeMode {
  /// Каждая запись заменяет предыдущий текст — быстрая диктовка.
  replace,

  /// Каждая запись дописывается абзацем — длинная заметка.
  append,
}

/// Что делать с текстом сразу после распознавания.
enum AfterTranscribe {
  /// Ничего, текст просто остаётся на экране и в истории.
  nothing,

  /// Скопировать в буфер обмена.
  copy,

  /// Скопировать и сразу открыть системное меню «Поделиться».
  copyAndShare,
}

/// Сколько хранить аудиозаписи (сам текст в истории хранится всегда).
enum RecordingRetention {
  /// Не сохранять аудио вообще.
  never,

  /// Хранить, пока запись есть в истории.
  keepWithHistory,

  days3,
  weeks2,
  months3,
}

extension RecordingRetentionX on RecordingRetention {
  Duration? get maxAge => switch (this) {
        RecordingRetention.days3 => const Duration(days: 3),
        RecordingRetention.weeks2 => const Duration(days: 14),
        RecordingRetention.months3 => const Duration(days: 90),
        _ => null,
      };

  String get label => switch (this) {
        RecordingRetention.never => 'Не сохранять',
        RecordingRetention.keepWithHistory => 'Пока есть в истории',
        RecordingRetention.days3 => '3 дня',
        RecordingRetention.weeks2 => '2 недели',
        RecordingRetention.months3 => '3 месяца',
      };
}

enum AppTheme { system, light, dark }

/// Значение «язык определяется моделью автоматически».
const String kAutoLanguage = 'auto';

class Settings {
  const Settings({
    this.modelId = kDefaultModelId,
    this.language = kAutoLanguage,
    this.translateToEnglish = false,
    this.recordMode = RecordMode.hold,
    this.composeMode = ComposeMode.replace,
    this.afterTranscribe = AfterTranscribe.copy,
    this.vadEnabled = true,
    this.vadThreshold = 0.5,
    this.minSilenceDuration = 0.5,
    this.soundFeedback = true,
    this.hapticFeedback = true,
    this.removeFillerWords = false,
    this.customWords = const <String, String>{},
    this.historyLimit = 200,
    this.recordingRetention = RecordingRetention.keepWithHistory,
    this.numThreads = 2,
    this.theme = AppTheme.system,
    this.onboardingDone = false,
    this.keepScreenAwake = true,
  });

  /// Выбранная модель распознавания.
  final String modelId;

  /// Код языка или [kAutoLanguage]. Работает только для многоязычных моделей.
  final String language;

  /// Whisper: переводить речь на английский вместо расшифровки.
  final bool translateToEnglish;

  final RecordMode recordMode;

  /// Режим склейки по умолчанию. На главном экране переключается на лету,
  /// здесь хранится последний выбор.
  final ComposeMode composeMode;

  final AfterTranscribe afterTranscribe;

  /// Отрезать тишину через Silero VAD перед распознаванием.
  final bool vadEnabled;

  /// Порог VAD, 0.0–1.0. Выше — строже отбор речи.
  final double vadThreshold;

  /// Сколько секунд тишины считать концом фразы.
  final double minSilenceDuration;

  final bool soundFeedback;
  final bool hapticFeedback;

  /// Вырезать «э-э», «ну», «как бы» и прочий словесный мусор.
  final bool removeFillerWords;

  /// Словарь замен: как распозналось → как должно быть.
  /// Аналог `CustomWords` в десктопном Handy.
  final Map<String, String> customWords;

  /// Сколько расшифровок держать в истории.
  final int historyLimit;

  final RecordingRetention recordingRetention;

  /// Число потоков onnxruntime. На телефоне 2 — разумный компромисс.
  final int numThreads;

  final AppTheme theme;

  final bool onboardingDone;

  /// Не гасить экран во время записи и распознавания.
  final bool keepScreenAwake;

  Settings copyWith({
    String? modelId,
    String? language,
    bool? translateToEnglish,
    RecordMode? recordMode,
    ComposeMode? composeMode,
    AfterTranscribe? afterTranscribe,
    bool? vadEnabled,
    double? vadThreshold,
    double? minSilenceDuration,
    bool? soundFeedback,
    bool? hapticFeedback,
    bool? removeFillerWords,
    Map<String, String>? customWords,
    int? historyLimit,
    RecordingRetention? recordingRetention,
    int? numThreads,
    AppTheme? theme,
    bool? onboardingDone,
    bool? keepScreenAwake,
  }) {
    return Settings(
      modelId: modelId ?? this.modelId,
      language: language ?? this.language,
      translateToEnglish: translateToEnglish ?? this.translateToEnglish,
      recordMode: recordMode ?? this.recordMode,
      composeMode: composeMode ?? this.composeMode,
      afterTranscribe: afterTranscribe ?? this.afterTranscribe,
      vadEnabled: vadEnabled ?? this.vadEnabled,
      vadThreshold: vadThreshold ?? this.vadThreshold,
      minSilenceDuration: minSilenceDuration ?? this.minSilenceDuration,
      soundFeedback: soundFeedback ?? this.soundFeedback,
      hapticFeedback: hapticFeedback ?? this.hapticFeedback,
      removeFillerWords: removeFillerWords ?? this.removeFillerWords,
      customWords: customWords ?? this.customWords,
      historyLimit: historyLimit ?? this.historyLimit,
      recordingRetention: recordingRetention ?? this.recordingRetention,
      numThreads: numThreads ?? this.numThreads,
      theme: theme ?? this.theme,
      onboardingDone: onboardingDone ?? this.onboardingDone,
      keepScreenAwake: keepScreenAwake ?? this.keepScreenAwake,
    );
  }

  Map<String, dynamic> toJson() => {
        'modelId': modelId,
        'language': language,
        'translateToEnglish': translateToEnglish,
        'recordMode': recordMode.name,
        'composeMode': composeMode.name,
        'afterTranscribe': afterTranscribe.name,
        'vadEnabled': vadEnabled,
        'vadThreshold': vadThreshold,
        'minSilenceDuration': minSilenceDuration,
        'soundFeedback': soundFeedback,
        'hapticFeedback': hapticFeedback,
        'removeFillerWords': removeFillerWords,
        'customWords': customWords,
        'historyLimit': historyLimit,
        'recordingRetention': recordingRetention.name,
        'numThreads': numThreads,
        'theme': theme.name,
        'onboardingDone': onboardingDone,
        'keepScreenAwake': keepScreenAwake,
      };

  factory Settings.fromJson(Map<String, dynamic> json) {
    T pick<T extends Enum>(List<T> values, Object? name, T fallback) {
      for (final v in values) {
        if (v.name == name) return v;
      }
      return fallback;
    }

    return Settings(
      modelId: json['modelId'] as String? ?? kDefaultModelId,
      language: json['language'] as String? ?? kAutoLanguage,
      translateToEnglish: json['translateToEnglish'] as bool? ?? false,
      recordMode:
          pick(RecordMode.values, json['recordMode'], RecordMode.hold),
      composeMode: pick(
        ComposeMode.values,
        json['composeMode'],
        ComposeMode.replace,
      ),
      afterTranscribe: pick(
        AfterTranscribe.values,
        json['afterTranscribe'],
        AfterTranscribe.copy,
      ),
      vadEnabled: json['vadEnabled'] as bool? ?? true,
      vadThreshold: (json['vadThreshold'] as num?)?.toDouble() ?? 0.5,
      minSilenceDuration:
          (json['minSilenceDuration'] as num?)?.toDouble() ?? 0.5,
      soundFeedback: json['soundFeedback'] as bool? ?? true,
      hapticFeedback: json['hapticFeedback'] as bool? ?? true,
      removeFillerWords: json['removeFillerWords'] as bool? ?? false,
      customWords: (json['customWords'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), v.toString()),
          ) ??
          const {},
      historyLimit: (json['historyLimit'] as num?)?.toInt() ?? 200,
      recordingRetention: pick(
        RecordingRetention.values,
        json['recordingRetention'],
        RecordingRetention.keepWithHistory,
      ),
      numThreads: (json['numThreads'] as num?)?.toInt() ?? 2,
      theme: pick(AppTheme.values, json['theme'], AppTheme.system),
      onboardingDone: json['onboardingDone'] as bool? ?? false,
      keepScreenAwake: json['keepScreenAwake'] as bool? ?? true,
    );
  }

  /// Модель из каталога, на которую указывает [modelId].
  AsrModel? get model => modelById(modelId);
}

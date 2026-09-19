/// Что именно показывает главный экран прямо сейчас.
///
/// Фаза выводится чистой функцией: её легко проверить тестом, не поднимая
/// ни Flutter, ни сервисы.
library;

enum HomePhase {
  /// Модель не выбрана или не скачана — записывать нечем.
  noModel,

  /// Выбранная модель качается прямо сейчас.
  modelDownloading,

  /// Всё готово, текста ещё нет.
  idleEmpty,

  /// Есть распознанный текст, запись не идёт.
  idleText,

  /// Идёт запись.
  recording,

  /// Запись закончена, идёт распознавание.
  transcribing,
}

/// Порядок проверок важен: то, что происходит прямо сейчас, важнее того,
/// что лежит на экране.
HomePhase computeHomePhase({
  required bool recording,
  required bool transcribing,
  required bool modelDownloading,
  required bool canRecord,
  required bool hasText,
}) {
  if (recording) return HomePhase.recording;
  if (transcribing) return HomePhase.transcribing;
  if (modelDownloading) return HomePhase.modelDownloading;
  if (!canRecord) return HomePhase.noModel;

  return hasText ? HomePhase.idleText : HomePhase.idleEmpty;
}

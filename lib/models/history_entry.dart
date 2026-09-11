/// Одна расшифровка в истории. Схема повторяет `transcription_history`
/// из десктопного Handy, минус поля пост-обработки через LLM.
class HistoryEntry {
  const HistoryEntry({
    required this.id,
    required this.timestamp,
    required this.text,
    required this.modelId,
    this.fileName,
    this.durationMs = 0,
    this.saved = false,
  });

  /// `null` до вставки в базу.
  final int? id;

  final DateTime timestamp;
  final String text;

  /// Какой моделью распознано — полезно при сравнении качества.
  final String modelId;

  /// Имя wav-файла в папке recordings, если аудио сохранено.
  final String? fileName;

  /// Длительность исходной записи.
  final int durationMs;

  /// Закреплённые записи не удаляются при чистке по лимиту.
  final bool saved;

  /// Первая строка расшифровки — заголовок в списке.
  String get title {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 'Пустая расшифровка';
    final firstLine = trimmed.split('\n').first;
    return firstLine.length <= 60 ? firstLine : '${firstLine.substring(0, 57)}…';
  }

  int get wordCount =>
      text.trim().isEmpty ? 0 : text.trim().split(RegExp(r'\s+')).length;

  HistoryEntry copyWith({
    int? id,
    DateTime? timestamp,
    String? text,
    String? modelId,
    String? fileName,
    int? durationMs,
    bool? saved,
  }) {
    return HistoryEntry(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      text: text ?? this.text,
      modelId: modelId ?? this.modelId,
      fileName: fileName ?? this.fileName,
      durationMs: durationMs ?? this.durationMs,
      saved: saved ?? this.saved,
    );
  }

  Map<String, Object?> toRow() => {
        if (id != null) 'id': id,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'text': text,
        'model_id': modelId,
        'file_name': fileName,
        'duration_ms': durationMs,
        'saved': saved ? 1 : 0,
      };

  factory HistoryEntry.fromRow(Map<String, Object?> row) => HistoryEntry(
        id: row['id'] as int?,
        timestamp:
            DateTime.fromMillisecondsSinceEpoch(row['timestamp'] as int),
        text: row['text'] as String? ?? '',
        modelId: row['model_id'] as String? ?? '',
        fileName: row['file_name'] as String?,
        durationMs: (row['duration_ms'] as int?) ?? 0,
        saved: (row['saved'] as int? ?? 0) == 1,
      );
}

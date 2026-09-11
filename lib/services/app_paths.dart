import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Единое место, где приложение держит свои файлы.
///
/// Модели и записи лежат в support-директории, а не в кэше: система не должна
/// удалять полгигабайта скачанной модели без спроса.
class AppPaths {
  AppPaths._(this.root);

  static AppPaths? _instance;

  /// Корневая папка приложения.
  final Directory root;

  static Future<AppPaths> instance() async {
    final existing = _instance;
    if (existing != null) return existing;

    final base = await getApplicationSupportDirectory();
    final paths = AppPaths._(base);
    await paths.models.create(recursive: true);
    await paths.recordings.create(recursive: true);
    _instance = paths;
    return paths;
  }

  Directory get models => Directory(p.join(root.path, 'models'));

  Directory get recordings => Directory(p.join(root.path, 'recordings'));

  String get databaseFile => p.join(root.path, 'history.db');

  /// Папка конкретной модели, например `<root>/models/giga-am-v3-rnnt-ru`.
  Directory modelDir(String modelId) =>
      Directory(p.join(models.path, modelId));

  String modelFilePath(String modelId, String fileName) =>
      p.join(models.path, modelId, fileName);

  /// Silero VAD общий для всех моделей, поэтому лежит рядом, а не внутри.
  String get vadModelPath => p.join(models.path, 'silero_vad.onnx');

  String recordingPath(String fileName) =>
      p.join(recordings.path, fileName);
}

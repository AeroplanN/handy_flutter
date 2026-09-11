import '../models/asr_model.dart';
import '../models/settings.dart';
import 'app_paths.dart';

/// Всё, что изоляту нужно знать, чтобы поднять распознаватель.
///
/// Только простые значения: объект пересекает границу изолята копированием.
class EngineConfig {
  const EngineConfig({
    required this.modelId,
    required this.arch,
    required this.tokens,
    required this.numThreads,
    this.encoder = '',
    this.decoder = '',
    this.joiner = '',
    this.model = '',
    this.language = '',
    this.translate = false,
    this.vadModelPath = '',
    this.vadEnabled = false,
    this.vadThreshold = 0.5,
    this.minSilenceDuration = 0.5,
  });

  final String modelId;
  final ModelArch arch;

  final String encoder;
  final String decoder;
  final String joiner;
  final String model;
  final String tokens;

  final int numThreads;

  /// Код языка для Whisper; пустая строка — автоопределение.
  final String language;

  /// Whisper: переводить на английский вместо расшифровки.
  final bool translate;

  final String vadModelPath;
  final bool vadEnabled;
  final double vadThreshold;
  final double minSilenceDuration;

  /// Конфиги с одинаковой «начинкой» не требуют перезагрузки модели.
  String get signature => [
        modelId,
        arch.name,
        encoder,
        decoder,
        joiner,
        model,
        tokens,
        numThreads,
        language,
        translate,
        vadEnabled,
        vadThreshold,
        minSilenceDuration,
      ].join('|');

  /// Собирает конфиг из выбранной модели и настроек пользователя.
  static Future<EngineConfig> build({
    required AsrModel model,
    required Settings settings,
  }) async {
    final paths = await AppPaths.instance();
    String path(String? fileName) =>
        fileName == null ? '' : paths.modelFilePath(model.id, fileName);

    // Подсказка языка имеет смысл только для многоязычных моделей Whisper:
    // у русских GigaAM язык один и задавать его нечем.
    final wantsLanguage =
        model.arch == ModelArch.whisper && settings.language != kAutoLanguage;

    return EngineConfig(
      modelId: model.id,
      arch: model.arch,
      encoder: path(model.encoderFile),
      decoder: path(model.decoderFile),
      joiner: path(model.joinerFile),
      model: path(model.modelFile),
      tokens: path(model.tokensFile),
      numThreads: settings.numThreads,
      language: wantsLanguage ? settings.language : '',
      translate: model.supportsTranslate && settings.translateToEnglish,
      vadModelPath: paths.vadModelPath,
      vadEnabled: settings.vadEnabled,
      vadThreshold: settings.vadThreshold,
      minSilenceDuration: settings.minSilenceDuration,
    );
  }
}

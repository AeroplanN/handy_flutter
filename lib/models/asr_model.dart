/// Каталог моделей распознавания речи — мобильный аналог `catalog.json` из Handy.
///
/// Все модели в формате sherpa-onnx (onnxruntime), скачиваются с Hugging Face
/// по требованию и работают полностью офлайн.
library;

/// Архитектура модели — определяет, как её скормить sherpa-onnx.
enum ModelArch {
  /// NeMo RNN-T (GigaAM, Parakeet): encoder + decoder + joiner.
  nemoTransducer,

  /// NeMo CTC (GigaAM CTC): один файл модели.
  nemoCtc,

  /// Потоковый NeMo-транcдьюсер (Nemotron 3.5 ASR): encoder + decoder + joiner,
  /// но распознаётся через streaming-API sherpa-onnx, а не offline.
  nemotronStreaming,

  /// Whisper: encoder + decoder.
  whisper,
}

/// Один файл модели, скачиваемый отдельно.
class ModelFile {
  const ModelFile({
    required this.name,
    required this.url,
    required this.sizeBytes,
  });

  /// Имя файла на диске (внутри папки модели).
  final String name;
  final String url;
  final int sizeBytes;
}

class AsrModel {
  const AsrModel({
    required this.id,
    required this.name,
    required this.description,
    required this.arch,
    required this.languages,
    required this.files,
    required this.speedScore,
    required this.accuracyScore,
    required this.tokensFile,
    this.encoderFile,
    this.decoderFile,
    this.joinerFile,
    this.modelFile,
    this.recommended = false,
    this.recommendedRank = 999,
    this.supportsTranslate = false,
  });

  final String id;
  final String name;
  final String description;
  final ModelArch arch;

  /// Коды языков ISO-639-1. `multi` в конце списка означает «и многие другие».
  final List<String> languages;

  final List<ModelFile> files;

  /// 0–100, выше — быстрее.
  final int speedScore;

  /// 0–100, выше — точнее.
  final int accuracyScore;

  final String? encoderFile;
  final String? decoderFile;
  final String? joinerFile;
  final String? modelFile;
  final String tokensFile;

  final bool recommended;
  final int recommendedRank;

  /// Whisper умеет сразу переводить речь на английский.
  final bool supportsTranslate;

  int get sizeBytes => files.fold(0, (sum, f) => sum + f.sizeBytes);

  bool get isRussian => languages.contains('ru');

  /// Модель понимает больше одного языка и принимает подсказку языка.
  bool get isMultilingual => languages.length > 1;
}

/// Silero VAD — отдельная маленькая модель, общая для всех остальных.
/// Обрезает тишину до распознавания, как `vad-rs` в десктопном Handy.
const sileroVadFile = ModelFile(
  name: 'silero_vad.onnx',
  url:
      'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/silero_vad.onnx',
  sizeBytes: 643854,
);

const _gigaV3Rnnt =
    'https://huggingface.co/csukuangfj/sherpa-onnx-nemo-transducer-giga-am-v3-russian-2025-12-16/resolve/main';
const _gigaV3Ctc =
    'https://huggingface.co/csukuangfj/sherpa-onnx-nemo-ctc-giga-am-v3-russian-2025-12-16/resolve/main';
const _gigaV2Rnnt =
    'https://huggingface.co/csukuangfj/sherpa-onnx-nemo-transducer-giga-am-v2-russian-2025-04-19/resolve/main';
const _parakeetV3 =
    'https://huggingface.co/csukuangfj/sherpa-onnx-nemo-parakeet-tdt-0.6b-v3-int8/resolve/main';
const _nemotron35 =
    'https://huggingface.co/csukuangfj2/sherpa-onnx-nemotron-3.5-asr-streaming-0.6b-1120ms-int8-2026-06-11/resolve/main';
const _whisperSmall =
    'https://huggingface.co/csukuangfj/sherpa-onnx-whisper-small/resolve/main';
const _whisperBase =
    'https://huggingface.co/csukuangfj/sherpa-onnx-whisper-base/resolve/main';
const _whisperTiny =
    'https://huggingface.co/csukuangfj/sherpa-onnx-whisper-tiny/resolve/main';

/// Многоязычный набор Whisper — перечислены крупнейшие языки из 99 поддержанных.
const _whisperLangs = [
  'ru',
  'en',
  'uk',
  'de',
  'fr',
  'es',
  'it',
  'pt',
  'nl',
  'pl',
  'tr',
  'ar',
  'zh',
  'ja',
  'ko',
  'hi',
  'multi',
];

/// Языки Nemotron 3.5: 19 «transcription-ready» локалей плюс 13 с более
/// широким покрытием. Порядок — от самых частых для нас.
const _nemotronLangs = [
  'ru',
  'en',
  'uk',
  'de',
  'fr',
  'es',
  'it',
  'pt',
  'nl',
  'tr',
  'ar',
  'hi',
  'ja',
  'ko',
  'vi',
  'pl',
  'cs',
  'sk',
  'bg',
  'hr',
  'da',
  'et',
  'fi',
  'hu',
  'nb',
  'ro',
  'sv',
  'zh',
];

/// Доступные модели. Порядок = порядок показа в списке.
const List<AsrModel> kModelCatalog = [
  // ── Русский: GigaAM v3 (Сбер) — лучшее качество на русском ──────────────
  AsrModel(
    id: 'giga-am-v3-rnnt-ru',
    name: 'GigaAM v3 RNN-T',
    description:
        'Лучшее качество на русском. Знаки препинания и нормализация чисел.',
    arch: ModelArch.nemoTransducer,
    languages: ['ru'],
    speedScore: 70,
    accuracyScore: 96,
    recommended: true,
    recommendedRank: 1,
    encoderFile: 'encoder.int8.onnx',
    decoderFile: 'decoder.onnx',
    joinerFile: 'joiner.onnx',
    tokensFile: 'tokens.txt',
    files: [
      ModelFile(
        name: 'encoder.int8.onnx',
        url: '$_gigaV3Rnnt/encoder.int8.onnx',
        sizeBytes: 224570814,
      ),
      ModelFile(
        name: 'decoder.onnx',
        url: '$_gigaV3Rnnt/decoder.onnx',
        sizeBytes: 3331651,
      ),
      ModelFile(
        name: 'joiner.onnx',
        url: '$_gigaV3Rnnt/joiner.onnx',
        sizeBytes: 1440448,
      ),
      ModelFile(
        name: 'tokens.txt',
        url: '$_gigaV3Rnnt/tokens.txt',
        sizeBytes: 196,
      ),
    ],
  ),

  AsrModel(
    id: 'giga-am-v3-ctc-ru',
    name: 'GigaAM v3 CTC',
    description:
        'Тот же русский, но заметно быстрее. Хороший выбор для слабых телефонов.',
    arch: ModelArch.nemoCtc,
    languages: ['ru'],
    speedScore: 85,
    accuracyScore: 93,
    recommended: true,
    recommendedRank: 2,
    modelFile: 'model.int8.onnx',
    tokensFile: 'tokens.txt',
    files: [
      ModelFile(
        name: 'model.int8.onnx',
        url: '$_gigaV3Ctc/model.int8.onnx',
        sizeBytes: 224721476,
      ),
      ModelFile(
        name: 'tokens.txt',
        url: '$_gigaV3Ctc/tokens.txt',
        sizeBytes: 196,
      ),
    ],
  ),

  AsrModel(
    id: 'giga-am-v2-rnnt-ru',
    name: 'GigaAM v2 RNN-T',
    description: 'Предыдущее поколение русской модели. Запасной вариант.',
    arch: ModelArch.nemoTransducer,
    languages: ['ru'],
    speedScore: 70,
    accuracyScore: 92,
    encoderFile: 'encoder.int8.onnx',
    decoderFile: 'decoder.onnx',
    joinerFile: 'joiner.onnx',
    tokensFile: 'tokens.txt',
    files: [
      ModelFile(
        name: 'encoder.int8.onnx',
        url: '$_gigaV2Rnnt/encoder.int8.onnx',
        sizeBytes: 236314144,
      ),
      ModelFile(
        name: 'decoder.onnx',
        url: '$_gigaV2Rnnt/decoder.onnx',
        sizeBytes: 3331651,
      ),
      ModelFile(
        name: 'joiner.onnx',
        url: '$_gigaV2Rnnt/joiner.onnx',
        sizeBytes: 1440448,
      ),
      ModelFile(
        name: 'tokens.txt',
        url: '$_gigaV2Rnnt/tokens.txt',
        sizeBytes: 196,
      ),
    ],
  ),

  // ── Многоязычные ────────────────────────────────────────────────────────
  AsrModel(
    id: 'nemotron-3.5-streaming-ru',
    name: 'Nemotron 3.5 ASR',
    description:
        'Знаки препинания и заглавные буквы прямо из модели, 32 языка. '
        'Та же модель, что в десктопном Handy.',
    arch: ModelArch.nemotronStreaming,
    languages: _nemotronLangs,
    speedScore: 60,
    accuracyScore: 90,
    recommended: true,
    recommendedRank: 3,
    encoderFile: 'encoder.int8.onnx',
    decoderFile: 'decoder.int8.onnx',
    joinerFile: 'joiner.int8.onnx',
    tokensFile: 'tokens.txt',
    files: [
      ModelFile(
        name: 'encoder.int8.onnx',
        url: '$_nemotron35/encoder.int8.onnx',
        sizeBytes: 657601521,
      ),
      ModelFile(
        name: 'decoder.int8.onnx',
        url: '$_nemotron35/decoder.int8.onnx',
        sizeBytes: 14978075,
      ),
      ModelFile(
        name: 'joiner.int8.onnx',
        url: '$_nemotron35/joiner.int8.onnx',
        sizeBytes: 9504438,
      ),
      ModelFile(
        name: 'tokens.txt',
        url: '$_nemotron35/tokens.txt',
        sizeBytes: 131440,
      ),
    ],
  ),

  AsrModel(
    id: 'whisper-small',
    name: 'Whisper Small',
    description: '99 языков, включая русский. Медленнее, зато универсальна.',
    arch: ModelArch.whisper,
    languages: _whisperLangs,
    speedScore: 35,
    accuracyScore: 85,
    supportsTranslate: true,
    recommended: true,
    recommendedRank: 4,
    encoderFile: 'small-encoder.int8.onnx',
    decoderFile: 'small-decoder.int8.onnx',
    tokensFile: 'small-tokens.txt',
    files: [
      ModelFile(
        name: 'small-encoder.int8.onnx',
        url: '$_whisperSmall/small-encoder.int8.onnx',
        sizeBytes: 112442483,
      ),
      ModelFile(
        name: 'small-decoder.int8.onnx',
        url: '$_whisperSmall/small-decoder.int8.onnx',
        sizeBytes: 262226114,
      ),
      ModelFile(
        name: 'small-tokens.txt',
        url: '$_whisperSmall/small-tokens.txt',
        sizeBytes: 816730,
      ),
    ],
  ),

  AsrModel(
    id: 'whisper-base',
    name: 'Whisper Base',
    description: '99 языков, компактнее и быстрее Small. Точность ниже.',
    arch: ModelArch.whisper,
    languages: _whisperLangs,
    speedScore: 60,
    accuracyScore: 72,
    supportsTranslate: true,
    encoderFile: 'base-encoder.int8.onnx',
    decoderFile: 'base-decoder.int8.onnx',
    tokensFile: 'base-tokens.txt',
    files: [
      ModelFile(
        name: 'base-encoder.int8.onnx',
        url: '$_whisperBase/base-encoder.int8.onnx',
        sizeBytes: 29120534,
      ),
      ModelFile(
        name: 'base-decoder.int8.onnx',
        url: '$_whisperBase/base-decoder.int8.onnx',
        sizeBytes: 130672026,
      ),
      ModelFile(
        name: 'base-tokens.txt',
        url: '$_whisperBase/base-tokens.txt',
        sizeBytes: 816730,
      ),
    ],
  ),

  AsrModel(
    id: 'whisper-tiny',
    name: 'Whisper Tiny',
    description: 'Самая маленькая. Для коротких заметок и слабых устройств.',
    arch: ModelArch.whisper,
    languages: _whisperLangs,
    speedScore: 85,
    accuracyScore: 55,
    supportsTranslate: true,
    encoderFile: 'tiny-encoder.int8.onnx',
    decoderFile: 'tiny-decoder.int8.onnx',
    tokensFile: 'tiny-tokens.txt',
    files: [
      ModelFile(
        name: 'tiny-encoder.int8.onnx',
        url: '$_whisperTiny/tiny-encoder.int8.onnx',
        sizeBytes: 12937772,
      ),
      ModelFile(
        name: 'tiny-decoder.int8.onnx',
        url: '$_whisperTiny/tiny-decoder.int8.onnx',
        sizeBytes: 89855401,
      ),
      ModelFile(
        name: 'tiny-tokens.txt',
        url: '$_whisperTiny/tiny-tokens.txt',
        sizeBytes: 816730,
      ),
    ],
  ),

  AsrModel(
    id: 'parakeet-tdt-0.6b-v3',
    name: 'Parakeet TDT 0.6B v3',
    description: '25 европейских языков, включая русский. Крупная, но быстрая.',
    arch: ModelArch.nemoTransducer,
    languages: [
      'ru',
      'en',
      'uk',
      'de',
      'fr',
      'es',
      'it',
      'pt',
      'nl',
      'pl',
      'cs',
      'sk',
      'bg',
      'hr',
      'da',
      'et',
      'fi',
      'el',
      'hu',
      'lv',
      'lt',
      'mt',
      'ro',
      'sl',
      'sv',
    ],
    speedScore: 65,
    accuracyScore: 84,
    encoderFile: 'encoder.int8.onnx',
    decoderFile: 'decoder.int8.onnx',
    joinerFile: 'joiner.int8.onnx',
    tokensFile: 'tokens.txt',
    files: [
      ModelFile(
        name: 'encoder.int8.onnx',
        url: '$_parakeetV3/encoder.int8.onnx',
        sizeBytes: 652184281,
      ),
      ModelFile(
        name: 'decoder.int8.onnx',
        url: '$_parakeetV3/decoder.int8.onnx',
        sizeBytes: 11845275,
      ),
      ModelFile(
        name: 'joiner.int8.onnx',
        url: '$_parakeetV3/joiner.int8.onnx',
        sizeBytes: 6355277,
      ),
      ModelFile(
        name: 'tokens.txt',
        url: '$_parakeetV3/tokens.txt',
        sizeBytes: 93939,
      ),
    ],
  ),
];

AsrModel? modelById(String id) {
  for (final m in kModelCatalog) {
    if (m.id == id) return m;
  }
  return null;
}

/// Модель по умолчанию для нового пользователя — русская и самая точная.
const String kDefaultModelId = 'giga-am-v3-rnnt-ru';

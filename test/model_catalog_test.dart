import 'package:flutter_test/flutter_test.dart';
import 'package:handy/models/asr_model.dart';

void main() {
  test('каждая модель описана полностью', () {
    for (final model in kModelCatalog) {
      expect(model.files, isNotEmpty, reason: model.id);
      expect(model.tokensFile, isNotEmpty, reason: model.id);

      // Файлы, на которые ссылается модель, должны быть в списке загрузки —
      // иначе распознаватель получит путь к несуществующему файлу.
      final names = model.files.map((f) => f.name).toSet();
      for (final required in [
        model.encoderFile,
        model.decoderFile,
        model.joinerFile,
        model.modelFile,
        model.tokensFile,
      ]) {
        if (required != null) {
          expect(names, contains(required), reason: '${model.id}: $required');
        }
      }

      switch (model.arch) {
        case ModelArch.nemoTransducer:
          expect(model.encoderFile, isNotNull, reason: model.id);
          expect(model.decoderFile, isNotNull, reason: model.id);
          expect(model.joinerFile, isNotNull, reason: model.id);
        case ModelArch.nemoCtc:
          expect(model.modelFile, isNotNull, reason: model.id);
        case ModelArch.nemotronStreaming:
          expect(model.encoderFile, isNotNull, reason: model.id);
          expect(model.decoderFile, isNotNull, reason: model.id);
          expect(model.joinerFile, isNotNull, reason: model.id);
        case ModelArch.whisper:
          expect(model.encoderFile, isNotNull, reason: model.id);
          expect(model.decoderFile, isNotNull, reason: model.id);
      }

      for (final file in model.files) {
        expect(file.url, startsWith('https://'), reason: file.name);
        expect(file.sizeBytes, greaterThan(0), reason: file.name);
      }
    }
  });

  test('идентификаторы уникальны', () {
    final ids = kModelCatalog.map((m) => m.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('модель по умолчанию есть в каталоге и понимает русский', () {
    final model = modelById(kDefaultModelId);
    expect(model, isNotNull);
    expect(model!.isRussian, isTrue);
  });
}

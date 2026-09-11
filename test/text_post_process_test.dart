import 'package:flutter_test/flutter_test.dart';
import 'package:handy/services/text_post_process.dart';

void main() {
  group('словарь замен', () {
    test('меняет слово целиком и не лезет внутрь других слов', () {
      final result = postProcess(
        'Пишем на флаттере, а флаттерный код читаем',
        customWords: {'флаттере': 'Flutter'},
      );

      expect(result, 'Пишем на Flutter, а флаттерный код читаем');
    });

    test('сохраняет заглавную букву исходного слова', () {
      final result = postProcess(
        'Джаваскрипт — это не жаваскрипт',
        customWords: {'джаваскрипт': 'JavaScript'},
      );

      expect(result, startsWith('JavaScript'));
    });
  });

  group('слова-паразиты', () {
    test('убирает их, не трогая похожие слова', () {
      final result = postProcess(
        'Ну нужно вот это типа сделать',
        removeFillerWords: true,
      );

      expect(result, 'Нужно это сделать');
    });

    test('без флага текст остаётся как есть', () {
      const input = 'Ну вот как бы всё';
      expect(postProcess(input), input);
    });
  });

  test('чистит лишние пробелы перед знаками препинания', () {
    expect(postProcess('текст  с   пробелами , и точкой .'),
        'текст с пробелами, и точкой.');
  });
}

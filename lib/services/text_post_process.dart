/// Лёгкая пост-обработка расшифровки: словарь замен и чистка слов-паразитов.
/// Аналог `CustomWords` и `FillerWordRemoval` из десктопного Handy —
/// без обращений к облачным LLM, всё локально и мгновенно.
library;

const _russianFillers = <String>[
  'э',
  'ээ',
  'эээ',
  'эм',
  'ммм',
  'мм',
  'ну',
  'вот',
  'типа',
  'как бы',
  'короче',
  'значит',
  'в общем',
  'это самое',
  'так сказать',
];

const _englishFillers = <String>[
  'uh',
  'um',
  'umm',
  'erm',
  'hmm',
  'like',
  'you know',
  'i mean',
  'sort of',
  'kind of',
];

/// Применяет к тексту пользовательские правила.
///
/// Порядок важен: сначала убираем мусор, потом чиним слова из словаря —
/// иначе замена может попасть внутрь удаляемого куска.
String postProcess(
  String text, {
  bool removeFillerWords = false,
  Map<String, String> customWords = const {},
}) {
  var result = text;

  if (removeFillerWords) result = _removeFillers(result);
  if (customWords.isNotEmpty) result = _applyCustomWords(result, customWords);

  return _tidyWhitespace(result);
}

String _removeFillers(String text) {
  var result = text;

  for (final filler in [..._russianFillers, ..._englishFillers]) {
    // Только отдельные слова: «ну» не должно выгрызать середину «нужно».
    final pattern = RegExp(
      r'(?<![\wЀ-ӿ])' +
          RegExp.escape(filler) +
          r'(?![\wЀ-ӿ])[,]?\s*',
      caseSensitive: false,
      unicode: true,
    );
    result = result.replaceAll(pattern, '');
  }

  return _capitalizeSentences(result);
}

String _applyCustomWords(String text, Map<String, String> replacements) {
  var result = text;

  for (final entry in replacements.entries) {
    if (entry.key.trim().isEmpty) continue;

    final pattern = RegExp(
      r'(?<![\wЀ-ӿ])' +
          RegExp.escape(entry.key) +
          r'(?![\wЀ-ӿ])',
      caseSensitive: false,
      unicode: true,
    );
    result = result.replaceAllMapped(pattern, (match) {
      final original = match.group(0)!;
      // Слово стояло с большой буквы — замена тоже должна.
      final startsUpper =
          original.isNotEmpty && original[0] == original[0].toUpperCase() &&
              original[0] != original[0].toLowerCase();
      if (!startsUpper || entry.value.isEmpty) return entry.value;
      return entry.value[0].toUpperCase() + entry.value.substring(1);
    });
  }

  return result;
}

/// После вычисток предложение может начаться со строчной буквы — поправим.
String _capitalizeSentences(String text) {
  final buffer = StringBuffer();
  var capitalizeNext = true;

  for (final rune in text.runes) {
    final char = String.fromCharCode(rune);
    if (capitalizeNext && RegExp(r'[\wЀ-ӿ]', unicode: true).hasMatch(char)) {
      buffer.write(char.toUpperCase());
      capitalizeNext = false;
    } else {
      buffer.write(char);
      if (char == '.' || char == '!' || char == '?' || char == '\n') {
        capitalizeNext = true;
      }
    }
  }

  return buffer.toString();
}

String _tidyWhitespace(String text) => text
    .replaceAll(RegExp(r'[ \t]+'), ' ')
    .replaceAllMapped(RegExp(r' +([,.!?;:])'), (m) => m.group(1)!)
    .replaceAll(RegExp(r'\n{3,}'), '\n\n')
    .trim();

/// Человеческие названия языков для подсказки многоязычным моделям.
library;

import '../models/settings.dart';

const Map<String, String> kLanguageNames = {
  kAutoLanguage: 'Определять автоматически',
  'ru': 'Русский',
  'en': 'English',
  'uk': 'Українська',
  'de': 'Deutsch',
  'fr': 'Français',
  'es': 'Español',
  'it': 'Italiano',
  'pt': 'Português',
  'pl': 'Polski',
  'tr': 'Türkçe',
  'ar': 'العربية',
  'zh': '中文',
  'ja': '日本語',
  'ko': '한국어',
  'nl': 'Nederlands',
  'vi': 'Tiếng Việt',
  'hi': 'हिन्दी',
  'cs': 'Čeština',
  'sk': 'Slovenčina',
  'bg': 'Български',
  'hr': 'Hrvatski',
  'da': 'Dansk',
  'et': 'Eesti',
  'fi': 'Suomi',
  'hu': 'Magyar',
  'nb': 'Norsk bokmål',
  'ro': 'Română',
  'sv': 'Svenska',
  'sl': 'Slovenščina',
  'lt': 'Lietuvių',
  'lv': 'Latviešu',
  'el': 'Ελληνικά',
  'mt': 'Malti',
};

/// Название языка или сам код, если названия нет.
String languageName(String code) => kLanguageNames[code] ?? code;

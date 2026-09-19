/// Переходы между экранами в одном месте.
///
/// Раньше `MaterialPageRoute(builder: (_) => const ModelsScreen())` был
/// продублирован в четырёх файлах. Теперь экран открывается вызовом
/// `openModels(context)` — и правится централизованно.
library;

import 'package:flutter/material.dart';

import 'screens/custom_words_screen.dart';
import 'screens/history_screen.dart';
import 'screens/models_screen.dart';
import 'screens/settings/settings_screen.dart';

Future<void> openModels(BuildContext context) => Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ModelsScreen()),
    );

Future<void> openHistory(BuildContext context) => Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const HistoryScreen()),
    );

Future<void> openSettings(BuildContext context) => Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
    );

Future<void> openCustomWords(BuildContext context) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CustomWordsScreen()),
    );

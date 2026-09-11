import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/settings.dart';

/// Хранит настройки одним JSON-блобом в SharedPreferences.
///
/// Одно значение вместо два десятка ключей: настройки всегда читаются и
/// пишутся целиком, так что дробить их незачем.
class SettingsService {
  static const _key = 'handy.settings.v1';

  Future<Settings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return const Settings();

    try {
      return Settings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Повреждённые или несовместимые настройки — не повод падать на старте.
      return const Settings();
    }
  }

  Future<void> save(Settings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(settings.toJson()));
  }

  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

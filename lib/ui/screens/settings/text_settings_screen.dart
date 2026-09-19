import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/settings.dart';
import '../../../state/app_controller.dart';
import '../../navigation.dart';
import 'settings_common.dart';

/// Что происходит с готовым текстом.
class TextSettingsScreen extends StatelessWidget {
  const TextSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final settings = controller.settings;
    final rules = settings.customWords.length;

    return SettingsPage(
      title: 'Текст',
      children: [
        ListTile(
          leading: const Icon(Icons.output_rounded),
          title: const Text('После распознавания'),
          subtitle: Text(_afterLabel(settings.afterTranscribe)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () async {
            final picked = await pickOption<AfterTranscribe>(
              context: context,
              title: 'После распознавания',
              current: settings.afterTranscribe,
              options: [
                for (final value in AfterTranscribe.values)
                  (value, _afterLabel(value)),
              ],
            );
            if (picked != null && context.mounted) {
              await context.updateSettings(
                settings.copyWith(afterTranscribe: picked),
              );
            }
          },
        ),
        const SettingsHeader('Чистка'),
        SwitchListTile(
          secondary: const Icon(Icons.cleaning_services_rounded),
          title: const Text('Убирать слова-паразиты'),
          subtitle: const Text('«э-э», «ну», «как бы» и подобные'),
          value: settings.removeFillerWords,
          onChanged: (value) => controller.updateSettings(
            settings.copyWith(removeFillerWords: value),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.spellcheck_rounded),
          title: const Text('Словарь замен'),
          subtitle: Text(
            rules == 0
                ? 'Исправлять имена и термины, которые модель слышит неверно'
                : '$rules ${_rulesPlural(rules)}',
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => openCustomWords(context),
        ),
      ],
    );
  }

  static String _afterLabel(AfterTranscribe value) => switch (value) {
        AfterTranscribe.nothing => 'Оставить на экране',
        AfterTranscribe.copy => 'Копировать в буфер',
        AfterTranscribe.copyAndShare => 'Копировать и предложить отправить',
      };

  static String _rulesPlural(int count) {
    final mod10 = count % 10;
    final mod100 = count % 100;
    if (mod10 == 1 && mod100 != 11) return 'правило';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
      return 'правила';
    }
    return 'правил';
  }
}

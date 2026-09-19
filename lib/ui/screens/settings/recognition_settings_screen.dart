import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/settings.dart';
import '../../../state/app_controller.dart';
import '../../languages.dart';
import '../../navigation.dart';
import '../../tokens.dart';
import 'settings_common.dart';

/// Чем и на каком языке распознавать.
class RecognitionSettingsScreen extends StatelessWidget {
  const RecognitionSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final settings = controller.settings;
    final model = controller.selectedModel;

    return SettingsPage(
      title: 'Распознавание',
      children: [
        ListTile(
          leading: const Icon(Icons.memory_rounded),
          title: const Text('Модель'),
          subtitle: Text(model?.name ?? 'Не выбрана'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => openModels(context),
        ),

        if (model != null && model.isMultilingual)
          ListTile(
            leading: const Icon(Icons.translate_rounded),
            title: const Text('Язык речи'),
            subtitle: Text(languageName(settings.language)),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () async {
              final picked = await pickOption<String>(
                context: context,
                title: 'Язык речи',
                current: settings.language,
                options: [
                  (kAutoLanguage, languageName(kAutoLanguage)),
                  for (final code in model.languages.where((l) => l != 'multi'))
                    (code, languageName(code)),
                ],
              );
              if (picked != null && context.mounted) {
                await context.updateSettings(
                  settings.copyWith(language: picked),
                );
              }
            },
          ),

        if (model != null && model.supportsTranslate)
          SwitchListTile(
            secondary: const Icon(Icons.g_translate_rounded),
            title: const Text('Переводить на английский'),
            subtitle: const Text('Модель сразу выдаёт английский текст'),
            value: settings.translateToEnglish,
            onChanged: (value) => controller.updateSettings(
              settings.copyWith(translateToEnglish: value),
            ),
          ),

        const SettingsNote(
          'Распознавание идёт на устройстве. Интернет нужен только на время '
          'скачивания модели.',
        ),

        ExpansionTile(
          leading: const Icon(Icons.tune_rounded),
          title: const Text('Дополнительно'),
          childrenPadding: const EdgeInsets.only(bottom: kGapS),
          children: [
            SettingsSlider(
              icon: Icons.memory_outlined,
              title: 'Потоков процессора',
              subtitle: '${settings.numThreads} — больше значит быстрее, '
                  'но телефон сильнее греется',
              value: settings.numThreads.toDouble(),
              min: 1,
              max: 8,
              divisions: 7,
              onChanged: (value) => controller.updateSettings(
                settings.copyWith(numThreads: value.round()),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/settings.dart';
import '../../../state/app_controller.dart';
import 'settings_common.dart';

/// Внешний вид и отклик на действия.
class AppearanceSettingsScreen extends StatelessWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final settings = controller.settings;

    return SettingsPage(
      title: 'Оформление',
      children: [
        ListTile(
          leading: const Icon(Icons.palette_outlined),
          title: const Text('Тема'),
          subtitle: Text(_themeLabel(settings.theme)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () async {
            final picked = await pickOption<AppTheme>(
              context: context,
              title: 'Тема',
              current: settings.theme,
              options: [
                for (final value in AppTheme.values) (value, _themeLabel(value)),
              ],
            );
            if (picked != null && context.mounted) {
              await context.updateSettings(settings.copyWith(theme: picked));
            }
          },
        ),

        const SettingsHeader('Отклик'),
        SwitchListTile(
          secondary: const Icon(Icons.volume_up_rounded),
          title: const Text('Звук начала и конца записи'),
          value: settings.soundFeedback,
          onChanged: (value) => controller.updateSettings(
            settings.copyWith(soundFeedback: value),
          ),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.vibration_rounded),
          title: const Text('Вибрация'),
          value: settings.hapticFeedback,
          onChanged: (value) => controller.updateSettings(
            settings.copyWith(hapticFeedback: value),
          ),
        ),
      ],
    );
  }

  static String _themeLabel(AppTheme theme) => switch (theme) {
        AppTheme.system => 'Как в системе',
        AppTheme.light => 'Светлая',
        AppTheme.dark => 'Тёмная',
      };
}

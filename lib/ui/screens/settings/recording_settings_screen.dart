import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/settings.dart';
import '../../../state/app_controller.dart';
import '../../tokens.dart';
import 'settings_common.dart';

/// Как ведёт себя кнопка и что происходит со звуком до распознавания.
class RecordingSettingsScreen extends StatelessWidget {
  const RecordingSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final settings = controller.settings;

    return SettingsPage(
      title: 'Запись',
      children: [
        const SettingsHeader('Кнопка'),
        RadioGroup<RecordMode>(
          groupValue: settings.recordMode,
          onChanged: (value) {
            if (value != null) {
              controller.updateSettings(settings.copyWith(recordMode: value));
            }
          },
          child: const Column(
            children: [
              RadioListTile<RecordMode>(
                value: RecordMode.hold,
                title: Text('Удерживать'),
                subtitle: Text('Держите палец — идёт запись, отпустили — текст'),
              ),
              RadioListTile<RecordMode>(
                value: RecordMode.toggle,
                title: Text('Нажатием'),
                subtitle: Text('Тап начинает запись, второй тап заканчивает'),
              ),
            ],
          ),
        ),

        const SettingsHeader('Звук'),
        SwitchListTile(
          secondary: const Icon(Icons.graphic_eq_rounded),
          title: const Text('Отсекать тишину'),
          subtitle: const Text('Паузы не попадают в распознавание — быстрее'),
          value: settings.vadEnabled,
          onChanged: (value) =>
              controller.updateSettings(settings.copyWith(vadEnabled: value)),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.screen_lock_portrait_rounded),
          title: const Text('Не гасить экран при записи'),
          value: settings.keepScreenAwake,
          onChanged: (value) => controller.updateSettings(
            settings.copyWith(keepScreenAwake: value),
          ),
        ),

        const SettingsNote('Одна запись длится не дольше 10 минут — дальше '
            'она автоматически уходит в распознавание.'),

        if (settings.vadEnabled)
          ExpansionTile(
            leading: const Icon(Icons.tune_rounded),
            title: const Text('Дополнительно'),
            childrenPadding: const EdgeInsets.only(bottom: kGapS),
            children: [
              SettingsSlider(
                icon: Icons.hearing_rounded,
                title: 'Чувствительность',
                subtitle: settings.vadThreshold >= 0.6
                    ? 'Строже — реже ловит шум, может резать тихую речь'
                    : settings.vadThreshold <= 0.4
                        ? 'Мягче — слышит тихую речь, но пропускает шум'
                        : 'Обычная',
                value: settings.vadThreshold,
                min: 0.1,
                max: 0.9,
                divisions: 16,
                onChanged: (value) => controller.updateSettings(
                  settings.copyWith(vadThreshold: value),
                ),
              ),
              SettingsSlider(
                icon: Icons.timer_outlined,
                title: 'Пауза для конца фразы',
                subtitle: '${settings.minSilenceDuration.toStringAsFixed(1)} с '
                    'тишины считается концом фразы',
                value: settings.minSilenceDuration,
                min: 0.2,
                max: 2.0,
                divisions: 18,
                onChanged: (value) => controller.updateSettings(
                  settings.copyWith(minSilenceDuration: value),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

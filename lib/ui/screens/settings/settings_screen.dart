import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../state/app_controller.dart';
import '../../languages.dart';
import '../../navigation.dart';
import '../../tokens.dart';
import '../../widgets/handy_card.dart';
import '../../widgets/model_download_progress.dart';
import 'about_screen.dart';
import 'appearance_settings_screen.dart';
import 'recognition_settings_screen.dart';
import 'recording_settings_screen.dart';
import 'storage_settings_screen.dart';
import 'text_settings_screen.dart';

/// Корень настроек: активная модель и шесть разделов вместо простыни
/// из двадцати пунктов.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final settings = controller.settings;
    final model = controller.selectedModel;

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(kGapL, 0, kGapL, kGapXL),
        children: [
          HandyCard(
            onTap: () => openModels(context),
            child: Row(
              children: [
                Icon(
                  Icons.memory_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: kGapM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        model?.name ?? 'Модель не выбрана',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        model == null
                            ? 'Нажмите, чтобы выбрать'
                            : '${formatSize(model.sizeBytes)}'
                                '${model.isMultilingual ? '  ·  ${languageName(settings.language)}' : ''}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color:
                                  Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
          const SizedBox(height: kGapL),

          _Section(
            icon: Icons.record_voice_over_rounded,
            title: 'Распознавание',
            subtitle: 'Модель, язык, производительность',
            builder: (_) => const RecognitionSettingsScreen(),
          ),
          _Section(
            icon: Icons.mic_rounded,
            title: 'Запись',
            subtitle: 'Поведение кнопки, отсечение тишины',
            builder: (_) => const RecordingSettingsScreen(),
          ),
          _Section(
            icon: Icons.notes_rounded,
            title: 'Текст',
            subtitle: 'Что делать с расшифровкой, словарь замен',
            builder: (_) => const TextSettingsScreen(),
          ),
          _Section(
            icon: Icons.storage_rounded,
            title: 'Хранилище',
            subtitle: 'История, аудиозаписи, место на диске',
            builder: (_) => const StorageSettingsScreen(),
          ),
          _Section(
            icon: Icons.palette_outlined,
            title: 'Оформление',
            subtitle: 'Тема, звук, вибрация',
            builder: (_) => const AppearanceSettingsScreen(),
          ),
          _Section(
            icon: Icons.info_outline_rounded,
            title: 'О приложении',
            subtitle: 'Офлайн-режим, лицензии, сброс настроек',
            builder: (_) => const AboutScreen(),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.builder,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: kGapS),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: kGapS),
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: builder),
        ),
      ),
    );
  }
}

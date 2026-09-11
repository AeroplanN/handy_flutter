import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/asr_model.dart';
import '../../models/settings.dart';
import '../../state/app_controller.dart';
import 'custom_words_screen.dart';
import 'models_screen.dart';

/// Языки, которые можно подсказать многоязычной модели.
const _languageNames = <String, String>{
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
};

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final settings = controller.settings;
    final model = controller.selectedModel;

    void update(Settings next) => controller.updateSettings(next);

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const _SectionHeader('Распознавание'),
          ListTile(
            leading: const Icon(Icons.memory_rounded),
            title: const Text('Модель'),
            subtitle: Text(model?.name ?? 'Не выбрана'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ModelsScreen()),
            ),
          ),
          if (model != null && model.isMultilingual)
            ListTile(
              leading: const Icon(Icons.translate_rounded),
              title: const Text('Язык речи'),
              subtitle: Text(
                _languageNames[settings.language] ?? settings.language,
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _pickLanguage(context, controller, model),
            ),
          if (model != null && model.supportsTranslate)
            SwitchListTile(
              secondary: const Icon(Icons.g_translate_rounded),
              title: const Text('Переводить на английский'),
              subtitle: const Text(
                'Модель сразу выдаёт английский текст вместо расшифровки',
              ),
              value: settings.translateToEnglish,
              onChanged: (value) =>
                  update(settings.copyWith(translateToEnglish: value)),
            ),
          ListTile(
            leading: const Icon(Icons.memory_outlined),
            title: const Text('Потоков процессора'),
            subtitle: Text(
              '${settings.numThreads} — больше значит быстрее, но горячее',
            ),
            trailing: SizedBox(
              width: 140,
              child: Slider(
                value: settings.numThreads.toDouble(),
                min: 1,
                max: 8,
                divisions: 7,
                label: '${settings.numThreads}',
                onChanged: (value) =>
                    update(settings.copyWith(numThreads: value.round())),
              ),
            ),
          ),

          const _SectionHeader('Запись'),
          RadioGroup<RecordMode>(
            groupValue: settings.recordMode,
            onChanged: (value) =>
                update(settings.copyWith(recordMode: value)),
            child: const Column(
              children: [
                RadioListTile<RecordMode>(
                  secondary: Icon(Icons.touch_app_rounded),
                  title: Text('Удерживать кнопку'),
                  subtitle: Text('Запись идёт, пока палец на кнопке'),
                  value: RecordMode.hold,
                ),
                RadioListTile<RecordMode>(
                  secondary: Icon(Icons.toggle_on_rounded),
                  title: Text('Нажатие включает и выключает'),
                  subtitle: Text('Удобно для длинных надиктовок'),
                  value: RecordMode.toggle,
                ),
              ],
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.graphic_eq_rounded),
            title: const Text('Отсекать тишину (VAD)'),
            subtitle: const Text(
              'Silero VAD вырезает паузы — распознавание идёт быстрее',
            ),
            value: settings.vadEnabled,
            onChanged: (value) =>
                update(settings.copyWith(vadEnabled: value)),
          ),
          if (settings.vadEnabled) ...[
            ListTile(
              leading: const Icon(Icons.tune_rounded),
              title: const Text('Чувствительность VAD'),
              subtitle: Text(
                settings.vadThreshold.toStringAsFixed(2) +
                    (settings.vadThreshold > 0.6
                        ? ' — строже, отсекает тихую речь'
                        : settings.vadThreshold < 0.4
                            ? ' — мягче, ловит шёпот и шум'
                            : ''),
              ),
              trailing: SizedBox(
                width: 140,
                child: Slider(
                  value: settings.vadThreshold,
                  min: 0.1,
                  max: 0.9,
                  divisions: 16,
                  onChanged: (value) =>
                      update(settings.copyWith(vadThreshold: value)),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: const Text('Пауза для конца фразы'),
              subtitle: Text('${settings.minSilenceDuration.toStringAsFixed(1)} с'),
              trailing: SizedBox(
                width: 140,
                child: Slider(
                  value: settings.minSilenceDuration,
                  min: 0.2,
                  max: 2.0,
                  divisions: 18,
                  onChanged: (value) =>
                      update(settings.copyWith(minSilenceDuration: value)),
                ),
              ),
            ),
          ],
          SwitchListTile(
            secondary: const Icon(Icons.screen_lock_portrait_rounded),
            title: const Text('Не гасить экран при записи'),
            value: settings.keepScreenAwake,
            onChanged: (value) =>
                update(settings.copyWith(keepScreenAwake: value)),
          ),

          const _SectionHeader('Готовый текст'),
          ListTile(
            leading: const Icon(Icons.output_rounded),
            title: const Text('Что делать после распознавания'),
            subtitle: Text(switch (settings.afterTranscribe) {
              AfterTranscribe.nothing => 'Ничего, только показать',
              AfterTranscribe.copy => 'Скопировать в буфер обмена',
              AfterTranscribe.copyAndShare => 'Скопировать и открыть «Поделиться»',
            }),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _pickAfterTranscribe(context, controller),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.cleaning_services_rounded),
            title: const Text('Убирать слова-паразиты'),
            subtitle: const Text('«э-э», «ну», «как бы», «типа»'),
            value: settings.removeFillerWords,
            onChanged: (value) =>
                update(settings.copyWith(removeFillerWords: value)),
          ),
          ListTile(
            leading: const Icon(Icons.spellcheck_rounded),
            title: const Text('Словарь замен'),
            subtitle: Text(
              settings.customWords.isEmpty
                  ? 'Исправлять имена и термины автоматически'
                  : '${settings.customWords.length} правил',
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CustomWordsScreen()),
            ),
          ),

          const _SectionHeader('История'),
          ListTile(
            leading: const Icon(Icons.format_list_numbered_rounded),
            title: const Text('Хранить расшифровок'),
            subtitle: Text('${settings.historyLimit}'),
            trailing: SizedBox(
              width: 140,
              child: Slider(
                value: settings.historyLimit.toDouble().clamp(20, 1000),
                min: 20,
                max: 1000,
                divisions: 49,
                label: '${settings.historyLimit}',
                onChanged: (value) =>
                    update(settings.copyWith(historyLimit: value.round())),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.audiotrack_rounded),
            title: const Text('Хранить аудиозаписи'),
            subtitle: Text(settings.recordingRetention.label),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _pickRetention(context, controller),
          ),

          const _SectionHeader('Оформление и отклик'),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Тема'),
            subtitle: Text(switch (settings.theme) {
              AppTheme.system => 'Как в системе',
              AppTheme.light => 'Светлая',
              AppTheme.dark => 'Тёмная',
            }),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _pickTheme(context, controller),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.volume_up_rounded),
            title: const Text('Звук начала и конца записи'),
            value: settings.soundFeedback,
            onChanged: (value) =>
                update(settings.copyWith(soundFeedback: value)),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.vibration_rounded),
            title: const Text('Вибрация'),
            value: settings.hapticFeedback,
            onChanged: (value) =>
                update(settings.copyWith(hapticFeedback: value)),
          ),

          const _SectionHeader('О приложении'),
          const _StorageTile(),
          const ListTile(
            leading: Icon(Icons.lock_outline_rounded),
            title: Text('Всё работает офлайн'),
            subtitle: Text(
              'Аудио и текст не покидают устройство. Интернет нужен только '
              'для скачивания моделей.',
            ),
          ),
          const ListTile(
            leading: Icon(Icons.code_rounded),
            title: Text('Handy для Android и iOS'),
            subtitle: Text(
              'Порт cjpais/handy на Flutter. Распознавание — sherpa-onnx, '
              'русская модель — GigaAM.',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickLanguage(
    BuildContext context,
    AppController controller,
    AsrModel model,
  ) async {
    final available = [
      kAutoLanguage,
      ...model.languages.where((l) => l != 'multi'),
    ];

    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => RadioGroup<String>(
        groupValue: controller.settings.language,
        onChanged: (value) => Navigator.of(context).pop(value),
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final code in available)
              RadioListTile<String>(
                title: Text(_languageNames[code] ?? code),
                value: code,
              ),
          ],
        ),
      ),
    );

    if (picked != null) {
      await controller.updateSettings(
        controller.settings.copyWith(language: picked),
      );
    }
  }

  Future<void> _pickAfterTranscribe(
    BuildContext context,
    AppController controller,
  ) async {
    final picked = await showModalBottomSheet<AfterTranscribe>(
      context: context,
      showDragHandle: true,
      builder: (context) => RadioGroup<AfterTranscribe>(
        groupValue: controller.settings.afterTranscribe,
        onChanged: (value) => Navigator.of(context).pop(value),
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final option in AfterTranscribe.values)
              RadioListTile<AfterTranscribe>(
                title: Text(switch (option) {
                  AfterTranscribe.nothing => 'Ничего, только показать',
                  AfterTranscribe.copy => 'Скопировать в буфер обмена',
                  AfterTranscribe.copyAndShare =>
                    'Скопировать и открыть «Поделиться»',
                }),
                value: option,
              ),
          ],
        ),
      ),
    );

    if (picked != null) {
      await controller.updateSettings(
        controller.settings.copyWith(afterTranscribe: picked),
      );
    }
  }

  Future<void> _pickRetention(
    BuildContext context,
    AppController controller,
  ) async {
    final picked = await showModalBottomSheet<RecordingRetention>(
      context: context,
      showDragHandle: true,
      builder: (context) => RadioGroup<RecordingRetention>(
        groupValue: controller.settings.recordingRetention,
        onChanged: (value) => Navigator.of(context).pop(value),
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final option in RecordingRetention.values)
              RadioListTile<RecordingRetention>(
                title: Text(option.label),
                value: option,
              ),
          ],
        ),
      ),
    );

    if (picked != null) {
      await controller.updateSettings(
        controller.settings.copyWith(recordingRetention: picked),
      );
    }
  }

  Future<void> _pickTheme(
    BuildContext context,
    AppController controller,
  ) async {
    final picked = await showModalBottomSheet<AppTheme>(
      context: context,
      showDragHandle: true,
      builder: (context) => RadioGroup<AppTheme>(
        groupValue: controller.settings.theme,
        onChanged: (value) => Navigator.of(context).pop(value),
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final option in AppTheme.values)
              RadioListTile<AppTheme>(
                title: Text(switch (option) {
                  AppTheme.system => 'Как в системе',
                  AppTheme.light => 'Светлая',
                  AppTheme.dark => 'Тёмная',
                }),
                value: option,
              ),
          ],
        ),
      ),
    );

    if (picked != null) {
      await controller.updateSettings(
        controller.settings.copyWith(theme: picked),
      );
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
        child: Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                letterSpacing: 1.1,
              ),
        ),
      );
}

/// Сколько места на диске занимают скачанные модели.
class _StorageTile extends StatelessWidget {
  const _StorageTile();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();

    return FutureBuilder<int>(
      future: controller.models.usedBytes(),
      builder: (context, snapshot) {
        final bytes = snapshot.data ?? 0;
        final mb = bytes / (1024 * 1024);

        return ListTile(
          leading: const Icon(Icons.sd_storage_outlined),
          title: const Text('Занято моделями'),
          subtitle: Text(
            mb >= 1024
                ? '${(mb / 1024).toStringAsFixed(2)} ГБ'
                : '${mb.round()} МБ',
          ),
        );
      },
    );
  }
}

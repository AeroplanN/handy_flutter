import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/settings.dart';
import '../../state/app_controller.dart';
import '../languages.dart';
import '../screens/settings/settings_screen.dart';
import '../tokens.dart';

/// Четыре настройки, которые меняют чаще всего, — без похода в раздел.
///
/// Открывается долгим тапом по шестерёнке и из меню «ещё» на главном экране.
Future<void> showQuickSettings(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (_) => const _QuickSettings(),
  );
}

class _QuickSettings extends StatelessWidget {
  const _QuickSettings();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final settings = controller.settings;
    final theme = Theme.of(context);
    final model = controller.selectedModel;

    void update(Settings next) => controller.updateSettings(next);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(kGapL, 0, kGapL, kGapL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: kGapM),
              child: Text('Быстрые настройки', style: theme.textTheme.titleMedium),
            ),

            _Label('Кнопка записи'),
            SegmentedButton<RecordMode>(
              segments: const [
                ButtonSegment(
                  value: RecordMode.hold,
                  label: Text('Удерживать'),
                  icon: Icon(Icons.touch_app_rounded, size: 18),
                ),
                ButtonSegment(
                  value: RecordMode.toggle,
                  label: Text('Нажатием'),
                  icon: Icon(Icons.radio_button_checked_rounded, size: 18),
                ),
              ],
              selected: {settings.recordMode},
              onSelectionChanged: (value) =>
                  update(settings.copyWith(recordMode: value.first)),
            ),
            const SizedBox(height: kGapL),

            _Label('После распознавания'),
            SegmentedButton<AfterTranscribe>(
              segments: const [
                ButtonSegment(
                  value: AfterTranscribe.nothing,
                  label: Text('Ничего'),
                ),
                ButtonSegment(
                  value: AfterTranscribe.copy,
                  label: Text('Копировать'),
                ),
                ButtonSegment(
                  value: AfterTranscribe.copyAndShare,
                  label: Text('И поделиться'),
                ),
              ],
              selected: {settings.afterTranscribe},
              onSelectionChanged: (value) =>
                  update(settings.copyWith(afterTranscribe: value.first)),
            ),
            const SizedBox(height: kGapS),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Убирать слова-паразиты'),
              value: settings.removeFillerWords,
              onChanged: (value) =>
                  update(settings.copyWith(removeFillerWords: value)),
            ),

            if (model != null && model.isMultilingual)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.translate_rounded),
                title: const Text('Язык речи'),
                subtitle: Text(languageName(settings.language)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  // Контекст шторки после pop уже мёртв — берём навигатор
                  // экрана заранее.
                  final navigator = Navigator.of(context);
                  navigator
                    ..pop()
                    ..push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SettingsScreen(),
                      ),
                    );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: kGapS),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

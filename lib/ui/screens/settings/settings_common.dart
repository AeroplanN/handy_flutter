import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/settings.dart';
import '../../../state/app_controller.dart';
import '../../tokens.dart';

/// Обёртка подэкрана настроек: одинаковая шапка и отступы у всех разделов.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: kGapXL),
        children: children,
      ),
    );
  }
}

/// Заголовок группы внутри раздела.
class SettingsHeader extends StatelessWidget {
  const SettingsHeader(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(kGapL, kGapXL, kGapL, kGapS),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.primary,
          letterSpacing: 1.1,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Пояснение под группой — там, где короткой подписи мало.
class SettingsNote extends StatelessWidget {
  const SettingsNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(kGapL, kGapS, kGapL, 0),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Ползунок с подписью значения — для порогов и лимитов.
class SettingsSlider extends StatelessWidget {
  const SettingsSlider({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: SizedBox(
        width: 140,
        child: Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// Выбор одного значения из списка — общая шторка для всех перечислений.
Future<T?> pickOption<T>({
  required BuildContext context,
  required String title,
  required List<(T value, String label)> options,
  required T current,
}) {
  return showModalBottomSheet<T>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(kGapL, 0, kGapL, kGapS),
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          Flexible(
            child: RadioGroup<T>(
              groupValue: current,
              onChanged: (value) => Navigator.of(context).pop(value),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final (value, label) in options)
                    RadioListTile<T>(title: Text(label), value: value),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Короткий путь к обновлению настроек из любого подэкрана.
extension SettingsUpdate on BuildContext {
  Future<void> updateSettings(Settings next) =>
      read<AppController>().updateSettings(next);
}

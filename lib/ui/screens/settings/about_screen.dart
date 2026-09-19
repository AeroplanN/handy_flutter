import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../state/app_controller.dart';
import '../../tokens.dart';
import '../../widgets/handy_wordmark.dart';
import 'settings_common.dart';

/// О приложении и сброс настроек.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SettingsPage(
      title: 'О приложении',
      children: [
        Padding(
          padding: const EdgeInsets.all(kGapXL),
          child: Column(
            children: [
              const HandyWordmark(size: 44),
              const SizedBox(height: kGapM),
              Text(
                'Офлайн-распознавание речи для Android и iOS',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),

        const ListTile(
          leading: Icon(Icons.wifi_off_rounded),
          title: Text('Работает без интернета'),
          subtitle: Text(
            'Запись и распознавание не покидают телефон. Сеть нужна только '
            'для скачивания моделей.',
          ),
        ),
        const ListTile(
          leading: Icon(Icons.favorite_outline_rounded),
          title: Text('Основано на открытых проектах'),
          subtitle: Text(
            'cjpais/Handy, sherpa-onnx, GigaAM, NVIDIA Nemotron, Whisper. '
            'Шрифт логотипа — Pacifico (SIL OFL 1.1).',
          ),
        ),

        const SettingsHeader('Сброс'),
        ListTile(
          leading: Icon(Icons.restart_alt_rounded, color: scheme.error),
          title: const Text('Сбросить настройки'),
          subtitle: const Text(
            'Вернёт значения по умолчанию. История и модели останутся.',
          ),
          onTap: () => _confirmReset(context),
        ),
      ],
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final controller = context.read<AppController>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Сбросить настройки?'),
        content: const Text(
          'Все параметры вернутся к значениям по умолчанию. Расшифровки и '
          'скачанные модели останутся на месте.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Сбросить'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) await controller.resetSettings();
  }
}

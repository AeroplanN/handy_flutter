import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/asr_model.dart';
import '../../../models/settings.dart';
import '../../../state/app_controller.dart';
import '../../tokens.dart';
import '../../widgets/model_download_progress.dart';
import 'settings_common.dart';

/// Сколько всего хранится и как долго.
class StorageSettingsScreen extends StatefulWidget {
  const StorageSettingsScreen({super.key});

  @override
  State<StorageSettingsScreen> createState() => _StorageSettingsScreenState();
}

class _StorageSettingsScreenState extends State<StorageSettingsScreen> {
  // Размеры считаются обходом файлов — держим результат, а не пересчитываем
  // на каждую перерисовку, как делал прежний экран.
  late Future<Map<String, int>> _sizes = _load();

  Future<Map<String, int>> _load() =>
      context.read<AppController>().models.usedBytesByModel();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final settings = controller.settings;

    return SettingsPage(
      title: 'Хранилище',
      children: [
        const SettingsHeader('История'),
        SettingsSlider(
          icon: Icons.history_rounded,
          title: 'Хранить расшифровок',
          subtitle: '${settings.historyLimit} последних; '
              'закреплённые не удаляются',
          value: settings.historyLimit.toDouble(),
          min: 20,
          max: 1000,
          divisions: 49,
          onChanged: (value) => controller.updateSettings(
            settings.copyWith(historyLimit: value.round()),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.audiotrack_rounded),
          title: const Text('Хранить аудиозаписи'),
          subtitle: Text(settings.recordingRetention.label),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () async {
            final picked = await pickOption<RecordingRetention>(
              context: context,
              title: 'Хранить аудиозаписи',
              current: settings.recordingRetention,
              options: [
                for (final value in RecordingRetention.values)
                  (value, value.label),
              ],
            );
            if (picked != null && context.mounted) {
              await context.updateSettings(
                settings.copyWith(recordingRetention: picked),
              );
            }
          },
        ),
        const SettingsNote(
          'Аудио остаётся на телефоне и нужно, чтобы переслать исходную '
          'запись из истории.',
        ),

        const SettingsHeader('Модели'),
        FutureBuilder<Map<String, int>>(
          future: _sizes,
          builder: (context, snapshot) {
            final sizes = snapshot.data;
            if (sizes == null) {
              return const ListTile(
                leading: Icon(Icons.storage_rounded),
                title: Text('Считаем занятое место…'),
              );
            }
            if (sizes.isEmpty) {
              return const ListTile(
                leading: Icon(Icons.storage_rounded),
                title: Text('Моделей на устройстве нет'),
              );
            }

            final total = sizes.values.fold(0, (sum, value) => sum + value);

            return Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.storage_rounded),
                  title: const Text('Занято моделями'),
                  subtitle: Text(formatSize(total)),
                ),
                for (final entry in sizes.entries)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      kGapXL + kGapL,
                      0,
                      kGapL,
                      kGapS,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            modelById(entry.key)?.name ?? entry.key,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(formatSize(entry.value)),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),

        const SettingsHeader('Очистка'),
        ListTile(
          leading: Icon(
            Icons.delete_sweep_outlined,
            color: Theme.of(context).colorScheme.error,
          ),
          title: const Text('Очистить историю'),
          subtitle: const Text('Удалит все расшифровки и аудиозаписи'),
          onTap: () => _confirmClear(controller),
        ),
      ],
    );
  }

  Future<void> _confirmClear(AppController controller) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Очистить историю?'),
        content: const Text(
          'Удалятся все расшифровки и аудиозаписи, включая закреплённые. '
          'Отменить это нельзя.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Очистить'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      await controller.clearHistory();
      if (mounted) setState(() => _sizes = _load());
    }
  }
}

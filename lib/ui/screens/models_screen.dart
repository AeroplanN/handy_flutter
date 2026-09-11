import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/asr_model.dart';
import '../../services/model_manager.dart';
import '../../state/app_controller.dart';

class ModelsScreen extends StatelessWidget {
  const ModelsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    // ModelManager шлёт свои уведомления о прогрессе загрузки.
    context.watch<ModelManager>();

    final russian = kModelCatalog.where((m) => m.languages.length == 1).toList();
    final multilingual =
        kModelCatalog.where((m) => m.languages.length > 1).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Модели')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const _SectionTitle('Русский язык'),
          for (final model in russian)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ModelCard(model: model, controller: controller),
            ),
          const SizedBox(height: 8),
          const _SectionTitle('Многоязычные'),
          for (final model in multilingual)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ModelCard(model: model, controller: controller),
            ),
          const SizedBox(height: 16),
          Text(
            'Модели скачиваются один раз и работают без интернета. '
            'Всё распознавание идёт на устройстве — записи никуда не уходят.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 12),
        child: Text(
          text,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                letterSpacing: 0.4,
              ),
        ),
      );
}

class ModelCard extends StatelessWidget {
  const ModelCard({
    super.key,
    required this.model,
    required this.controller,
  });

  final AsrModel model;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final status = controller.models.statusOf(model.id);
    final download = controller.models.downloadOf(model.id);
    final selected = controller.settings.modelId == model.id;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: status == ModelStatus.ready
            ? () => controller.selectModel(model)
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            model.name,
                            style: theme.textTheme.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (model.recommended) ...[
                          const SizedBox(width: 8),
                          _Chip(
                            label: 'рекомендуем',
                            color: scheme.primaryContainer,
                            textColor: scheme.onPrimaryContainer,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (selected)
                    Icon(Icons.check_circle_rounded, color: scheme.primary),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                model.description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _Metric(
                    icon: Icons.speed_rounded,
                    label: 'скорость',
                    value: model.speedScore,
                  ),
                  const SizedBox(width: 16),
                  _Metric(
                    icon: Icons.center_focus_strong_rounded,
                    label: 'точность',
                    value: model.accuracyScore,
                  ),
                  const Spacer(),
                  Text(
                    _formatSize(model.sizeBytes),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _Actions(
                model: model,
                controller: controller,
                status: status,
                download: download,
                selected: selected,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatSize(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} ГБ';
    }
    return '${(bytes / (1024 * 1024)).round()} МБ';
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.model,
    required this.controller,
    required this.status,
    required this.download,
    required this.selected,
  });

  final AsrModel model;
  final AppController controller;
  final ModelStatus status;
  final ModelDownload? download;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    switch (status) {
      case ModelStatus.downloading:
        final progress = download?.progress ?? 0;
        final received = download?.receivedBytes ?? 0;
        final total = download?.totalBytes ?? model.sizeBytes;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress == 0 ? null : progress,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${ModelCard._formatSize(received)} из '
                    '${ModelCard._formatSize(total)}'
                    '${download != null && download!.fileCount > 0 ? '  ·  файл ${download!.fileIndex}/${download!.fileCount}' : ''}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => controller.models.cancel(model.id),
                  child: const Text('Отменить'),
                ),
              ],
            ),
          ],
        );

      case ModelStatus.ready:
        return Row(
          children: [
            if (selected)
              Text(
                'Выбрана',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.primary,
                ),
              )
            else
              FilledButton.tonal(
                onPressed: () => controller.selectModel(model),
                child: const Text('Выбрать'),
              ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _confirmRemove(context),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Удалить'),
              style: TextButton.styleFrom(foregroundColor: scheme.error),
            ),
          ],
        );

      case ModelStatus.failed:
        return Row(
          children: [
            Expanded(
              child: Text(
                download?.error ?? 'Не удалось скачать',
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
              ),
            ),
            FilledButton(
              onPressed: () => controller.downloadModel(model),
              child: const Text('Повторить'),
            ),
          ],
        );

      case ModelStatus.notDownloaded:
        return Row(
          children: [
            FilledButton.icon(
              onPressed: () => controller.downloadModel(model),
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Скачать'),
            ),
          ],
        );
    }
  }

  Future<void> _confirmRemove(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Удалить «${model.name}»?'),
        content: Text(
          'Файлы модели (${ModelCard._formatSize(model.sizeBytes)}) '
          'будут удалены с устройства. Скачать снова можно в любой момент.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed == true) await controller.removeModel(model);
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(icon, size: 16, color: scheme.onSurfaceVariant),
        const SizedBox(width: 6),
        SizedBox(
          width: 52,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: value / 100,
              minHeight: 5,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.color,
    required this.textColor,
  });

  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 11, color: textColor),
        ),
      );
}

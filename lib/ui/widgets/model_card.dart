import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/asr_model.dart';
import '../../services/model_manager.dart';
import '../../state/app_controller.dart';
import '../tokens.dart';
import 'handy_card.dart';
import 'handy_chip.dart';
import 'model_download_progress.dart';

/// Карточка модели: что это, чем хороша, сколько весит и что с ней делать.
class ModelCard extends StatelessWidget {
  const ModelCard({super.key, required this.model});

  final AsrModel model;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    // Прогресс загрузки приходит из отдельного уведомителя.
    context.watch<ModelManager>();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final status = controller.models.statusOf(model.id);
    final selected = controller.settings.modelId == model.id;
    final ready = status == ModelStatus.ready;

    return HandyCard(
      selected: selected && ready,
      onTap: ready && !selected ? () => controller.selectModel(model) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  model.name,
                  style: theme.textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                formatSize(model.sizeBytes),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: kGapS),
          Wrap(
            spacing: kGapXS,
            runSpacing: kGapXS,
            children: [
              if (selected && ready)
                const HandyChip(
                  'Активна',
                  tone: ChipTone.accent,
                  icon: Icons.check_rounded,
                ),
              if (model.recommended) const HandyChip('Рекомендуем'),
              HandyChip(
                model.isMultilingual
                    ? '${model.languages.length} языков'
                    : 'Только русский',
                icon: Icons.language_rounded,
              ),
              if (model.supportsTranslate) const HandyChip('Умеет переводить'),
              if (model.speedScore >= 80)
                const HandyChip('Быстрая', icon: Icons.bolt_rounded),
              if (model.accuracyScore >= 92)
                const HandyChip('Точная', icon: Icons.verified_outlined),
            ],
          ),
          const SizedBox(height: kGapM),
          Text(
            model.description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: kGapM),
          _Metrics(model: model),
          const SizedBox(height: kGapM),
          _Actions(model: model, controller: controller, status: status,
              selected: selected),
        ],
      ),
    );
  }
}

/// Скорость и точность — две полоски, по которым модели сравнивают взглядом.
class _Metrics extends StatelessWidget {
  const _Metrics({required this.model});

  final AsrModel model;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Metric(
            label: 'скорость',
            value: model.speedScore,
            icon: Icons.speed_rounded,
          ),
        ),
        const SizedBox(width: kGapL),
        Expanded(
          child: _Metric(
            label: 'точность',
            value: model.accuracyScore,
            icon: Icons.center_focus_strong_rounded,
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      children: [
        Icon(icon, size: 14, color: scheme.onSurfaceVariant),
        const SizedBox(width: kGapXS),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: kGapS),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(kGapXS),
            child: LinearProgressIndicator(value: value / 100, minHeight: 4),
          ),
        ),
      ],
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.model,
    required this.controller,
    required this.status,
    required this.selected,
  });

  final AsrModel model;
  final AppController controller;
  final ModelStatus status;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final download = controller.models.downloadOf(model.id);

    switch (status) {
      case ModelStatus.downloading:
        return ModelDownloadProgress(
          download: download ??
              ModelDownload(
                modelId: model.id,
                status: ModelStatus.downloading,
                totalBytes: model.sizeBytes,
              ),
          speed: controller.models.speedOf(model.id),
          eta: controller.models.etaOf(model.id),
          onCancel: () => controller.models.cancel(model.id),
        );

      case ModelStatus.ready:
        return Row(
          children: [
            if (selected)
              Text(
                'Используется',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.primary,
                ),
              )
            else
              FilledButton.tonal(
                onPressed: () => controller.selectModel(model),
                child: const Text('Сделать активной'),
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
            const SizedBox(width: kGapS),
            FilledButton(
              onPressed: () => controller.downloadModel(model),
              child: const Text('Повторить'),
            ),
          ],
        );

      case ModelStatus.notDownloaded:
        return Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: () => controller.downloadModel(model),
            icon: const Icon(Icons.download_rounded, size: 18),
            label: Text('Скачать · ${formatSize(model.sizeBytes)}'),
          ),
        );
    }
  }

  Future<void> _confirmRemove(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Удалить «${model.name}»?'),
        content: Text(
          selected
              ? 'Это активная модель. Освободится '
                  '${formatSize(model.sizeBytes)}; если есть другая скачанная, '
                  'приложение переключится на неё.'
              : 'Освободится ${formatSize(model.sizeBytes)}. '
                  'Скачать заново можно в любой момент.',
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

    if (confirmed ?? false) await controller.removeModel(model);
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/asr_model.dart';
import '../../../services/model_manager.dart';
import '../../../state/app_controller.dart';
import '../../navigation.dart';
import '../../tokens.dart';
import '../../widgets/model_download_progress.dart';

/// Записывать нечем: модели нет. Вместо упрёка — сразу кнопка, которая
/// скачивает рекомендованную русскую модель, и ссылка на остальные.
class ModelGate extends StatelessWidget {
  const ModelGate({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final suggested = _suggestedModel(controller);

    return Center(
      child: SingleChildScrollView(
        padding: kScreenPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.download_for_offline_outlined,
              size: 48,
              color: scheme.primary,
            ),
            const SizedBox(height: kGapL),
            Text(
              'Нужна модель распознавания',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: kGapS),
            Text(
              'Скачивается один раз. Дальше речь распознаётся прямо на '
              'телефоне — без интернета и без отправки записей куда-либо.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: kGapXL),
            if (suggested != null)
              FilledButton.icon(
                onPressed: () => controller.downloadModel(suggested),
                icon: const Icon(Icons.download_rounded, size: 18),
                label: Text(
                  'Скачать ${suggested.name} · '
                  '${formatSize(suggested.sizeBytes)}',
                ),
              ),
            TextButton(
              onPressed: () => openModels(context),
              child: const Text('Выбрать другую модель'),
            ),
          ],
        ),
      ),
    );
  }

  /// Самая рекомендованная русская модель — с неё разумно начинать.
  AsrModel? _suggestedModel(AppController controller) {
    final candidates = kModelCatalog
        .where((m) => m.recommended && m.isRussian)
        .toList()
      ..sort((a, b) => a.recommendedRank.compareTo(b.recommendedRank));

    for (final model in candidates) {
      if (controller.models.statusOf(model.id) != ModelStatus.downloading) {
        return model;
      }
    }
    return candidates.firstOrNull;
  }
}

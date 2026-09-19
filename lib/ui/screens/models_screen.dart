import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/asr_model.dart';
import '../../services/model_manager.dart';
import '../../state/app_controller.dart';
import '../tokens.dart';
import '../widgets/model_card.dart';
import '../widgets/model_download_progress.dart';

/// Модели распознавания.
///
/// Группировка по состоянию, а не по языку: сначала человек хочет понять,
/// что у него уже есть, и только потом — что ещё бывает.
class ModelsScreen extends StatelessWidget {
  const ModelsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    context.watch<ModelManager>();

    final active = controller.selectedModel;
    final activeReady = active != null && controller.models.isReady(active.id);

    final downloaded = kModelCatalog
        .where((m) =>
            controller.models.isReady(m.id) && !(activeReady && m.id == active.id))
        .toList();
    final downloading = kModelCatalog
        .where((m) =>
            controller.models.statusOf(m.id) == ModelStatus.downloading)
        .toList();
    final available = kModelCatalog
        .where((m) =>
            !controller.models.isReady(m.id) &&
            controller.models.statusOf(m.id) != ModelStatus.downloading)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Модели')),
      body: RefreshIndicator(
        onRefresh: controller.models.refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(kGapL, 0, kGapL, kGapXL),
          children: [
            _Summary(controller: controller),

            if (activeReady) ...[
              const _SectionTitle('Активная'),
              ModelCard(model: active),
            ],

            if (downloading.isNotEmpty) ...[
              const _SectionTitle('Скачиваются'),
              for (final model in downloading) ...[
                ModelCard(model: model),
                const SizedBox(height: kGapM),
              ],
            ],

            if (downloaded.isNotEmpty) ...[
              const _SectionTitle('Загружены'),
              for (final model in downloaded) ...[
                ModelCard(model: model),
                const SizedBox(height: kGapM),
              ],
            ],

            if (available.isNotEmpty) ...[
              const _SectionTitle('Доступны для загрузки'),
              ..._availableGrouped(available),
            ],

            const SizedBox(height: kGapL),
            _Footnote(),
          ],
        ),
      ),
    );
  }

  /// Внутри «доступных» деление по языку всё ещё полезно: русских моделей
  /// немного, а многоязычные крупнее и нужны не всем.
  List<Widget> _availableGrouped(List<AsrModel> models) {
    final russian = models.where((m) => !m.isMultilingual).toList();
    final multilingual = models.where((m) => m.isMultilingual).toList();

    return [
      if (russian.isNotEmpty) ...[
        const _GroupLabel('Русский язык'),
        for (final model in russian) ...[
          ModelCard(model: model),
          const SizedBox(height: kGapM),
        ],
      ],
      if (multilingual.isNotEmpty) ...[
        const _GroupLabel('Многоязычные'),
        for (final model in multilingual) ...[
          ModelCard(model: model),
          const SizedBox(height: kGapM),
        ],
      ],
    ];
  }
}

/// Сколько моделей на устройстве и сколько места они занимают.
class _Summary extends StatelessWidget {
  const _Summary({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final count = kModelCatalog.where((m) => controller.models.isReady(m.id)).length;

    return FutureBuilder<int>(
      future: controller.models.usedBytes(),
      builder: (context, snapshot) {
        final size = snapshot.data;
        final text = count == 0
            ? 'На устройстве пока нет моделей'
            : '$count ${_plural(count)} на устройстве'
                '${size != null ? '  ·  ${formatSize(size)}' : ''}';

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: kGapM),
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        );
      },
    );
  }

  static String _plural(int count) {
    final mod10 = count % 10;
    final mod100 = count % 100;
    if (mod10 == 1 && mod100 != 11) return 'модель';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return 'модели';
    return 'моделей';
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, kGapL, 0, kGapM),
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

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

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

class _Footnote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Text(
      'Модели скачиваются один раз и работают офлайн. Прерванная загрузка '
      'продолжается с того же места, а удалённую модель можно вернуть в любой '
      'момент.',
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

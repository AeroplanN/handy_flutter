import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../services/model_manager.dart';
import '../../../state/app_controller.dart';
import '../../../state/home_phase.dart';
import '../../tokens.dart';
import '../../widgets/model_download_progress.dart';
import 'model_gate.dart';
import 'recent_strip.dart';

/// Главная область экрана: последние расшифровки или состояние модели.
///
/// Готовый текст здесь не оседает — он сразу уходит в буфер обмена и в
/// историю, а на экране появляется новой строкой в списке.
class TranscriptArea extends StatelessWidget {
  const TranscriptArea({super.key, required this.phase});

  final HomePhase phase;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: kNormal,
      child: KeyedSubtree(key: ValueKey(phase.name), child: _body()),
    );
  }

  Widget _body() => switch (phase) {
        HomePhase.noModel => const ModelGate(),
        HomePhase.modelDownloading => const _DownloadingModel(),
        HomePhase.recording => const _Listening(transcribing: false),
        HomePhase.transcribing => const _Listening(transcribing: true),
        HomePhase.idle => const _RecentList(),
      };
}

/// В покое показываем то, что уже надиктовано.
class _RecentList extends StatelessWidget {
  const _RecentList();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.expand(
      child: SingleChildScrollView(
        padding: kScreenPadding,
        child: Padding(
          padding: EdgeInsets.only(top: kGapL),
          child: RecentStrip(),
        ),
      ),
    );
  }
}

/// Пока говорят или идёт распознавание.
class _Listening extends StatelessWidget {
  const _Listening({required this.transcribing});

  final bool transcribing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: kScreenPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              transcribing ? Icons.auto_awesome_rounded : Icons.hearing_rounded,
              size: 32,
              color: scheme.primary,
            ),
            const SizedBox(height: kGapM),
            Text(
              transcribing ? 'Распознаю речь…' : 'Слушаю',
              style: theme.textTheme.titleMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Модель качается — показываем, сколько ещё ждать.
class _DownloadingModel extends StatelessWidget {
  const _DownloadingModel();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    // Прогресс приходит из отдельного уведомителя.
    context.watch<ModelManager>();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final model = controller.selectedModel;
    final download =
        model == null ? null : controller.models.downloadOf(model.id);

    if (model == null || download == null) return const SizedBox.shrink();

    return Center(
      child: SingleChildScrollView(
        padding: kScreenPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Скачиваем ${model.name}',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: kGapL),
            ModelDownloadProgress(
              download: download,
              speed: controller.models.speedOf(model.id),
              eta: controller.models.etaOf(model.id),
              onCancel: () => controller.models.cancel(model.id),
            ),
            const SizedBox(height: kGapL),
            Text(
              'Можно свернуть приложение — загрузка продолжится. '
              'Прерванная закачка продолжится с того же места.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/settings.dart';
import '../../../services/model_manager.dart';
import '../../../state/app_controller.dart';
import '../../../state/home_phase.dart';
import '../../tokens.dart';
import '../../widgets/model_download_progress.dart';
import 'model_gate.dart';
import 'recent_strip.dart';
import 'transcript_editor.dart';

/// Главная область экрана: расшифровка, подсказка или состояние модели.
///
/// Текст здесь — герой, поэтому он занимает всё свободное место, а не
/// ютится в карточке под кнопкой, как было раньше.
class TranscriptArea extends StatelessWidget {
  const TranscriptArea({
    super.key,
    required this.phase,
    required this.justCopied,
  });

  final HomePhase phase;

  /// Текст только что ушёл в буфер — показываем отметку в мета-строке.
  final bool justCopied;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: kNormal,
      child: KeyedSubtree(
        key: ValueKey(_bodyKey(phase)),
        child: _body(context),
      ),
    );
  }

  /// Соседние фазы с одинаковым содержимым не должны вызывать перелистывание.
  String _bodyKey(HomePhase phase) => switch (phase) {
        HomePhase.noModel => 'gate',
        HomePhase.modelDownloading => 'download',
        HomePhase.idleEmpty => 'empty',
        _ => 'text',
      };

  Widget _body(BuildContext context) => switch (phase) {
        HomePhase.noModel => const ModelGate(),
        HomePhase.modelDownloading => const _DownloadingModel(),
        HomePhase.idleEmpty => const _EmptyState(),
        _ => _TextState(phase: phase, justCopied: justCopied),
      };
}

/// Текст расшифровки плюс строка с фактами о ней.
class _TextState extends StatelessWidget {
  const _TextState({required this.phase, required this.justCopied});

  final HomePhase phase;
  final bool justCopied;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final busy = phase != HomePhase.idleText;
    final empty = controller.currentText.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _ComposeSwitch(),
        Expanded(
          child: empty && busy
              // Первая запись: текста ещё нет, но экран не должен быть пустым.
              ? _Listening(transcribing: phase == HomePhase.transcribing)
              : SingleChildScrollView(
                  padding: kScreenPadding,
                  child: TranscriptEditor(
                    text: controller.currentText,
                    readOnly: busy,
                    dimmed: busy,
                  ),
                ),
        ),
        _MetaLine(
          controller: controller,
          transcribing: phase == HomePhase.transcribing,
          justCopied: justCopied,
        ),
      ],
    );
  }
}

/// Пока говорят или идёт распознавание, а текста ещё нет.
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

/// Переключатель «заменять / дописывать» — состояние текущей работы,
/// поэтому живёт над текстом, а не в настройках.
class _ComposeSwitch extends StatelessWidget {
  const _ComposeSwitch();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final settings = controller.settings;

    return Padding(
      padding: const EdgeInsets.fromLTRB(kGapL, 0, kGapL, kGapS),
      child: Align(
        alignment: Alignment.centerLeft,
        child: SegmentedButton<ComposeMode>(
          showSelectedIcon: false,
          style: SegmentedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            textStyle: const TextStyle(fontSize: 12),
          ),
          segments: const [
            ButtonSegment(
              value: ComposeMode.replace,
              label: Text('Заменять'),
            ),
            ButtonSegment(
              value: ComposeMode.append,
              label: Text('Дописывать'),
            ),
          ],
          selected: {settings.composeMode},
          onSelectionChanged: (value) => controller.updateSettings(
            settings.copyWith(composeMode: value.first),
          ),
        ),
      ),
    );
  }
}

/// Слов, время распознавания, язык, отметка о копировании.
class _MetaLine extends StatelessWidget {
  const _MetaLine({
    required this.controller,
    required this.transcribing,
    required this.justCopied,
  });

  final AppController controller;
  final bool transcribing;
  final bool justCopied;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final words = controller.currentText
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;
    final elapsed = controller.lastElapsed;
    final language = controller.lastLanguage;

    final parts = <String>[
      '$words ${_plural(words)}',
      if (elapsed != null) '${(elapsed.inMilliseconds / 1000).toStringAsFixed(1)} с',
      if (language.isNotEmpty) language,
      if (controller.currentDirty) 'не сохранено',
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(kGapL, kGapS, kGapL, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              transcribing ? 'Распознаю…' : parts.join('  ·  '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: transcribing ? scheme.primary : scheme.onSurfaceVariant,
                fontFeatures: kTabularFigures,
              ),
            ),
          ),
          AnimatedOpacity(
            duration: kFast,
            opacity: justCopied ? 1 : 0,
            child: Row(
              children: [
                Icon(Icons.check_rounded, size: 14, color: kOk),
                const SizedBox(width: kGapXS),
                Text(
                  'Скопировано',
                  style: theme.textTheme.bodySmall?.copyWith(color: kOk),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _plural(int count) {
    final mod10 = count % 10;
    final mod100 = count % 100;
    if (mod10 == 1 && mod100 != 11) return 'слово';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return 'слова';
    return 'слов';
  }
}

/// Готовы писать, текста ещё нет.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // AnimatedSwitcher центрирует ребёнка, поэтому подсказка иначе повисает
    // в середине экрана; растягиваем на всю высоту и начинаем сверху.
    return SizedBox.expand(
      child: SingleChildScrollView(
        padding: kScreenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: kGapL),
            Text(
              'Говорите — получите текст',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: kGapS),
            Text(
              'Распознавание идёт прямо на телефоне: без интернета и без '
              'отправки записей куда-либо.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: kGapXL),
            const RecentStrip(),
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
    final download = model == null ? null : controller.models.downloadOf(model.id);

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

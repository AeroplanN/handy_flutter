import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/settings.dart';
import '../../../services/audio_capture.dart';
import '../../../state/app_controller.dart';
import '../../../state/home_phase.dart';
import '../../tokens.dart';
import '../../widgets/record_button.dart';
import '../../widgets/waveform.dart';

/// Нижняя панель: волна, таймер, кнопка записи и явная отмена.
///
/// Высота подстраивается: при открытой клавиатуре и при длинном тексте
/// панель ужимается, чтобы не выдавливать текст с экрана.
class RecordDock extends StatelessWidget {
  const RecordDock({super.key, required this.phase});

  final HomePhase phase;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final recording = phase == HomePhase.recording;
    final compact = MediaQuery.viewInsetsOf(context).bottom > 0;
    final buttonSize = compact ? 64.0 : 132.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(kGapL, kGapS, kGapL, compact ? kGapS : kGapL),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (recording && !compact) ...[
            Waveform(
              levelListenable: controller.levelNotifier,
              active: true,
              height: 40,
            ),
            const SizedBox(height: kGapS),
          ],
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: kGapM),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: recording
                        ? _RecordingMeta(controller: controller)
                        : _Hint(phase: phase, controller: controller),
                  ),
                ),
              ),
              RecordButton(
                state: controller.state,
                mode: controller.settings.recordMode,
                size: buttonSize,
                enabled: controller.canRecord,
                levelListenable: controller.levelNotifier,
                onStart: controller.startRecording,
                onStop: controller.stopAndTranscribe,
                onCancel: controller.cancelRecording,
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: recording
                      ? TextButton.icon(
                          onPressed: controller.cancelRecording,
                          icon: const Icon(Icons.close_rounded, size: 18),
                          label: const Text('Отмена'),
                          style: TextButton.styleFrom(
                            foregroundColor: scheme.onSurfaceVariant,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Таймер записи и предупреждение о лимите.
class _RecordingMeta extends StatelessWidget {
  const _RecordingMeta({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ValueListenableBuilder<Duration>(
      valueListenable: controller.elapsedNotifier,
      builder: (context, elapsed, _) {
        final left = kMaxRecordingDuration - elapsed;
        final nearLimit = left.inSeconds <= 60;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _format(elapsed),
              style: theme.textTheme.titleMedium?.copyWith(
                color: kRecording,
                fontFeatures: kTabularFigures,
              ),
            ),
            if (nearLimit)
              Text(
                'осталась ${left.inSeconds ~/ 60 + 1} мин',
                style: theme.textTheme.bodySmall?.copyWith(color: kWarn),
              ),
          ],
        );
      },
    );
  }

  static String _format(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

/// Подсказка под состояние: что сделает кнопка.
class _Hint extends StatelessWidget {
  const _Hint({required this.phase, required this.controller});

  final HomePhase phase;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final hold = controller.settings.recordMode == RecordMode.hold;

    final text = switch (phase) {
      HomePhase.noModel => 'Сначала скачайте модель',
      HomePhase.modelDownloading => 'Модель качается',
      HomePhase.transcribing => 'Распознаю…',
      _ => hold ? 'Удерживайте и говорите' : 'Нажмите и говорите',
    };

    if (text.isEmpty) return const SizedBox.shrink();

    return Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: phase == HomePhase.transcribing
            ? scheme.primary
            : scheme.onSurfaceVariant,
      ),
    );
  }
}

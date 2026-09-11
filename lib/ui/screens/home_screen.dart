import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/settings.dart';
import '../../state/app_controller.dart';
import '../widgets/record_button.dart';
import '../widgets/waveform.dart';
import 'models_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final scheme = Theme.of(context).colorScheme;
    final model = controller.selectedModel;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Handy'),
        actions: [
          if (model != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ModelsScreen()),
                  ),
                  icon: const Icon(Icons.memory_rounded, size: 18),
                  label: Text(model.name),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (!controller.canRecord) const _ModelMissingBanner(),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Waveform(
                      level: controller.level,
                      active: controller.state == RecordingState.recording,
                    ),
                  ),
                  const SizedBox(height: 32),
                  RecordButton(
                    state: controller.state,
                    mode: controller.settings.recordMode,
                    level: controller.level,
                    enabled: controller.canRecord,
                    onStart: controller.startRecording,
                    onStop: controller.stopAndTranscribe,
                    onCancel: controller.cancelRecording,
                  ),
                  const SizedBox(height: 24),
                  _StatusLine(controller: controller),
                ],
              ),
            ),
            _TranscriptCard(controller: controller),
            if (controller.error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: scheme.error, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        controller.error!,
                        style: TextStyle(color: scheme.error),
                      ),
                    ),
                    IconButton(
                      onPressed: controller.clearError,
                      icon: const Icon(Icons.close, size: 18),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final (text, emphasis) = switch (controller.state) {
      RecordingState.recording => (
          _formatDuration(controller.recordingElapsed),
          true,
        ),
      RecordingState.transcribing => ('Распознаю…', true),
      RecordingState.idle => (
          controller.canRecord
              ? (controller.settings.recordMode == RecordMode.hold
                  ? 'Удерживайте кнопку и говорите'
                  : 'Нажмите, чтобы начать запись')
              : 'Сначала скачайте модель',
          false,
        ),
    };

    return Column(
      children: [
        Text(
          text,
          style: theme.textTheme.titleMedium?.copyWith(
            color: emphasis ? scheme.primary : scheme.onSurfaceVariant,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        if (controller.state == RecordingState.recording)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Свайп вверх — отменить',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }

  static String _formatDuration(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _TranscriptCard extends StatelessWidget {
  const _TranscriptCard({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.currentText.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final elapsed = controller.lastElapsed;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: SingleChildScrollView(
                  child: SelectableText(
                    controller.currentText,
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (elapsed != null)
                    Text(
                      '${(elapsed.inMilliseconds / 1000).toStringAsFixed(1)} с',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Скопировать',
                    onPressed: () async {
                      await controller.copyCurrent();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Скопировано в буфер обмена'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded),
                  ),
                  IconButton(
                    tooltip: 'Поделиться',
                    onPressed: controller.shareCurrent,
                    icon: const Icon(Icons.ios_share_rounded),
                  ),
                  IconButton(
                    tooltip: 'Очистить',
                    onPressed: controller.clearCurrent,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModelMissingBanner extends StatelessWidget {
  const _ModelMissingBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.download_rounded, color: scheme.onSecondaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Чтобы распознавать речь офлайн, нужно один раз скачать модель.',
              style: TextStyle(color: scheme.onSecondaryContainer),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ModelsScreen()),
            ),
            child: const Text('Модели'),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/asr_model.dart';
import '../../services/model_manager.dart';
import '../../state/app_controller.dart';
import 'models_screen.dart';

/// Первый запуск: объясняем идею, просим микрофон и качаем первую модель.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _micGranted = false;
  bool _micRequested = false;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    context.watch<ModelManager>();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // Для онбординга показываем только две русские модели — остальное
    // человек найдёт на экране моделей, когда разберётся.
    final suggested = kModelCatalog
        .where((m) => m.recommended && m.isRussian)
        .toList()
      ..sort((a, b) => a.recommendedRank.compareTo(b.recommendedRank));

    final anyReady = kModelCatalog.any((m) => controller.models.isReady(m.id));

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
          children: [
            Icon(Icons.mic_rounded, size: 56, color: scheme.primary),
            const SizedBox(height: 20),
            Text('Handy', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Говорите — получаете текст. Распознавание идёт прямо на '
              'телефоне, без интернета и без отправки записей куда-либо.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),

            _Step(
              number: 1,
              title: 'Доступ к микрофону',
              done: _micGranted,
              child: _micGranted
                  ? const Text('Разрешение получено')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_micRequested)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              'Без микрофона записывать нечего. Разрешение '
                              'можно выдать в настройках системы.',
                              style: TextStyle(color: scheme.error),
                            ),
                          ),
                        FilledButton(
                          onPressed: () async {
                            final granted =
                                await controller.requestMicrophonePermission();
                            if (!mounted) return;
                            setState(() {
                              _micGranted = granted;
                              _micRequested = true;
                            });
                          },
                          child: const Text('Разрешить'),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 24),

            _Step(
              number: 2,
              title: 'Скачать модель',
              done: anyReady,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Один раз скачиваем модель распознавания — дальше всё '
                    'работает офлайн. Для русского лучше всего GigaAM.',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  for (final model in suggested)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ModelCard(model: model, controller: controller),
                    ),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ModelsScreen()),
                    ),
                    child: const Text('Показать все модели'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            FilledButton(
              onPressed: anyReady && _micGranted
                  ? () => controller.updateSettings(
                        controller.settings.copyWith(onboardingDone: true),
                      )
                  : null,
              child: const Text('Начать'),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => controller.updateSettings(
                  controller.settings.copyWith(onboardingDone: true),
                ),
                child: const Text('Пропустить'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.title,
    required this.done,
    required this.child,
  });

  final int number;
  final String title;
  final bool done;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? scheme.primary : scheme.surfaceContainerHighest,
          ),
          child: Center(
            child: done
                ? Icon(Icons.check, size: 16, color: scheme.onPrimary)
                : Text('$number', style: theme.textTheme.labelLarge),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              child,
            ],
          ),
        ),
      ],
    );
  }
}

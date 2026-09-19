import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/asr_model.dart';
import '../../services/model_manager.dart';
import '../../state/app_controller.dart';
import '../navigation.dart';
import '../tokens.dart';
import '../widgets/handy_wordmark.dart';
import '../widgets/model_card.dart';

/// Первый запуск: зачем это нужно, доступ к микрофону, первая модель.
///
/// Три страницы вместо одного длинного списка — каждый шаг требует ровно
/// одного решения.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pages = PageController();
  int _page = 0;

  bool _micGranted = false;
  bool _micRequested = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    _pages.animateToPage(page, duration: kNormal, curve: Curves.easeOutCubic);
  }

  Future<void> _requestMic() async {
    final granted =
        await context.read<AppController>().requestMicrophonePermission();
    if (!mounted) return;

    setState(() {
      _micGranted = granted;
      _micRequested = true;
    });
    if (granted) _goTo(2);
  }

  Future<void> _finish() async {
    final controller = context.read<AppController>();
    await controller.updateSettings(
      controller.settings.copyWith(onboardingDone: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    context.watch<ModelManager>();

    final anyReady = kModelCatalog.any((m) => controller.models.isReady(m.id));

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (page) => setState(() => _page = page),
                children: [
                  const _IntroPage(),
                  _MicPage(
                    granted: _micGranted,
                    denied: _micRequested && !_micGranted,
                    onRequest: _requestMic,
                  ),
                  const _ModelPage(),
                ],
              ),
            ),
            _Dots(count: 3, active: _page),
            Padding(
              padding: const EdgeInsets.fromLTRB(kGapL, kGapM, kGapL, kGapL),
              child: Row(
                children: [
                  TextButton(
                    onPressed: _finish,
                    child: const Text('Пропустить'),
                  ),
                  const Spacer(),
                  if (_page < 2)
                    FilledButton(
                      onPressed: () => _goTo(_page + 1),
                      child: const Text('Дальше'),
                    )
                  else
                    FilledButton(
                      onPressed: anyReady && _micGranted ? _finish : null,
                      child: const Text('Начать'),
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

class _IntroPage extends StatelessWidget {
  const _IntroPage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.all(kGapXL),
      children: [
        const HandyWordmark(size: 48),
        const SizedBox(height: kGapL),
        Text('Говорите — получите текст', style: theme.textTheme.headlineSmall),
        const SizedBox(height: kGapM),
        Text(
          'Распознавание идёт прямо на телефоне. Без интернета, без аккаунтов '
          'и без отправки ваших записей куда-либо.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: kGapXL),
        const _Feature(
          icon: Icons.bolt_rounded,
          title: 'Быстрая диктовка',
          text: 'Записали — текст сразу в буфере обмена.',
        ),
        const _Feature(
          icon: Icons.notes_rounded,
          title: 'Длинные заметки',
          text: 'Диктуйте абзацами и правьте текст на месте.',
        ),
        const _Feature(
          icon: Icons.lock_outline_rounded,
          title: 'Всё остаётся у вас',
          text: 'Записи и расшифровки хранятся только на телефоне.',
        ),
      ],
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: kGapL),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: scheme.primary),
          const SizedBox(width: kGapM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                Text(
                  text,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MicPage extends StatelessWidget {
  const _MicPage({
    required this.granted,
    required this.denied,
    required this.onRequest,
  });

  final bool granted;
  final bool denied;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.all(kGapXL),
      children: [
        Icon(
          granted ? Icons.mic_rounded : Icons.mic_none_rounded,
          size: 48,
          color: granted ? kOk : scheme.primary,
        ),
        const SizedBox(height: kGapL),
        Text('Доступ к микрофону', style: theme.textTheme.headlineSmall),
        const SizedBox(height: kGapM),
        Text(
          'Без него записывать нечего. Звук обрабатывается на устройстве и '
          'никуда не уходит.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: kGapXL),
        if (granted)
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: kOk),
              const SizedBox(width: kGapS),
              Text('Доступ есть', style: theme.textTheme.titleSmall),
            ],
          )
        else
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: onRequest,
              child: const Text('Разрешить'),
            ),
          ),
        if (denied)
          Padding(
            padding: const EdgeInsets.only(top: kGapM),
            child: Text(
              'Доступ не выдан. Его можно включить в настройках телефона: '
              'Приложения → Handy → Разрешения.',
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
            ),
          ),
      ],
    );
  }
}

class _ModelPage extends StatelessWidget {
  const _ModelPage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // На первом запуске показываем только рекомендованные русские модели —
    // остальное человек найдёт позже, когда разберётся.
    final suggested = kModelCatalog
        .where((m) => m.recommended && m.isRussian)
        .toList()
      ..sort((a, b) => a.recommendedRank.compareTo(b.recommendedRank));

    return ListView(
      padding: const EdgeInsets.fromLTRB(kGapXL, kGapXL, kGapXL, kGapL),
      children: [
        Text('Первая модель', style: theme.textTheme.headlineSmall),
        const SizedBox(height: kGapM),
        Text(
          'Скачивается один раз. Дальше всё работает офлайн.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: kGapXL),
        for (final model in suggested) ...[
          ModelCard(model: model),
          const SizedBox(height: kGapM),
        ],
        TextButton(
          onPressed: () => openModels(context),
          child: const Text('Показать все модели'),
        ),
      ],
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: kFast,
            margin: const EdgeInsets.symmetric(horizontal: kGapXS),
            width: i == active ? 20 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == active ? scheme.primary : scheme.outlineVariant,
              borderRadius: BorderRadius.circular(kRadiusPill),
            ),
          ),
      ],
    );
  }
}

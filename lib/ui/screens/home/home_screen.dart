import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../services/model_manager.dart';
import '../../../state/app_controller.dart';
import '../../../state/home_phase.dart';
import '../../widgets/handy_header.dart';
import 'error_banner.dart';
import 'quick_actions_bar.dart';
import 'record_dock.dart';
import 'transcript_area.dart';

/// Единственный «дом» приложения: здесь и записывают, и читают, и правят.
///
/// Вкладок больше нет — история, модели и настройки открываются поверх,
/// а всё, что нужно для работы, помещается на один экран.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool _justCopied = false;
  Timer? _copiedTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Приложение сворачивают — дописывать заметку уже некому,
    // сохраняем правки немедленно, не дожидаясь паузы в наборе.
    if (state == AppLifecycleState.paused) {
      unawaited(context.read<AppController>().saveCurrentToHistory());
    }
  }

  @override
  void dispose() {
    _copiedTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _showCopied() {
    _copiedTimer?.cancel();
    setState(() => _justCopied = true);
    _copiedTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _justCopied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    // Прогресс загрузки живёт в отдельном ChangeNotifier. Без этой подписки
    // фаза `modelDownloading` не наступала бы: экран не узнавал, что
    // загрузка началась, и продолжал показывать «нужна модель».
    context.watch<ModelManager>();

    final phase = controller.phase;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            const HandyHeader(),
            Expanded(
              child: TranscriptArea(phase: phase, justCopied: _justCopied),
            ),
            if (controller.error != null)
              ErrorBanner(
                message: controller.error!,
                onClose: controller.clearError,
              ),
            if (phase == HomePhase.idleText)
              QuickActionsBar(onCopied: _showCopied),
            RecordDock(phase: phase),
          ],
        ),
      ),
    );
  }
}

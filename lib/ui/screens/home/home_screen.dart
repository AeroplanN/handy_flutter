import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../services/model_manager.dart';
import '../../../state/app_controller.dart';
import '../../widgets/handy_header.dart';
import 'error_banner.dart';
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

class _HomeScreenState extends State<HomeScreen> {
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
            Expanded(child: TranscriptArea(phase: phase)),
            if (controller.error != null)
              ErrorBanner(
                message: controller.error!,
                onClose: controller.clearError,
              ),
            RecordDock(phase: phase),
          ],
        ),
      ),
    );
  }
}

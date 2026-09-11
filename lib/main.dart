import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'services/model_manager.dart';
import 'state/app_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Даты в истории показываем по-русски.
  await initializeDateFormatting('ru');

  final controller = AppController();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppController>.value(value: controller),
        // Прогресс загрузки моделей идёт отдельным потоком уведомлений,
        // чтобы перерисовывались только карточки моделей.
        ChangeNotifierProvider<ModelManager>.value(value: controller.models),
      ],
      child: const HandyApp(),
    ),
  );

  // Настройки, модели и история подтягиваются уже под сплэшем.
  await controller.init();
}

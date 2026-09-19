import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_controller.dart';
import '../navigation.dart';
import '../tokens.dart';
import 'handy_wordmark.dart';
import 'model_chip.dart';
import 'quick_settings_sheet.dart';

/// Шапка главного экрана: имя приложения, состояние модели и два входа —
/// в историю и настройки.
///
/// Это не `AppBar`: разделов больше нет, а вместо заголовка здесь живут
/// органы управления, до которых нужно дотягиваться одной рукой.
class HandyHeader extends StatelessWidget {
  const HandyHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final scheme = Theme.of(context).colorScheme;
    final count = controller.historyTotal;

    return Padding(
      padding: const EdgeInsets.fromLTRB(kGapL, kGapS, kGapS, kGapS),
      child: Row(
        children: [
          const HandyWordmark(size: 26),
          const SizedBox(width: kGapM),
          const Expanded(
            child: Align(alignment: Alignment.centerLeft, child: ModelChip()),
          ),
          _HistoryButton(count: count),
          // Долгий тап — быстрые настройки, без захода в раздел.
          GestureDetector(
            onLongPress: () => showQuickSettings(context),
            child: IconButton(
              onPressed: () => openSettings(context),
              icon: const Icon(Icons.tune_rounded),
              tooltip: 'Настройки',
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryButton extends StatelessWidget {
  const _HistoryButton({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Иконка с числом, а не кнопка с подписью: на узком экране строка
    // с логотипом и чипом модели иначе не помещается.
    return IconButton(
      onPressed: () => openHistory(context),
      tooltip: 'История',
      color: scheme.onSurfaceVariant,
      icon: count == 0
          ? const Icon(Icons.history_rounded)
          : Badge(
              label: Text(count > 99 ? '99+' : '$count'),
              backgroundColor: scheme.primary,
              textColor: scheme.onPrimary,
              child: const Icon(Icons.history_rounded),
            ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../state/app_controller.dart';
import '../../tokens.dart';
import '../../widgets/quick_settings_sheet.dart';

/// Действия над готовым текстом. Появляется только когда есть что делать.
class QuickActionsBar extends StatelessWidget {
  const QuickActionsBar({super.key, required this.onCopied});

  /// Сообщить экрану, что текст скопирован, — он покажет отметку в мета-строке.
  final VoidCallback onCopied;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(kGapS, 0, kGapS, kGapS),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: TextButton.icon(
              onPressed: () {
                controller.copyCurrent();
                onCopied();
              },
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Копировать'),
            ),
          ),
          Expanded(
            child: TextButton.icon(
              onPressed: controller.shareCurrent,
              icon: const Icon(Icons.ios_share_rounded, size: 18),
              label: const Text('Поделиться'),
            ),
          ),
          _MoreButton(controller: controller),
        ],
      ),
    );
  }
}

class _MoreButton extends StatelessWidget {
  const _MoreButton({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz_rounded),
      tooltip: 'Ещё',
      onSelected: (value) async {
        switch (value) {
          case 'new':
            await controller.startNewNote();
          case 'save':
            await controller.saveCurrentToHistory();
          case 'clear':
            controller.clearCurrent();
          case 'settings':
            await showQuickSettings(context);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'new',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.note_add_outlined),
            title: Text('Новая заметка'),
          ),
        ),
        if (controller.currentDirty)
          const PopupMenuItem(
            value: 'save',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.save_outlined),
              title: Text('Сохранить правки'),
            ),
          ),
        const PopupMenuItem(
          value: 'clear',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.backspace_outlined),
            title: Text('Очистить'),
          ),
        ),
        const PopupMenuItem(
          value: 'settings',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.tune_rounded),
            title: Text('Быстрые настройки'),
          ),
        ),
      ],
    );
  }
}

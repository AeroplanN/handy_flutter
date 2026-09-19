import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/history_entry.dart';
import '../../../state/app_controller.dart';
import '../../navigation.dart';
import '../../tokens.dart';
import '../history_detail_screen.dart';

/// Три последние расшифровки под подсказкой на пустом экране.
///
/// Раньше главный экран в покое не показывал ничего — сюда же переехал
/// второй вход в историю.
class RecentStrip extends StatelessWidget {
  const RecentStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final recent = controller.entries.take(3).toList();
    if (recent.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: kGapS),
          child: Row(
            children: [
              Text(
                'Последние',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => openHistory(context),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('Вся история'),
              ),
            ],
          ),
        ),
        for (final entry in recent)
          _RecentItem(entry: entry, controller: controller),
      ],
    );
  }
}

class _RecentItem extends StatelessWidget {
  const _RecentItem({required this.entry, required this.controller});

  final HistoryEntry entry;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: kGapS),
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(kRadiusField),
        child: InkWell(
          borderRadius: BorderRadius.circular(kRadiusField),
          // Тап открывает запись целиком: там её можно прочитать и поправить.
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => HistoryDetailScreen(entry: entry),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: kGapM,
              vertical: kGapM,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: kGapS),
                Icon(
                  Icons.north_east_rounded,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

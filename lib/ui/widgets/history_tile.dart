import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/asr_model.dart';
import '../../models/history_entry.dart';
import '../tokens.dart';

/// Строка истории: о чём запись, когда сделана и чем.
///
/// Длительность, модель и наличие аудио уже хранились в базе, но раньше их
/// нигде не показывали.
class HistoryTile extends StatelessWidget {
  const HistoryTile({
    super.key,
    required this.entry,
    required this.onTap,
    required this.onDelete,
    required this.onTogglePinned,
  });

  final HistoryEntry entry;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onTogglePinned;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final meta = <String>[
      DateFormat('HH:mm').format(entry.timestamp),
      if (entry.durationMs > 0) _formatDuration(entry.durationMs),
      '${entry.wordCount} ${_plural(entry.wordCount)}',
      modelById(entry.modelId)?.name ?? entry.modelId,
    ];

    return Dismissible(
      key: ValueKey(entry.id ?? entry.timestamp.millisecondsSinceEpoch),
      background: _SwipeBackground(
        alignment: Alignment.centerLeft,
        color: scheme.primaryContainer,
        foreground: scheme.onPrimaryContainer,
        icon: entry.saved
            ? Icons.push_pin_outlined
            : Icons.push_pin_rounded,
        label: entry.saved ? 'Открепить' : 'Закрепить',
      ),
      secondaryBackground: _SwipeBackground(
        alignment: Alignment.centerRight,
        color: scheme.errorContainer,
        foreground: scheme.onErrorContainer,
        icon: Icons.delete_outline_rounded,
        label: 'Удалить',
      ),
      confirmDismiss: (direction) async {
        // Закрепление не убирает строку из списка — обрабатываем и отменяем.
        if (direction == DismissDirection.startToEnd) {
          onTogglePinned();
          return false;
        }
        return true;
      },
      onDismissed: (_) => onDelete(),
      child: Padding(
        padding: const EdgeInsets.only(bottom: kGapS),
        child: Material(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(kRadiusCard),
          child: InkWell(
            borderRadius: BorderRadius.circular(kRadiusCard),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(kGapL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      if (entry.saved)
                        Icon(
                          Icons.push_pin_rounded,
                          size: 16,
                          color: scheme.primary,
                        ),
                    ],
                  ),
                  const SizedBox(height: kGapXS),
                  Text(
                    entry.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: kGapS),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          meta.join('  ·  '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                            fontFeatures: kTabularFigures,
                          ),
                        ),
                      ),
                      if (entry.fileName != null)
                        Icon(
                          Icons.graphic_eq_rounded,
                          size: 14,
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _formatDuration(int milliseconds) {
    final seconds = (milliseconds / 1000).round();
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  static String _plural(int count) {
    final mod10 = count % 10;
    final mod100 = count % 100;
    if (mod10 == 1 && mod100 != 11) return 'слово';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return 'слова';
    return 'слов';
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.alignment,
    required this.color,
    required this.foreground,
    required this.icon,
    required this.label,
  });

  final Alignment alignment;
  final Color color;
  final Color foreground;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: kGapS),
      child: Container(
        alignment: alignment,
        padding: const EdgeInsets.symmetric(horizontal: kGapXL),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(kRadiusCard),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: foreground, size: 20),
            const SizedBox(width: kGapS),
            Text(label, style: TextStyle(color: foreground)),
          ],
        ),
      ),
    );
  }
}

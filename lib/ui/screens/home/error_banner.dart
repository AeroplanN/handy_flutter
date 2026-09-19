import 'package:flutter/material.dart';

import '../../tokens.dart';

/// Ошибка показывается строкой над доком, а не всплывашкой: SnackBar
/// перекрыл бы кнопку записи и исчез раньше, чем его прочитали.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message, required this.onClose});

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(kGapL, 0, kGapL, kGapS),
      child: Container(
        padding: const EdgeInsets.fromLTRB(kGapM, kGapS, kGapS, kGapS),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(kRadiusField),
        ),
        child: Row(
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 18,
              color: scheme.onErrorContainer,
            ),
            const SizedBox(width: kGapS),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onErrorContainer,
                ),
              ),
            ),
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded, size: 18),
              color: scheme.onErrorContainer,
              visualDensity: VisualDensity.compact,
              tooltip: 'Скрыть',
            ),
          ],
        ),
      ),
    );
  }
}

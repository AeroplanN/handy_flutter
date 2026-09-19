import 'package:flutter/material.dart';

import '../tokens.dart';

/// Маленький бейдж-пилюля: «Активна», «Рекомендуем», «32 языка».
///
/// [tone] задаёт смысл, а не цвет — чтобы в одном месте решать, как
/// выглядит «важное» и «обычное».
enum ChipTone { neutral, accent, warn, ok }

class HandyChip extends StatelessWidget {
  const HandyChip(
    this.label, {
    super.key,
    this.tone = ChipTone.neutral,
    this.icon,
  });

  final String label;
  final ChipTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final (background, foreground) = switch (tone) {
      ChipTone.neutral => (
          scheme.surfaceContainerHighest,
          scheme.onSurfaceVariant,
        ),
      ChipTone.accent => (scheme.primaryContainer, scheme.onPrimaryContainer),
      ChipTone.warn => (kWarn.withValues(alpha: 0.18), kWarn),
      ChipTone.ok => (kOk.withValues(alpha: 0.18), kOk),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: kGapS, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(kRadiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: foreground),
            const SizedBox(width: kGapXS),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

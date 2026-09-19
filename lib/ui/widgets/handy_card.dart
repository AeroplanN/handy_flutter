import 'package:flutter/material.dart';

import '../tokens.dart';

/// Карточка приложения. При [selected] обводится розовой рамкой и слегка
/// подкрашивается — так на экране моделей видно активную, как в десктопном
/// Handy. Через `CardTheme` это не выражается, поэтому отдельный виджет.
class HandyCard extends StatelessWidget {
  const HandyCard({
    super.key,
    required this.child,
    this.selected = false,
    this.onTap,
    this.padding = const EdgeInsets.all(kGapL),
  });

  final Widget child;
  final bool selected;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(kRadiusCard);

    return AnimatedContainer(
      duration: kFast,
      decoration: BoxDecoration(
        color: selected
            ? Color.alphaBlend(
                scheme.primary.withValues(alpha: 0.07),
                scheme.surfaceContainerLow,
              )
            : scheme.surfaceContainerLow,
        borderRadius: radius,
        border: Border.all(
          color: selected ? scheme.primary : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

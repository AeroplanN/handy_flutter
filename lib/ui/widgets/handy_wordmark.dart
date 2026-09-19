import 'package:flutter/material.dart';

import '../tokens.dart';

/// Рукописный логотип «handy» — тот же приём, что в десктопной версии.
///
/// Единственное место, где приложение называет себя по имени. Реализация
/// спрятана внутри: сменится шрифт или придёт нарисованный вордмарк —
/// вызовы останутся прежними.
class HandyWordmark extends StatelessWidget {
  const HandyWordmark({super.key, this.size = 24, this.color});

  /// Высота начертания в логических пикселях.
  final double size;

  /// По умолчанию — акцентный цвет темы.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      'handy',
      style: TextStyle(
        fontFamily: kScriptFamily,
        fontSize: size,
        height: 1.4,
        color: color ?? Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Бегущая дорожка громкости — визуальное подтверждение, что микрофон слышит.
///
/// Слушает уровень напрямую: кадры звука приходят несколько раз в секунду и
/// не должны перерисовывать экран целиком.
class Waveform extends StatefulWidget {
  const Waveform({
    super.key,
    required this.levelListenable,
    required this.active,
    this.barCount = 48,
    this.height = 56,
  });

  final ValueListenable<double> levelListenable;
  final bool active;
  final int barCount;
  final double height;

  @override
  State<Waveform> createState() => _WaveformState();
}

class _WaveformState extends State<Waveform> {
  final Queue<double> _history = Queue<double>();

  @override
  void initState() {
    super.initState();
    widget.levelListenable.addListener(_onLevel);
  }

  @override
  void didUpdateWidget(Waveform oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.levelListenable != widget.levelListenable) {
      oldWidget.levelListenable.removeListener(_onLevel);
      widget.levelListenable.addListener(_onLevel);
    }
    if (!widget.active && _history.isNotEmpty) _history.clear();
  }

  @override
  void dispose() {
    widget.levelListenable.removeListener(_onLevel);
    super.dispose();
  }

  void _onLevel() {
    if (!widget.active || !mounted) return;

    setState(() {
      _history.addLast(widget.levelListenable.value);
      while (_history.length > widget.barCount) {
        _history.removeFirst();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: widget.height,
      child: CustomPaint(
        painter: _WaveformPainter(
          levels: _history.toList(),
          barCount: widget.barCount,
          color: widget.active ? scheme.primary : scheme.outlineVariant,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.levels,
    required this.barCount,
    required this.color,
  });

  final List<double> levels;
  final int barCount;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final slotWidth = size.width / barCount;
    final barWidth = slotWidth * 0.55;
    final center = size.height / 2;

    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth;

    for (var i = 0; i < barCount; i++) {
      // Старые значения слева, свежие справа.
      final index = levels.length - barCount + i;
      final level = index >= 0 && index < levels.length ? levels[index] : 0.0;
      final height = (2 + level * (size.height - 6)).clamp(2.0, size.height);
      final x = slotWidth * i + slotWidth / 2;

      canvas.drawLine(
        Offset(x, center - height / 2),
        Offset(x, center + height / 2),
        paint..color = color.withValues(alpha: level < 0.02 ? 0.25 : 1.0),
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) =>
      oldDelegate.levels != levels || oldDelegate.color != color;
}

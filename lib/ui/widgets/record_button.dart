import 'package:flutter/material.dart';

import '../../models/settings.dart';
import '../../state/app_controller.dart';

/// Главная кнопка: зажать и говорить либо тап-тап — в зависимости от
/// [RecordMode]. Прямой перенос двух режимов шортката из десктопного Handy.
class RecordButton extends StatefulWidget {
  const RecordButton({
    super.key,
    required this.state,
    required this.mode,
    required this.level,
    required this.enabled,
    required this.onStart,
    required this.onStop,
    required this.onCancel,
  });

  final RecordingState state;
  final RecordMode mode;

  /// Текущая громкость 0.0–1.0 — кнопка «дышит» в такт голосу.
  final double level;

  final bool enabled;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onCancel;

  @override
  State<RecordButton> createState() => _RecordButtonState();
}

class _RecordButtonState extends State<RecordButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  bool get _isRecording => widget.state == RecordingState.recording;

  bool get _isBusy => widget.state == RecordingState.transcribing;

  void _handleTap() {
    if (!widget.enabled || _isBusy) return;
    if (widget.mode == RecordMode.hold) return;

    if (_isRecording) {
      widget.onStop();
    } else {
      widget.onStart();
    }
  }

  void _handleHoldStart() {
    if (!widget.enabled || _isBusy) return;
    if (widget.mode != RecordMode.hold) return;
    widget.onStart();
  }

  void _handleHoldEnd() {
    if (widget.mode != RecordMode.hold) return;
    if (_isRecording) widget.onStop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final base = switch (widget.state) {
      RecordingState.recording => scheme.error,
      RecordingState.transcribing => scheme.secondary,
      RecordingState.idle =>
        widget.enabled ? scheme.primary : scheme.surfaceContainerHighest,
    };

    return GestureDetector(
      onTap: _handleTap,
      onTapDown: (_) => _handleHoldStart(),
      onTapUp: (_) => _handleHoldEnd(),
      onTapCancel: _handleHoldEnd,
      // Свайп вверх во время записи — отмена, как Esc в десктопной версии.
      onVerticalDragEnd: (details) {
        if (_isRecording && (details.primaryVelocity ?? 0) < -300) {
          widget.onCancel();
        }
      },
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          final breathing = _isRecording
              ? 1.0 + 0.06 * _pulse.value + widget.level * 0.18
              : 1.0;

          return Transform.scale(
            scale: breathing,
            child: Container(
              width: 168,
              height: 168,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: base,
                boxShadow: [
                  if (_isRecording)
                    BoxShadow(
                      color: base.withValues(alpha: 0.35),
                      blurRadius: 40 + widget.level * 40,
                      spreadRadius: 4 + widget.level * 12,
                    ),
                ],
              ),
              child: Center(child: child),
            ),
          );
        },
        child: _isBusy
            ? const SizedBox(
                width: 44,
                height: 44,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Colors.white,
                ),
              )
            : Icon(
                _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                size: 64,
                color: widget.enabled || _isRecording
                    ? Colors.white
                    : scheme.onSurfaceVariant,
              ),
      ),
    );
  }
}

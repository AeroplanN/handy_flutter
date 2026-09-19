import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/settings.dart';
import '../../state/app_controller.dart';
import '../tokens.dart';

/// Круглая кнопка записи.
///
/// Два режима: удержание (палец держит — идёт запись) и переключение
/// (тап начал, тап закончил). Свайп вверх во время записи отменяет её,
/// но это лишь ускоритель: рядом в доке есть видимая кнопка «Отмена».
class RecordButton extends StatefulWidget {
  const RecordButton({
    super.key,
    required this.state,
    required this.mode,
    required this.enabled,
    required this.onStart,
    required this.onStop,
    required this.onCancel,
    this.levelListenable,
    this.size = 132,
  });

  final RecordingState state;
  final RecordMode mode;
  final bool enabled;

  /// Громкость для пульсации. Отдельный уведомитель, чтобы кадры звука не
  /// перерисовывали весь экран.
  final ValueListenable<double>? levelListenable;

  final double size;

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
    lowerBound: 0.0,
    upperBound: 1.0,
  )..repeat(reverse: true);

  /// Палец подняли раньше, чем запись успела начаться.
  ///
  /// `startRecording` асинхронна: проверяет разрешение и открывает поток.
  /// Без этого флага короткое касание оставляло бы запись включённой —
  /// отпускание уходило в пустоту, потому что состояние ещё не `recording`.
  bool _releasedEarly = false;

  @override
  void didUpdateWidget(RecordButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (_releasedEarly && widget.state == RecordingState.recording) {
      _releasedEarly = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onStop());
    }
  }

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

    _releasedEarly = false;
    widget.onStart();
  }

  void _handleHoldEnd() {
    if (widget.mode != RecordMode.hold) return;

    if (_isRecording) {
      widget.onStop();
    } else if (widget.enabled && !_isBusy) {
      // Запись ещё поднимается — остановим её, как только начнётся.
      _releasedEarly = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final base = switch (widget.state) {
      RecordingState.recording => kRecording,
      RecordingState.transcribing => scheme.secondary,
      RecordingState.idle =>
        widget.enabled ? scheme.primary : scheme.surfaceContainerHighest,
    };

    return GestureDetector(
      onTap: _handleTap,
      onTapDown: (_) => _handleHoldStart(),
      onTapUp: (_) => _handleHoldEnd(),
      onTapCancel: _handleHoldEnd,
      // Свайп вверх во время записи — быстрая отмена, как Esc на десктопе.
      onVerticalDragEnd: (details) {
        if (_isRecording && (details.primaryVelocity ?? 0) < -300) {
          widget.onCancel();
        }
      },
      child: ValueListenableBuilder<double>(
        valueListenable: widget.levelListenable ?? _zeroLevel,
        builder: (context, level, _) => AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) {
            final scale = _isRecording
                ? 1.0 + 0.06 * _pulse.value + level * 0.18
                : 1.0;

            return Transform.scale(
              scale: scale,
              child: AnimatedContainer(
                duration: kNormal,
                curve: Curves.easeOutCubic,
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  color: base,
                  shape: BoxShape.circle,
                  boxShadow: _isRecording
                      ? [
                          BoxShadow(
                            color: base.withValues(alpha: 0.35),
                            blurRadius: 40 + level * 40,
                            spreadRadius: 4 + level * 12,
                          ),
                        ]
                      : null,
                ),
                child: child,
              ),
            );
          },
          child: Center(child: _icon(scheme)),
        ),
      ),
    );
  }

  Widget _icon(ColorScheme scheme) {
    if (_isBusy) {
      return SizedBox(
        width: widget.size * 0.3,
        height: widget.size * 0.3,
        child: const CircularProgressIndicator(
          strokeWidth: 3,
          color: Colors.white,
        ),
      );
    }

    return Icon(
      _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
      size: widget.size * 0.4,
      color: widget.enabled ? Colors.white : scheme.onSurfaceVariant,
    );
  }
}

/// Заглушка на случай, когда уровень никто не передал.
final ValueNotifier<double> _zeroLevel = ValueNotifier<double>(0);

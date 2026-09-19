import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../state/app_controller.dart';
import '../../tokens.dart';

/// Текст расшифровки, который можно править прямо на месте.
///
/// Контроллер текста живёт здесь, а не в [AppController]: иначе в слой
/// состояния приехал бы `flutter/widgets`. Внешние изменения применяются
/// только если текст действительно разошёлся — иначе курсор прыгал бы в
/// начало на каждой перерисовке.
class TranscriptEditor extends StatefulWidget {
  const TranscriptEditor({
    super.key,
    required this.text,
    required this.readOnly,
    this.dimmed = false,
  });

  final String text;

  /// Во время записи и распознавания текст показываем, но не даём править.
  final bool readOnly;

  /// Приглушить — старый текст на время новой записи.
  final bool dimmed;

  @override
  State<TranscriptEditor> createState() => _TranscriptEditorState();
}

class _TranscriptEditorState extends State<TranscriptEditor> {
  late final TextEditingController _text =
      TextEditingController(text: widget.text);

  @override
  void didUpdateWidget(TranscriptEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncFromOutside();
  }

  void _syncFromOutside() {
    if (widget.text == _text.text) return;

    _text.value = TextEditingValue(
      text: widget.text,
      selection: TextSelection.collapsed(offset: widget.text.length),
    );
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return TextField(
      controller: _text,
      readOnly: widget.readOnly,
      maxLines: null,
      expands: false,
      keyboardType: TextInputType.multiline,
      textCapitalization: TextCapitalization.sentences,
      cursorColor: scheme.primary,
      style: theme.textTheme.bodyLarge?.copyWith(
        fontSize: 17,
        height: 1.45,
        color: widget.dimmed
            ? scheme.onSurface.withValues(alpha: 0.45)
            : scheme.onSurface,
      ),
      decoration: const InputDecoration(
        contentPadding: EdgeInsets.symmetric(vertical: kGapS),
      ),
      onChanged: context.read<AppController>().editCurrent,
    );
  }
}

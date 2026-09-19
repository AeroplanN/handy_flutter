import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/asr_model.dart';
import '../../models/history_entry.dart';
import '../../services/app_paths.dart';
import '../../state/app_controller.dart';
import '../tokens.dart';

/// Одна расшифровка целиком: прочитать, поправить, скопировать, отправить.
///
/// Отдельный экран, а не шторка: править длинный текст под клавиатурой в
/// нижнем листе неудобно.
class HistoryDetailScreen extends StatefulWidget {
  const HistoryDetailScreen({
    super.key,
    required this.entry,
    this.onTextChanged,
    this.onTogglePinned,
  });

  final HistoryEntry entry;

  /// Сообщить списку, что текст изменился, — чтобы строка обновилась.
  final Future<void> Function(String text)? onTextChanged;
  final Future<void> Function()? onTogglePinned;

  @override
  State<HistoryDetailScreen> createState() => _HistoryDetailScreenState();
}

class _HistoryDetailScreenState extends State<HistoryDetailScreen> {
  late final TextEditingController _text =
      TextEditingController(text: widget.entry.text);
  late HistoryEntry _entry = widget.entry;

  Timer? _autosave;

  @override
  void dispose() {
    _autosave?.cancel();
    // Уходим с экрана — дописывать уже некому, сохраняем сразу.
    unawaited(_save());
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_text.text == _entry.text) return;

    final text = _text.text;
    _entry = _entry.copyWith(text: text);

    final notify = widget.onTextChanged;
    if (notify != null) {
      await notify(text);
    } else if (mounted) {
      await context.read<AppController>().updateEntryText(widget.entry, text);
    }
  }

  void _scheduleSave() {
    _autosave?.cancel();
    _autosave = Timer(const Duration(milliseconds: 1500), _save);
  }

  Future<void> _togglePinned() async {
    final toggle = widget.onTogglePinned;
    if (toggle != null) {
      await toggle();
    } else if (mounted) {
      await context.read<AppController>().toggleSaved(_entry);
    }
    if (mounted) setState(() => _entry = _entry.copyWith(saved: !_entry.saved));
  }

  Future<void> _shareAudio() async {
    final fileName = _entry.fileName;
    if (fileName == null) return;

    final paths = await AppPaths.instance();
    final path = paths.recordingPath(fileName);
    if (!File(path).existsSync()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Запись уже удалена по сроку хранения')),
      );
      return;
    }

    await SharePlus.instance.share(
      ShareParams(files: [XFile(path)], text: _entry.title),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final controller = context.read<AppController>();

    final model = modelById(_entry.modelId)?.name ?? _entry.modelId;
    final meta = <String>[
      DateFormat('d MMMM, HH:mm', 'ru').format(_entry.timestamp),
      if (_entry.durationMs > 0)
        '${(_entry.durationMs / 1000).round() ~/ 60}:'
            '${((_entry.durationMs / 1000).round() % 60).toString().padLeft(2, '0')}',
      model,
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Расшифровка'),
        actions: [
          IconButton(
            onPressed: _togglePinned,
            tooltip: _entry.saved ? 'Открепить' : 'Закрепить',
            icon: Icon(
              _entry.saved ? Icons.push_pin_rounded : Icons.push_pin_outlined,
              color: _entry.saved ? scheme.primary : null,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: kScreenPadding,
              child: Text(
                meta.join('  ·  '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontFeatures: kTabularFigures,
                ),
              ),
            ),
            const SizedBox(height: kGapS),
            Expanded(
              child: SingleChildScrollView(
                padding: kScreenPadding,
                child: TextField(
                  controller: _text,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  cursorColor: scheme.primary,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontSize: 17,
                    height: 1.45,
                  ),
                  onChanged: (_) => _scheduleSave(),
                ),
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(kGapS),
              child: Wrap(
                alignment: WrapAlignment.spaceEvenly,
                children: [
                  TextButton.icon(
                    onPressed: () => controller.copyEntry(_entry),
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Копировать'),
                  ),
                  TextButton.icon(
                    onPressed: () => controller.shareEntry(_entry),
                    icon: const Icon(Icons.ios_share_rounded, size: 18),
                    label: const Text('Поделиться'),
                  ),
                  if (_entry.fileName != null)
                    TextButton.icon(
                      onPressed: _shareAudio,
                      icon: const Icon(Icons.graphic_eq_rounded, size: 18),
                      label: const Text('Аудио'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

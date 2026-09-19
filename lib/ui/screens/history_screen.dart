import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/history_entry.dart';
import '../../state/app_controller.dart';
import '../../state/history_list_controller.dart';
import '../tokens.dart';
import '../widgets/history_tile.dart';
import 'history_detail_screen.dart';

/// Все расшифровки: поиск по базе, фильтры, подгрузка по мере прокрутки.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late final HistoryListController _list =
      HistoryListController(context.read<AppController>())..load();

  final TextEditingController _search = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    final remaining = _scroll.position.maxScrollExtent - _scroll.position.pixels;
    if (remaining < 400) _list.loadMore();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    _list.dispose();
    super.dispose();
  }

  void _openEntry(HistoryEntry entry) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HistoryDetailScreen(
          entry: entry,
          onTextChanged: (text) => _list.updateText(entry, text),
          onTogglePinned: () => _list.togglePinned(entry),
        ),
      ),
    );
  }

  void _deleteWithUndo(HistoryEntry entry) {
    _list.deleteWithUndo(entry);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Расшифровка удалена'),
          action: SnackBarAction(
            label: 'Вернуть',
            onPressed: () => _list.undoDelete(entry),
          ),
        ),
      );
  }

  Future<void> _confirmClear() async {
    final controller = context.read<AppController>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Очистить историю?'),
        content: const Text(
          'Удалятся все расшифровки и сохранённые аудиозаписи, включая '
          'закреплённые. Отменить это нельзя.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Очистить'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      await controller.clearHistory();
      await _list.load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _list,
      builder: (context, _) {
        final entries = _list.entries;

        return Scaffold(
          appBar: AppBar(
            title: const Text('История'),
            actions: [
              IconButton(
                onPressed: _confirmClear,
                icon: const Icon(Icons.delete_sweep_outlined),
                tooltip: 'Очистить историю',
              ),
            ],
          ),
          body: Column(
            children: [
              _SearchField(controller: _search, onChanged: _list.search),
              _Filters(
                current: _list.filter,
                onChanged: _list.setFilter,
              ),
              Expanded(
                child: entries.isEmpty
                    ? _EmptyState(
                        query: _list.query,
                        filter: _list.filter,
                        loading: _list.loading,
                      )
                    : _EntryList(
                        rows: _buildRows(entries),
                        scroll: _scroll,
                        loadingMore: _list.loading,
                        onOpen: _openEntry,
                        onDelete: _deleteWithUndo,
                        onTogglePinned: _list.togglePinned,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Плоский список с заголовками дней — дешевле и проще, чем sliver-группы.
  List<_Row> _buildRows(List<HistoryEntry> entries) {
    final rows = <_Row>[];
    String? lastDay;

    for (final entry in entries) {
      final day = _dayLabel(entry.timestamp);
      if (day != lastDay) {
        rows.add(_Row.header(day));
        lastDay = day;
      }
      rows.add(_Row.entry(entry));
    }

    return rows;
  }

  static String _dayLabel(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(timestamp.year, timestamp.month, timestamp.day);
    final diff = today.difference(day).inDays;

    if (diff == 0) return 'Сегодня';
    if (diff == 1) return 'Вчера';
    if (timestamp.year == now.year) {
      return DateFormat('d MMMM', 'ru').format(timestamp);
    }
    return DateFormat('d MMMM y', 'ru').format(timestamp);
  }
}

/// Элемент списка: заголовок дня или запись.
class _Row {
  const _Row.header(this.day) : entry = null;
  const _Row.entry(this.entry) : day = null;

  final String? day;
  final HistoryEntry? entry;
}

class _EntryList extends StatelessWidget {
  const _EntryList({
    required this.rows,
    required this.scroll,
    required this.loadingMore,
    required this.onOpen,
    required this.onDelete,
    required this.onTogglePinned,
  });

  final List<_Row> rows;
  final ScrollController scroll;
  final bool loadingMore;
  final void Function(HistoryEntry) onOpen;
  final void Function(HistoryEntry) onDelete;
  final void Function(HistoryEntry) onTogglePinned;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView.builder(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(kGapL, kGapS, kGapL, kGapXL),
      itemCount: rows.length + (loadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= rows.length) {
          return const Padding(
            padding: EdgeInsets.all(kGapL),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final row = rows[index];
        final day = row.day;
        if (day != null) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(kGapXS, kGapM, 0, kGapS),
            child: Text(
              day,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }

        final entry = row.entry!;
        return HistoryTile(
          entry: entry,
          onTap: () => onOpen(entry),
          onDelete: () => onDelete(entry),
          onTogglePinned: () => onTogglePinned(entry),
        );
      },
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(kGapL, 0, kGapL, kGapS),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Поиск по расшифровкам',
          prefixIcon: const Icon(Icons.search_rounded),
          filled: true,
          fillColor: scheme.surfaceContainerLow,
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(kRadiusField),
            borderSide: BorderSide.none,
          ),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
        ),
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({required this.current, required this.onChanged});

  final HistoryFilter current;
  final ValueChanged<HistoryFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: kGapL),
        child: Row(
          children: [
            for (final (filter, label) in const [
              (HistoryFilter.all, 'Все'),
              (HistoryFilter.pinned, 'Закреплённые'),
              (HistoryFilter.withAudio, 'С аудио'),
            ])
              Padding(
                padding: const EdgeInsets.only(right: kGapS),
                child: FilterChip(
                  label: Text(label),
                  selected: current == filter,
                  onSelected: (_) => onChanged(filter),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.query,
    required this.filter,
    required this.loading,
  });

  final String query;
  final HistoryFilter filter;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final (icon, title, hint) = switch ((query.isNotEmpty, filter)) {
      (true, _) => (
          Icons.search_off_rounded,
          'Ничего не найдено',
          'Попробуйте другое слово.',
        ),
      (_, HistoryFilter.pinned) => (
          Icons.push_pin_outlined,
          'Нет закреплённых',
          'Смахните запись вправо, чтобы закрепить её.',
        ),
      (_, HistoryFilter.withAudio) => (
          Icons.graphic_eq_rounded,
          'Нет записей с аудио',
          'Хранение аудио настраивается в разделе «Хранилище».',
        ),
      _ => (
          Icons.history_rounded,
          'Пока ничего не записано',
          'Расшифровки будут появляться здесь автоматически.',
        ),
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(kGapXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: scheme.onSurfaceVariant),
            const SizedBox(height: kGapM),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: kGapXS),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

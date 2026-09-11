import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/history_entry.dart';
import '../../state/app_controller.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();

    final entries = _query.isEmpty
        ? controller.entries
        : controller.entries
            .where((e) => e.text.toLowerCase().contains(_query.toLowerCase()))
            .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('История'),
        actions: [
          if (controller.entries.isNotEmpty)
            IconButton(
              tooltip: 'Очистить историю',
              onPressed: () => _confirmClear(context, controller),
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'Поиск по расшифровкам',
                prefixIcon: const Icon(Icons.search_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
            ),
          ),
          Expanded(
            child: entries.isEmpty
                ? _EmptyState(hasQuery: _query.isNotEmpty)
                : RefreshIndicator(
                    onRefresh: controller.reloadHistory,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: entries.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) => _HistoryTile(
                        entry: entries[index],
                        controller: controller,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClear(
    BuildContext context,
    AppController controller,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Очистить историю?'),
        content: const Text(
          'Все расшифровки и сохранённые аудиозаписи будут удалены. '
          'Отменить это действие нельзя.',
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

    if (confirmed == true) await controller.clearHistory();
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry, required this.controller});

  final HistoryEntry entry;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Dismissible(
      key: ValueKey(entry.id ?? entry.timestamp.millisecondsSinceEpoch),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
      ),
      onDismissed: (_) => controller.deleteEntry(entry),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showDetails(context),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _formatTimestamp(entry.timestamp),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${entry.wordCount} сл.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    if (entry.saved)
                      Icon(Icons.push_pin, size: 16, color: scheme.primary),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  entry.text,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showDetails(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatTimestamp(entry.timestamp),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: SelectableText(
                    entry.text,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  IconButton(
                    tooltip: entry.saved ? 'Открепить' : 'Закрепить',
                    onPressed: () {
                      controller.toggleSaved(entry);
                      Navigator.of(sheetContext).pop();
                    },
                    icon: Icon(
                      entry.saved
                          ? Icons.push_pin
                          : Icons.push_pin_outlined,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () async {
                      await controller.copyEntry(entry);
                      if (!sheetContext.mounted) return;
                      Navigator.of(sheetContext).pop();
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Копировать'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => controller.shareEntry(entry),
                    icon: const Icon(Icons.ios_share_rounded, size: 18),
                    label: const Text('Поделиться'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final sameDay = now.year == timestamp.year &&
        now.month == timestamp.month &&
        now.day == timestamp.day;

    return sameDay
        ? 'сегодня, ${DateFormat.Hm('ru').format(timestamp)}'
        : DateFormat('d MMMM, HH:mm', 'ru').format(timestamp);
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasQuery});

  final bool hasQuery;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasQuery ? Icons.search_off_rounded : Icons.history_rounded,
            size: 48,
            color: scheme.outline,
          ),
          const SizedBox(height: 12),
          Text(
            hasQuery ? 'Ничего не найдено' : 'Пока ничего не записано',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

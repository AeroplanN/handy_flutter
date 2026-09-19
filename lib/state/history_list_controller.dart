import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/history_entry.dart';
import 'app_controller.dart';

/// Какие записи показывать.
enum HistoryFilter { all, pinned, withAudio }

/// Список истории: поиск, фильтр, подгрузка по мере прокрутки и отмена
/// удаления.
///
/// Живёт столько же, сколько экран истории: держать полсотни записей в
/// памяти постоянно незачем.
class HistoryListController extends ChangeNotifier {
  HistoryListController(this._app);

  static const _pageSize = 50;

  /// Сколько времени можно передумать после свайпа.
  static const _undoWindow = Duration(seconds: 4);

  final AppController _app;

  final List<HistoryEntry> _entries = [];
  List<HistoryEntry> get entries => List.unmodifiable(_entries);

  String _query = '';
  String get query => _query;

  HistoryFilter _filter = HistoryFilter.all;
  HistoryFilter get filter => _filter;

  bool _loading = false;
  bool get loading => _loading;

  bool _hasMore = true;
  bool get hasMore => _hasMore;

  Timer? _debounce;

  /// Записи, удаление которых ещё можно отменить: они уже убраны из списка,
  /// но из базы исчезнут по истечении окна отмены.
  final Map<int, (HistoryEntry, int, Timer)> _pendingDeletes = {};

  Future<void> load() => _reload();

  void search(String value) {
    if (value == _query) return;
    _query = value;
    notifyListeners();

    // Ждём паузы в наборе: иначе каждый символ уходил бы запросом в базу.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _reload);
  }

  void setFilter(HistoryFilter value) {
    if (value == _filter) return;
    _filter = value;
    unawaited(_reload());
  }

  Future<void> _reload() async {
    _loading = true;
    notifyListeners();

    final page = await _fetch(offset: 0);

    _entries
      ..clear()
      ..addAll(page);
    _hasMore = page.length == _pageSize;
    _loading = false;
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (_loading || !_hasMore) return;

    _loading = true;
    notifyListeners();

    final page = await _fetch(offset: _entries.length);

    _entries.addAll(page);
    _hasMore = page.length == _pageSize;
    _loading = false;
    notifyListeners();
  }

  Future<List<HistoryEntry>> _fetch({required int offset}) => _app.loadHistoryPage(
        offset: offset,
        limit: _pageSize,
        query: _query,
        pinnedOnly: _filter == HistoryFilter.pinned,
        withAudioOnly: _filter == HistoryFilter.withAudio,
      );

  /// Убирает запись из списка, но не из базы: настоящее удаление сносит и
  /// звуковой файл, а его уже не вернуть.
  void deleteWithUndo(HistoryEntry entry) {
    final id = entry.id;
    if (id == null) return;

    final index = _entries.indexWhere((e) => e.id == id);
    if (index < 0) return;

    _entries.removeAt(index);
    notifyListeners();

    final timer = Timer(_undoWindow, () => _commitDelete(id));
    _pendingDeletes[id] = (entry, index, timer);
  }

  void undoDelete(HistoryEntry entry) {
    final id = entry.id;
    final pending = id == null ? null : _pendingDeletes.remove(id);
    if (pending == null) return;

    final (restored, index, timer) = pending;
    timer.cancel();

    _entries.insert(index.clamp(0, _entries.length), restored);
    notifyListeners();
  }

  void _commitDelete(int id) {
    final pending = _pendingDeletes.remove(id);
    if (pending == null) return;

    unawaited(_app.deleteEntry(pending.$1));
  }

  Future<void> togglePinned(HistoryEntry entry) async {
    await _app.toggleSaved(entry);
    _replace(entry.copyWith(saved: !entry.saved));

    // В режиме «только закреплённые» открепление убирает запись из списка.
    if (_filter == HistoryFilter.pinned && entry.saved) {
      _entries.removeWhere((e) => e.id == entry.id);
      notifyListeners();
    }
  }

  Future<void> updateText(HistoryEntry entry, String text) async {
    await _app.updateEntryText(entry, text);
    _replace(entry.copyWith(text: text));
  }

  void _replace(HistoryEntry updated) {
    final index = _entries.indexWhere((e) => e.id == updated.id);
    if (index < 0) return;

    _entries[index] = updated;
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();

    // Экран закрывают — доводим отложенные удаления до конца,
    // иначе запись «вернётся» при следующем открытии истории.
    for (final entry in _pendingDeletes.values) {
      entry.$3.cancel();
      unawaited(_app.deleteEntry(entry.$1));
    }
    _pendingDeletes.clear();

    super.dispose();
  }
}

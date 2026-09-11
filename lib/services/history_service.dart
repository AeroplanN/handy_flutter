import 'dart:io';

import 'package:sqflite/sqflite.dart';

import '../models/history_entry.dart';
import '../models/settings.dart';
import 'app_paths.dart';

/// История расшифровок в SQLite — как `HistoryManager` в десктопном Handy.
class HistoryService {
  Database? _db;

  Future<Database> _open() async {
    final existing = _db;
    if (existing != null) return existing;

    final paths = await AppPaths.instance();
    final db = await openDatabase(
      paths.databaseFile,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE transcription_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp INTEGER NOT NULL,
            text TEXT NOT NULL,
            model_id TEXT NOT NULL DEFAULT '',
            file_name TEXT,
            duration_ms INTEGER NOT NULL DEFAULT 0,
            saved INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_history_timestamp ON transcription_history (timestamp DESC)',
        );
      },
    );
    _db = db;
    return db;
  }

  Future<List<HistoryEntry>> list({int limit = 100, int offset = 0}) async {
    final db = await _open();
    final rows = await db.query(
      'transcription_history',
      orderBy: 'timestamp DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(HistoryEntry.fromRow).toList();
  }

  Future<List<HistoryEntry>> search(String query) async {
    final db = await _open();
    final rows = await db.query(
      'transcription_history',
      where: 'text LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'timestamp DESC',
      limit: 200,
    );
    return rows.map(HistoryEntry.fromRow).toList();
  }

  Future<HistoryEntry> add(HistoryEntry entry) async {
    final db = await _open();
    final id = await db.insert('transcription_history', entry.toRow());
    return entry.copyWith(id: id);
  }

  Future<void> updateText(int id, String text) async {
    final db = await _open();
    await db.update(
      'transcription_history',
      {'text': text},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> toggleSaved(int id, bool saved) async {
    final db = await _open();
    await db.update(
      'transcription_history',
      {'saved': saved ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> delete(HistoryEntry entry) async {
    final db = await _open();
    if (entry.id != null) {
      await db.delete(
        'transcription_history',
        where: 'id = ?',
        whereArgs: [entry.id],
      );
    }
    await _deleteRecording(entry.fileName);
  }

  Future<void> clear() async {
    final db = await _open();
    await db.delete('transcription_history');

    final paths = await AppPaths.instance();
    if (await paths.recordings.exists()) {
      await for (final file in paths.recordings.list()) {
        if (file is File) await file.delete();
      }
    }
  }

  Future<int> count() async {
    final db = await _open();
    final result =
        await db.rawQuery('SELECT COUNT(*) AS c FROM transcription_history');
    return (result.first['c'] as int?) ?? 0;
  }

  /// Подрезает историю до лимита и удаляет аудио по политике хранения.
  /// Закреплённые записи (`saved`) не трогаем.
  Future<void> applyRetention(Settings settings) async {
    final db = await _open();

    final overflow = await db.rawQuery(
      '''
      SELECT * FROM transcription_history
      WHERE saved = 0
      ORDER BY timestamp DESC
      LIMIT -1 OFFSET ?
      ''',
      [settings.historyLimit],
    );
    for (final row in overflow) {
      final entry = HistoryEntry.fromRow(row);
      await delete(entry);
    }

    final maxAge = settings.recordingRetention.maxAge;
    if (maxAge != null) {
      final cutoff = DateTime.now().subtract(maxAge).millisecondsSinceEpoch;
      final stale = await db.query(
        'transcription_history',
        where: 'timestamp < ? AND file_name IS NOT NULL AND saved = 0',
        whereArgs: [cutoff],
      );
      for (final row in stale) {
        final entry = HistoryEntry.fromRow(row);
        await _deleteRecording(entry.fileName);
        await db.update(
          'transcription_history',
          {'file_name': null},
          where: 'id = ?',
          whereArgs: [entry.id],
        );
      }
    }
  }

  Future<void> _deleteRecording(String? fileName) async {
    if (fileName == null) return;
    final paths = await AppPaths.instance();
    final file = File(paths.recordingPath(fileName));
    if (await file.exists()) await file.delete();
  }
}

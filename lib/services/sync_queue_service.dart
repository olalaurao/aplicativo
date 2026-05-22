// lib/services/sync_queue_service.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import '../models/sync_action.dart';

class SyncQueueService {
  Database? _db;

  Future<void> init() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'sync_queue.db');

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE sync_actions(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            objectType TEXT,
            objectId TEXT,
            operation INTEGER,
            payload TEXT,
            timestamp INTEGER
          )
        ''');
      },
    );
  }

  Future<void> enqueueAction(SyncAction action) async {
    if (_db == null) throw Exception('Database not initialized');
    await _db!.insert(
      'sync_actions',
      action.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<SyncAction>> getPendingActions() async {
    if (_db == null) throw Exception('Database not initialized');
    final List<Map<String, dynamic>> maps = await _db!.query(
      'sync_actions',
      orderBy: 'timestamp ASC',
    );
    return List.generate(maps.length, (i) {
      return SyncAction.fromMap(maps[i]);
    });
  }

  Future<void> dequeueAction(int id) async {
    if (_db == null) throw Exception('Database not initialized');
    await _db!.delete('sync_actions', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> processQueue(Future<void> Function(SyncAction) syncFn) async {
    if (_db == null) return;

    final actions = await getPendingActions();
    for (final action in actions) {
      try {
        await syncFn(action);
        await dequeueAction(action.id!);
      } catch (e) {
        debugPrint('Error syncing action ${action.id}: $e');
        // Stop processing for now, will retry later
        break;
      }
    }
  }

  Future<void> clearQueue() async {
    if (_db == null) throw Exception('Database not initialized');
    await _db!.delete('sync_actions');
  }
}

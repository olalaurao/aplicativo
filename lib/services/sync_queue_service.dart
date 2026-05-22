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
      version: 2,
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await _createTables(db);
      },
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_actions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        objectType TEXT,
        objectId TEXT,
        operation INTEGER,
        payload TEXT,
        timestamp INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS file_sync_state(
        relativePath TEXT PRIMARY KEY,
        localHash TEXT,
        remoteHash TEXT,
        baseHash TEXT,
        remoteFileId TEXT,
        lastSyncedAt INTEGER,
        localModifiedAt INTEGER,
        remoteModifiedAt INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_conflicts(
        relativePath TEXT PRIMARY KEY,
        localPath TEXT,
        remotePath TEXT,
        detectedAt INTEGER
      )
    ''');
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

  Future<Map<String, dynamic>?> getFileSyncState(String relativePath) async {
    if (_db == null) throw Exception('Database not initialized');
    final rows = await _db!.query(
      'file_sync_state',
      where: 'relativePath = ?',
      whereArgs: [relativePath],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> upsertFileSyncState({
    required String relativePath,
    required String localHash,
    required String remoteHash,
    required String baseHash,
    String? remoteFileId,
    DateTime? localModifiedAt,
    DateTime? remoteModifiedAt,
  }) async {
    if (_db == null) throw Exception('Database not initialized');
    await _db!.insert('file_sync_state', {
      'relativePath': relativePath,
      'localHash': localHash,
      'remoteHash': remoteHash,
      'baseHash': baseHash,
      'remoteFileId': remoteFileId,
      'lastSyncedAt': DateTime.now().millisecondsSinceEpoch,
      'localModifiedAt': localModifiedAt?.millisecondsSinceEpoch,
      'remoteModifiedAt': remoteModifiedAt?.millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> removeFileSyncState(String relativePath) async {
    if (_db == null) throw Exception('Database not initialized');
    await _db!.delete(
      'file_sync_state',
      where: 'relativePath = ?',
      whereArgs: [relativePath],
    );
  }

  Future<List<Map<String, dynamic>>> getConflicts() async {
    if (_db == null) throw Exception('Database not initialized');
    return _db!.query('sync_conflicts', orderBy: 'detectedAt DESC');
  }

  Future<void> upsertConflict({
    required String relativePath,
    required String localPath,
    required String remotePath,
    required DateTime detectedAt,
  }) async {
    if (_db == null) throw Exception('Database not initialized');
    await _db!.insert('sync_conflicts', {
      'relativePath': relativePath,
      'localPath': localPath,
      'remotePath': remotePath,
      'detectedAt': detectedAt.millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> removeConflict(String relativePath) async {
    if (_db == null) throw Exception('Database not initialized');
    await _db!.delete(
      'sync_conflicts',
      where: 'relativePath = ?',
      whereArgs: [relativePath],
    );
  }
}

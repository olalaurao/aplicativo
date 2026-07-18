// lib/services/sync_queue_service.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import '../models/sync_action.dart';

class SyncQueueService {
  Database? _db;

  Future<void> init() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'sync_queue.db');

    _db = await openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await _createTables(db);
        if (oldVersion < 3) {
          await db.execute('''
            ALTER TABLE sync_conflicts ADD COLUMN localModifiedAt INTEGER
          ''');
          await db.execute('''
            ALTER TABLE sync_conflicts ADD COLUMN remoteModifiedAt INTEGER
          ''');
        }
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
        detectedAt INTEGER,
        localModifiedAt INTEGER,
        remoteModifiedAt INTEGER
      )
    ''');
  }

  Future<void> enqueueAction(SyncAction action) async {
    if (_db == null) throw Exception('Database not initialized');
    
    // Find any existing actions for this specific object in the queue
    final existing = await _db!.query(
      'sync_actions',
      where: 'objectType = ? AND objectId = ?',
      whereArgs: [action.objectType, action.objectId],
      orderBy: 'timestamp ASC',
    );

    if (existing.isNotEmpty) {
      final firstActionMap = existing.first;
      final firstId = firstActionMap['id'] as int;
      final firstOp = SyncOperation.values[firstActionMap['operation'] as int];

      if (action.operation == SyncOperation.delete) {
        if (firstOp == SyncOperation.create) {
          // If created offline and then deleted offline, we don't need any sync action
          await _db!.delete(
            'sync_actions',
            where: 'objectType = ? AND objectId = ?',
            whereArgs: [action.objectType, action.objectId],
          );
        } else {
          // Keep a single delete action: remove others and update the first to be a delete
          await _db!.delete(
            'sync_actions',
            where: 'objectType = ? AND objectId = ? AND id != ?',
            whereArgs: [action.objectType, action.objectId, firstId],
          );
          await _db!.update(
            'sync_actions',
            action.toMap()..remove('id'),
            where: 'id = ?',
            whereArgs: [firstId],
          );
        }
      } else if (action.operation == SyncOperation.update) {
        if (firstOp == SyncOperation.create) {
          // Keep it as a CREATE action but update its payload/timestamp to the latest
          await _db!.delete(
            'sync_actions',
            where: 'objectType = ? AND objectId = ? AND id != ?',
            whereArgs: [action.objectType, action.objectId, firstId],
          );
          await _db!.update(
            'sync_actions',
            {
              'payload': jsonEncode(action.payload),
              'timestamp': action.timestamp.millisecondsSinceEpoch,
            },
            where: 'id = ?',
            whereArgs: [firstId],
          );
        } else {
          // Keep a single update action and update its payload/timestamp to the latest
          await _db!.delete(
            'sync_actions',
            where: 'objectType = ? AND objectId = ? AND id != ?',
            whereArgs: [action.objectType, action.objectId, firstId],
          );
          await _db!.update(
            'sync_actions',
            {
              'payload': jsonEncode(action.payload),
              'timestamp': action.timestamp.millisecondsSinceEpoch,
            },
            where: 'id = ?',
            whereArgs: [firstId],
          );
        }
      } else {
        // Fallback or multiple creates: insert and let it overwrite via replace
        await _db!.insert(
          'sync_actions',
          action.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    } else {
      await _db!.insert(
        'sync_actions',
        action.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
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
    
    // Group actions by unique object key (objectType/objectId) to coalesce them
    final grouped = <String, List<SyncAction>>{};
    final order = <String>[];

    for (final action in actions) {
      final key = '${action.objectType}/${action.objectId}';
      if (!grouped.containsKey(key)) {
        order.add(key);
        grouped[key] = [];
      }
      grouped[key]!.add(action);
    }

    for (final key in order) {
      final group = grouped[key]!;
      if (group.isEmpty) continue;

      final firstAction = group.first;
      final lastAction = group.last;

      final isCreatedOffline = firstAction.operation == SyncOperation.create;
      final isDeletedOffline = lastAction.operation == SyncOperation.delete;

      if (isCreatedOffline && isDeletedOffline) {
        // Dequeue everything for this object since it has been discarded offline
        for (final action in group) {
          if (action.id != null) {
            await dequeueAction(action.id!);
          }
        }
        continue;
      }

      final netOp = isDeletedOffline
          ? SyncOperation.delete
          : (isCreatedOffline ? SyncOperation.create : SyncOperation.update);

      final coalescedAction = SyncAction(
        id: lastAction.id,
        objectType: lastAction.objectType,
        objectId: lastAction.objectId,
        operation: netOp,
        payload: lastAction.payload,
        timestamp: lastAction.timestamp,
      );

      try {
        await syncFn(coalescedAction);
        
        // On success, dequeue all the merged actions from the database
        for (final action in group) {
          if (action.id != null) {
            await dequeueAction(action.id!);
          }
        }
      } catch (e) {
        debugPrint('Error syncing coalesced action for $key: $e');
        // Halting execution on first failure is safer to maintain order and consistency
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

  Future<void> resetFileSyncState() async {
    if (_db == null) throw Exception('Database not initialized');
    await _db!.delete('file_sync_state');
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
    DateTime? localModifiedAt,
    DateTime? remoteModifiedAt,
  }) async {
    if (_db == null) throw Exception('Database not initialized');
    await _db!.insert('sync_conflicts', {
      'relativePath': relativePath,
      'localPath': localPath,
      'remotePath': remotePath,
      'detectedAt': detectedAt.millisecondsSinceEpoch,
      'localModifiedAt': localModifiedAt?.millisecondsSinceEpoch,
      'remoteModifiedAt': remoteModifiedAt?.millisecondsSinceEpoch,
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

// lib/services/sync_manager.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/googleapis_auth.dart';
import 'google_drive_sync_service.dart';
import 'google_auth_service.dart';
import 'obsidian_service.dart';
import 'dataview_generator.dart';
import 'notification_service.dart';
import 'sync_queue_service.dart';
import '../models/content_object.dart';
import '../models/sync_action.dart';
import '../models/task_model.dart';
import '../providers/sync_provider.dart';
import '../providers/vault_provider.dart';
import '../providers/settings_provider.dart';

final syncManagerProvider = Provider<SyncManager>((ref) {
  final manager = SyncManager(ref);
  return manager;
});

class SyncManager {
  static const Duration _syncTimeout = Duration(minutes: 5);

  final Ref _ref;
  Timer? _syncTimer;
  Timer? _syncDebounceTimer; // Debounce for rapid sync triggers
  bool _isSyncing = false;
  bool _preSyncBackupCreated = false;
  bool _syncHadConflict = false;
  DateTime? _lastSyncCompletion;
  static const Duration _syncCooldown = Duration(seconds: 10);
  bool _isAppStarting = true; // Guard to prevent sync during startup

  SyncManager(this._ref) {
    // PERMANENTLY disable sync to prevent crashes
    _isAppStarting = true;
    // Cancel any existing timers from previous hot restarts
    _syncTimer?.cancel();
    _syncDebounceTimer?.cancel();
  }

  void start() {
    debugPrint('[SyncManager] start() called');
    _syncTimer?.cancel();
    // DISABLED: Periodic sync causing crashes
    // _syncTimer = Timer.periodic(const Duration(minutes: 15), (_) {
    //   if (_ref.read(settingsProvider).autoSync) {
    //     performSync(debounce: true);
    //   }
    // });

    // Initial sync and cleanup - defer to avoid startup load
    debugPrint('[SyncManager] Scheduling startup tasks in 5 seconds');
    Future.delayed(const Duration(seconds: 5), () {
      debugPrint('[SyncManager] Executing startup tasks now');
      _runStartupTasks();
    });

    // DISABLED: Vault watcher causing ANR/crash even with error handling
    // debugPrint('[SyncManager] Setting up vault watcher with error handling');
    // _setupVaultWatcher();

    // Periodic Backup
    _setupBackupTimer();
  }

  Future<void> _runStartupTasks() async {
    debugPrint('[SyncManager] Running startup tasks');
    
    // DISABLED: Startup guard no longer needed without vault watcher
    // await Future.delayed(const Duration(seconds: 30));
    // _isAppStarting = false;
    // debugPrint('[SyncManager] Startup guard expired - vault watcher and sync now active');
    
    // DISABLED: Initial sync to prevent crashes
    // await performSync();
  }

  void _setupVaultWatcher() {
    final obsidian = _ref.read(obsidianServiceProvider);
    final watchStream = obsidian.watchVaultDebounced();
    if (watchStream != null) {
      watchStream.listen((events) {
        // Don't trigger vault invalidation during startup
        if (_isAppStarting) {
          debugPrint('[SyncManager] Vault watcher ignored during startup');
          return;
        }
        
        // Batch multiple file changes into a single invalidation
        var hasMdChanges = false;
        var hasDailyChanges = false;
        String? dailyDateStr;
        
        debugPrint('[VaultWatcher] Received ${events.length} events');
        
        for (final event in events) {
          debugPrint('[VaultWatcher] Event: ${event.path}, type: ${event.type}');
          if (event.path.endsWith('.md')) {
            hasMdChanges = true;
            if (event.path.contains('daily')) {
              hasDailyChanges = true;
              final dateMatch = RegExp(
                r'(\d{4}-\d{2}-\d{2})',
              ).firstMatch(event.path);
              if (dateMatch != null) {
                dailyDateStr = dateMatch.group(1);
              }
            }
          }
        }
        
        // Only invalidate if there were actual changes
        if (hasMdChanges) {
          debugPrint('[VaultWatcher] Invalidating allObjectsProvider');
          try {
            _ref.invalidate(allObjectsProvider);
            debugPrint('[VaultWatcher] allObjectsProvider invalidated successfully');
          } catch (e, st) {
            debugPrint('[VaultWatcher] Error invalidating allObjectsProvider: $e\n$st');
          }
          
          if (hasDailyChanges && dailyDateStr != null) {
            debugPrint('[VaultWatcher] Invalidating dailyNoteDataProvider for $dailyDateStr');
            try {
              _ref.invalidate(dailyNoteDataProvider(dailyDateStr));
              debugPrint('[VaultWatcher] dailyNoteDataProvider invalidated successfully');
            } catch (e, st) {
              debugPrint('[VaultWatcher] Error invalidating dailyNoteDataProvider: $e\n$st');
            }
          }
        }
      });
    }
  }

  void _setupBackupTimer() {
    Timer.periodic(const Duration(hours: 24), (timer) async {
      final backupService = _ref.read(backupServiceProvider);
      await backupService.createBackup();
    });
  }

  void stop() {
    _syncTimer?.cancel();
    _syncDebounceTimer?.cancel();
  }

  Future<void> performSync({bool debounce = false}) async {
    // DISABLED: Sync causing freeze/crash
    debugPrint('[SyncManager] Sync disabled to prevent freeze/crash');
    return;
    
    // Cancel any pending debounced sync
    _syncDebounceTimer?.cancel();

    // If debounce is requested, schedule sync after delay
    if (debounce) {
      _syncDebounceTimer = Timer(const Duration(seconds: 3), () {
        performSync(debounce: false);
      });
      return;
    }

    if (_isSyncing) return;

    // Startup guard: prevent sync during app startup
    if (_isAppStarting) {
      debugPrint('[SyncManager] Sync skipped: app is still starting');
      return;
    }

    // Cooldown: prevent rapid successive syncs
    if (_lastSyncCompletion != null) {
      final timeSinceLastSync = DateTime.now().difference(_lastSyncCompletion!);
      if (timeSinceLastSync < _syncCooldown) {
        debugPrint('[SyncManager] Sync cooldown active, skipping (${timeSinceLastSync.inSeconds}s since last sync)');
        return;
      }
    }

    final authService = _ref.read(googleAuthServiceProvider);
    final authClient = await authService.ensureClient().timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        debugPrint('[SyncManager] Google auth restore timed out.');
        return null;
      },
    );

    if (authClient == null) {
      _ref.read(syncStatusProvider.notifier).setStatus(SyncStatus.offline);
      return;
    }

    _isSyncing = true;
    _preSyncBackupCreated = false;
    _syncHadConflict = false;
    _ref.read(syncStatusProvider.notifier).setStatus(SyncStatus.syncing);
    _ref.read(syncProgressProvider.notifier).start(0, 'Iniciando sincronização...');

    try {
      await _performSyncWithClient(authClient).timeout(_syncTimeout);
      _ref
          .read(syncStatusProvider.notifier)
          .setStatus(
            _syncHadConflict ? SyncStatus.conflict : SyncStatus.synced,
          );
    } catch (e) {
      if (_isAuthError(e)) {
        try {
          final refreshedClient = await authService.ensureClient(
            forceRefresh: true,
          );
          if (refreshedClient != null) {
            await _performSyncWithClient(refreshedClient).timeout(_syncTimeout);
            _ref
                .read(syncStatusProvider.notifier)
                .setStatus(
                  _syncHadConflict ? SyncStatus.conflict : SyncStatus.synced,
                );
            return;
          }
        } catch (refreshError) {
          debugPrint('Sync auth refresh failed: $refreshError');
        }
      }

      debugPrint('Sync Error: $e');
      _ref.read(syncStatusProvider.notifier).setStatus(SyncStatus.error);
    } finally {
      _isSyncing = false;
      _lastSyncCompletion = DateTime.now();
      _ref.read(syncProgressProvider.notifier).reset();
    }
  }

  Future<void> _performSyncWithClient(AuthClient authClient) async {
    final driveSync = _ref.read(googleDriveSyncServiceProvider);
    final obsidian = _ref.read(obsidianServiceProvider);
    final queue = _ref.read(syncQueueServiceProvider);

    final settings = _ref.read(settingsProvider);
    driveSync.init(authClient);
    driveSync.onConflictDetected = ({
      required String relativePath,
      required String localContent,
      required String remoteContent,
    }) async {
      await _storeConflict(
        driveSync: driveSync,
        obsidian: obsidian,
        relativePath: relativePath,
        localContent: localContent,
        remoteContent: remoteContent,
      );
    };

    // Files that already have an unresolved conflict must not be re-compared
    // or re-flagged — that's what caused _conflicts/ to grow on every sync.
    final pendingConflictPaths = (await queue.getConflicts())
        .map((row) => row['relativePath'] as String)
        .toSet();

    debugPrint('[SyncManager] Preparing Drive folder.');
    if (settings.driveSyncFolderId.isNotEmpty) {
      await driveSync.useExistingVaultFolder(settings.driveSyncFolderId);
    } else {
      await driveSync.setupVaultFolder(settings.driveSyncFolder);
    }

    // 1. Push local queued edits first. Drive is the shared source of truth,
    // but offline mobile edits should reach it before we pull remote changes.
    debugPrint('[SyncManager] Processing local sync queue.');
    await queue.processQueue((action) async {
      final relativePath = await _relativePathForAction(action);
      if (relativePath == null && action.operation != SyncOperation.delete) {
        return;
      }

      if (relativePath != null && pendingConflictPaths.contains(relativePath)) {
        debugPrint('[SyncManager] Skipping $relativePath — unresolved conflict pending.');
        return;
      }

      // If it's a delete, we need to find the file ID on Drive
      if (action.operation == SyncOperation.delete) {
        // Fallback relative path if not found in memory (e.g. just deleted)
        final path = relativePath ?? _guessPathForAction(action);
        if (path == null) return;

        final remoteFiles = await driveSync.fetchRemoteFiles();
        final remoteFile = remoteFiles.where((f) => f.name == path).firstOrNull;
        if (remoteFile != null && remoteFile.id != null) {
          await driveSync.deleteFile(path, remoteFile.id!);
          debugPrint('Deleted $path from Drive');
        }
        return;
      }

      final content = await obsidian.readFile(relativePath!);
      if (content == null) return;

      final localHash = driveSync.calculateHash(content);
      final state = await queue.getFileSyncState(relativePath);
      final baseHash = state?['baseHash'] as String?;
      final remoteFile = (await driveSync.fetchRemoteFiles())
          .where((file) => file.name == relativePath)
          .firstOrNull;
      final remoteHash = remoteFile?.appProperties?['Quartzo_hash'];
      final localChanged = baseHash != null && localHash != baseHash;
      final remoteChanged =
          baseHash != null && remoteHash != null && remoteHash != baseHash;

      if (localChanged && remoteChanged && remoteFile?.id != null) {
        final remoteContent = await driveSync.downloadFile(remoteFile!.id!);
        if (remoteContent != null) {
          await _storeConflict(
            driveSync: driveSync,
            obsidian: obsidian,
            relativePath: relativePath,
            localContent: content,
            remoteContent: remoteContent,
            remoteModifiedAt: remoteFile.modifiedTime,
          );
        }
        return;
      }

      await _ensurePreSyncBackup(driveSync);
      final uploaded = await driveSync.syncFile(
        relativePath,
        content,
        localHash,
        baseHash: baseHash,
      );
      if (uploaded) {
        await queue.upsertFileSyncState(
          relativePath: relativePath,
          localHash: localHash,
          remoteHash: localHash,
          baseHash: localHash,
          remoteFileId: remoteFile?.id,
        );
      }
    });

    // 2. Pull remote changes after local queued edits are safely uploaded.
    debugPrint('[SyncManager] Running full Drive sync.');
    await _runFullSync(driveSync, obsidian, pendingConflictPaths);
    debugPrint('[SyncManager] Refreshing local notifications.');
    await _refreshNotificationsFromLocalVault();

    // 3. Update last successful sync timestamp for incremental sync
    await _ref.read(settingsProvider.notifier).updateLastSuccessfulSyncTime(DateTime.now());

    // 4. Regenerate Dataview queries in index.md files in each vault folder
    // Defer to background to avoid blocking sync completion
    Future.microtask(() async {
      try {
        debugPrint('[SyncManager] Regenerating Dataview indexes.');
        final gen = DataviewGenerator(obsidian);
        final projects = _ref.read(projectsProvider);
        final allObjects = _ref.read(allObjectsProvider).value ?? [];
        final tasks = allObjects.whereType<Task>().toList();
        await gen.regenerateAll(projects: projects, tasks: tasks);
        debugPrint('[SyncManager] Dataview regeneration completed.');
      } catch (e) {
        debugPrint('[SyncManager] Failed to regenerate Dataview during sync: $e');
      }
    });
  }

  bool _isAuthError(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('401') ||
        text.contains('403') ||
        text.contains('unauthorized') ||
        text.contains('invalid credentials') ||
        text.contains('access not configured');
  }

  Future<void> _runFullSync(
    GoogleDriveSyncService driveSync,
    ObsidianService obsidian,
    Set<String> pendingConflictPaths,
  ) async {
    final queue = _ref.read(syncQueueServiceProvider);
    final settings = _ref.read(settingsProvider);
    
    // Get last sync timestamp for incremental sync
    final lastSyncTime = settings.lastSuccessfulSyncTime;
    final remoteFiles = await driveSync.fetchRemoteFiles(
      modifiedSince: lastSyncTime,
    );
    
    // Otimização: buscar apenas arquivos locais modificados desde o último sync
    final localFiles = await _getModifiedLocalFiles(obsidian, queue, lastSyncTime);

    final Map<String, File> localMap = {
      for (var f in localFiles) obsidian.getRelativePath(f.path): f,
    };
    final Map<String, dynamic> remoteMap = {
      for (var f in remoteFiles) f.name!: f,
    };

    // Calculate total files to process for progress tracking
    final totalFiles = localMap.length + remoteMap.length;
    _ref.read(syncProgressProvider.notifier).start(
      totalFiles,
      'Sincronizando arquivos...',
    );

    int processedCount = 0;

    // 1. Upload local files that don't exist or are newer remotely
    for (final relPath in localMap.keys) {
      if (pendingConflictPaths.contains(relPath)) continue;

      final localFile = localMap[relPath]!;
      final remoteFile = remoteMap[relPath] as drive.File?;

      final content = await localFile.readAsString();
      final localHash = driveSync.calculateHash(content);
      final state = await queue.getFileSyncState(relPath);
      final baseHash = state?['baseHash'] as String?;

      if (remoteFile == null) {
        await _ensurePreSyncBackup(driveSync);
        final uploaded = await driveSync.syncFile(relPath, content, localHash);
        if (uploaded) {
          await queue.upsertFileSyncState(
            relativePath: relPath,
            localHash: localHash,
            remoteHash: localHash,
            baseHash: localHash,
            localModifiedAt: await localFile.lastModified(),
          );
        }
        processedCount++;
        _ref.read(syncProgressProvider.notifier).update(processedCount);
        continue;
      }

      final remoteHash = remoteFile.appProperties?['Quartzo_hash'];
      if (remoteHash == localHash) {
        await queue.upsertFileSyncState(
          relativePath: relPath,
          localHash: localHash,
          remoteHash: localHash,
          baseHash: localHash,
          remoteFileId: remoteFile.id,
          localModifiedAt: await localFile.lastModified(),
          remoteModifiedAt: remoteFile.modifiedTime,
        );
        processedCount++;
        _ref.read(syncProgressProvider.notifier).update(processedCount);
        continue;
      }

      final localChanged = baseHash != null && localHash != baseHash;
      final remoteChanged =
          baseHash != null && remoteHash != null && remoteHash != baseHash;

      if (localChanged && remoteChanged && remoteFile.id != null) {
        final remoteContent = await driveSync.downloadFile(remoteFile.id!);
        if (remoteContent != null) {
          await _storeConflict(
            driveSync: driveSync,
            obsidian: obsidian,
            relativePath: relPath,
            localContent: content,
            remoteContent: remoteContent,
            remoteModifiedAt: remoteFile.modifiedTime,
          );
        }
        processedCount++;
        _ref.read(syncProgressProvider.notifier).update(processedCount);
        continue;
      }

      if (remoteChanged && remoteFile.id != null) {
        final remoteContent = await driveSync.downloadFile(remoteFile.id!);
        if (remoteContent != null) {
          await _ensurePreSyncBackup(driveSync);
          await obsidian.writeFile(relPath, remoteContent);
          final newHash = driveSync.calculateHash(remoteContent);
          await queue.upsertFileSyncState(
            relativePath: relPath,
            localHash: newHash,
            remoteHash: newHash,
            baseHash: newHash,
            remoteFileId: remoteFile.id,
            remoteModifiedAt: remoteFile.modifiedTime,
          );
          debugPrint('Downloaded $relPath from Drive');
        }
        processedCount++;
        _ref.read(syncProgressProvider.notifier).update(processedCount);
        continue;
      }

      if (localChanged) {
        await _ensurePreSyncBackup(driveSync);
        final uploaded = await driveSync.syncFile(
          relPath,
          content,
          localHash,
          baseHash: baseHash,
        );
        if (uploaded) {
          await queue.upsertFileSyncState(
            relativePath: relPath,
            localHash: localHash,
            remoteHash: localHash,
            baseHash: localHash,
            remoteFileId: remoteFile.id,
            localModifiedAt: await localFile.lastModified(),
          );
        }
        processedCount++;
        _ref.read(syncProgressProvider.notifier).update(processedCount);
        continue;
      }

      if (remoteHash == null &&
          await _isRemoteFileNewer(remoteFile, localFile)) {
        if (remoteFile.id == null) continue;
        final remoteContent = await driveSync.downloadFile(remoteFile.id!);
        if (remoteContent != null) {
          // Optimistic concurrency check: re-read sync state before writing
          final currentSyncState = await queue.getFileSyncState(relPath);
          if (currentSyncState != null && currentSyncState['remoteHash'] != null) {
            // Another device already synced this file, treat as conflict
            await _storeConflict(
              driveSync: driveSync,
              obsidian: obsidian,
              relativePath: relPath,
              localContent: content,
              remoteContent: remoteContent,
              remoteModifiedAt: remoteFile.modifiedTime,
            );
            processedCount++;
            _ref.read(syncProgressProvider.notifier).update(processedCount);
            continue;
          }
          await _ensurePreSyncBackup(driveSync);
          await obsidian.writeFile(relPath, remoteContent);
          final newHash = driveSync.calculateHash(remoteContent);
          await queue.upsertFileSyncState(
            relativePath: relPath,
            localHash: newHash,
            remoteHash: newHash,
            baseHash: newHash,
            remoteFileId: remoteFile.id,
            remoteModifiedAt: remoteFile.modifiedTime,
          );
          debugPrint('Downloaded $relPath from Drive');
        }
        processedCount++;
        _ref.read(syncProgressProvider.notifier).update(processedCount);
      } else if (remoteHash == null &&
          await _isLocalFileNewer(localFile, remoteFile)) {
        // Optimistic concurrency check: re-read sync state before writing
        final currentSyncState = await queue.getFileSyncState(relPath);
        if (currentSyncState != null && currentSyncState['remoteHash'] != null) {
          // Another device already synced this file, treat as conflict
          final remoteContent = await driveSync.downloadFile(remoteFile.id!);
          if (remoteContent != null) {
            await _storeConflict(
              driveSync: driveSync,
              obsidian: obsidian,
              relativePath: relPath,
              localContent: content,
              remoteContent: remoteContent,
              remoteModifiedAt: remoteFile.modifiedTime,
            );
          }
          processedCount++;
          _ref.read(syncProgressProvider.notifier).update(processedCount);
          continue;
        }
        await _ensurePreSyncBackup(driveSync);
        final uploaded = await driveSync.syncFile(relPath, content, localHash);
        if (uploaded) {
          await queue.upsertFileSyncState(
            relativePath: relPath,
            localHash: localHash,
            remoteHash: localHash,
            baseHash: localHash,
            remoteFileId: remoteFile.id,
            localModifiedAt: await localFile.lastModified(),
          );
        }
        processedCount++;
        _ref.read(syncProgressProvider.notifier).update(processedCount);
      } else {
        // File not changed, just count it as processed
        processedCount++;
        _ref.read(syncProgressProvider.notifier).update(processedCount);
      }
    }

    // 2. Download remote files that don't exist locally or are newer
    for (final relPath in remoteMap.keys) {
      if (pendingConflictPaths.contains(relPath)) continue;

      final remoteFile = remoteMap[relPath] as drive.File;
      if (remoteFile.mimeType == 'application/vnd.google-apps.folder') continue;
      if (!relPath.endsWith('.md')) continue;

      final localFile = localMap[relPath];
      if (localFile == null) {
        final content = await driveSync.downloadFile(remoteFile.id!);
        if (content != null) {
          await _ensurePreSyncBackup(driveSync);
          await obsidian.writeFile(relPath, content);
          final hash = driveSync.calculateHash(content);
          await queue.upsertFileSyncState(
            relativePath: relPath,
            localHash: hash,
            remoteHash: hash,
            baseHash: hash,
            remoteFileId: remoteFile.id,
            remoteModifiedAt: remoteFile.modifiedTime,
          );
          debugPrint('Downloaded $relPath from Drive');
        }
        processedCount++;
        _ref.read(syncProgressProvider.notifier).update(processedCount);
      } else {
        // File exists locally, just count it as processed
        processedCount++;
        _ref.read(syncProgressProvider.notifier).update(processedCount);
      }
    }
  }
  
  /// Get only local files modified since last sync
  Future<List<File>> _getModifiedLocalFiles(
    ObsidianService obsidian,
    SyncQueueService queue,
    DateTime? lastSyncTime,
  ) async {
    // If no previous sync, get all files
    if (lastSyncTime == null) {
      return await obsidian.getAllMarkdownFiles();
    }
    
    final allFiles = await obsidian.getAllMarkdownFiles();
    final modifiedFiles = <File>[];
    
    for (final file in allFiles) {
      final relPath = obsidian.getRelativePath(file.path);
      final state = await queue.getFileSyncState(relPath);
      
      // If no sync state, file is new/unsynced
      if (state == null) {
        modifiedFiles.add(file);
        continue;
      }
      
      // Check if file was modified locally since last sync
      final localModifiedAtRaw = state['localModifiedAt'];
      DateTime? localModifiedAt;
      if (localModifiedAtRaw != null) {
        if (localModifiedAtRaw is DateTime) {
          localModifiedAt = localModifiedAtRaw;
        } else if (localModifiedAtRaw is int) {
          localModifiedAt = DateTime.fromMillisecondsSinceEpoch(localModifiedAtRaw);
        }
      }
      final currentModifiedAt = await file.lastModified();
      
      if (localModifiedAt == null || currentModifiedAt.isAfter(localModifiedAt)) {
        modifiedFiles.add(file);
      }
    }
    
    return modifiedFiles;
  }

  Future<bool> _isLocalFileNewer(File localFile, drive.File remoteFile) async {
    final remoteModified = remoteFile.modifiedTime;
    if (remoteModified == null) return false;
    final localModified = await localFile.lastModified();
    return localModified.toUtc().isAfter(remoteModified.toUtc());
  }

  Future<bool> _isRemoteFileNewer(drive.File remoteFile, File localFile) async {
    final remoteModified = remoteFile.modifiedTime;
    if (remoteModified == null) return false;
    final localModified = await localFile.lastModified();
    return remoteModified.toUtc().isAfter(localModified.toUtc());
  }

  Future<void> _ensurePreSyncBackup(GoogleDriveSyncService driveSync) async {
    if (_preSyncBackupCreated) return;
    final backupService = _ref.read(backupServiceProvider);
    final zipFile = await backupService.createBackup();
    if (zipFile != null) {
      await driveSync.createBackupFromFile(zipFile);
    }
    await driveSync.cleanOldRemoteBackups(keepCount: 1);
    _preSyncBackupCreated = true;
  }

  Future<void> _storeConflict({
    required GoogleDriveSyncService driveSync,
    required ObsidianService obsidian,
    required String relativePath,
    required String localContent,
    required String remoteContent,
    DateTime? localModifiedAt,
    DateTime? remoteModifiedAt,
  }) async {
    // If the conflict is in _diagnostics folder, just delete the file instead of creating conflict
    if (relativePath.startsWith('_diagnostics/') || relativePath.contains('/_diagnostics/')) {
      try {
        await obsidian.deleteFile(relativePath);
        debugPrint('Deleted _diagnostics file instead of creating conflict: $relativePath');
        return;
      } catch (e) {
        debugPrint('Failed to delete _diagnostics file: $relativePath, error: $e');
        // Continue with normal conflict handling if deletion fails
      }
    }

    await _ensurePreSyncBackup(driveSync);
    await driveSync.saveConflictPair(
      relativePath: relativePath,
      localContent: localContent,
      remoteContent: remoteContent,
    );

    final detectedAt = DateTime.now();
    final timestamp = detectedAt.millisecondsSinceEpoch;
    final safePath = relativePath.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final localConflictPath = '_conflicts/${_generateSafeFileName(safePath, 'local', timestamp)}.md';
    final remoteConflictPath = '_conflicts/${_generateSafeFileName(safePath, 'remote', timestamp)}.md';
    await obsidian.writeFile(localConflictPath, localContent);
    await obsidian.writeFile(remoteConflictPath, remoteContent);
    
    // Get modification times if not provided
    localModifiedAt ??= await obsidian.getFileModificationTime(relativePath);
    
    await _ref
        .read(syncQueueServiceProvider)
        .upsertConflict(
          relativePath: relativePath,
          localPath: localConflictPath,
          remotePath: remoteConflictPath,
          detectedAt: detectedAt,
          localModifiedAt: localModifiedAt,
          remoteModifiedAt: remoteModifiedAt,
        );

    _syncHadConflict = true;
    _ref
        .read(syncConflictsProvider.notifier)
        .addConflict(
          SyncConflict(
            relativePath: relativePath,
            localPath: localConflictPath,
            remotePath: remoteConflictPath,
            detectedAt: detectedAt,
          ),
        );
    debugPrint('Sync conflict detected for $relativePath');
  }

  String? _guessPathForAction(SyncAction action) {
    if (action.objectType == 'daily_note') {
      return 'daily/${action.objectId}.md';
    }
    
    // Check if the path is explicitly specified in the payload (saved during enqueueAction)
    final payloadPath = action.payload['obsidian_path'] as String?;
    if (payloadPath != null && payloadPath.isNotEmpty) {
      return payloadPath;
    }

    final type = action.objectType;
    final folder = switch (type) {
      'mood_definition' => 'moods',
      'combined_analysis' => 'analyses',
      'goal' => 'goals',
      'task' => 'tasks',
      'habit' => 'habits',
      'tracker_definition' => 'trackers',
      'note' => 'notes',
      'resource' => 'resources',
      'person' => 'organizers/people',
      'project' => 'organizers/projects',
      'area' => 'organizers/areas',
      'activity' => 'organizers/activities',
      'label' => 'organizers/labels',
      'dayTheme' || 'day_theme' => 'organizers/day_themes',
      'timeBlock' || 'time_block' => 'organizers/time_blocks',
      'value' => 'organizers/values',
      'routine' => 'organizers/routines',
      'pillar' => 'pillars',
      'pomodoro_session' => 'pomodoros',
      _ => 'app',
    };
    
    final slug = action.payload['slug'] as String? ?? action.objectId;
    return '$folder/$slug.md';
  }

  Future<String?> _relativePathForAction(SyncAction action) async {
    if (action.objectType == 'daily_note') {
      return 'daily/${action.objectId}.md';
    }
    final allObjects = await _ref.read(allObjectsProvider.future);
    final object = allObjects
        .where((candidate) => candidate.id == action.objectId)
        .firstOrNull;
    if (object != null) return object.obsidianPath;

    // Fallback: check if the path is explicitly specified in the payload
    final payloadPath = action.payload['obsidian_path'] as String?;
    if (payloadPath != null && payloadPath.isNotEmpty) {
      return payloadPath;
    }
    return null;
  }

  Future<void> _refreshNotificationsFromLocalVault() async {
    _ref.invalidate(allObjectsProvider);
    final allObjects = await _ref.read(allObjectsProvider.future);
    final now = DateTime.now();
    for (final object in allObjects.whereType<ContentObject>()) {
      for (final reminder in object.reminders) {
        final triggerTime = reminder.calculateTriggerTime(
          object.baseTime ?? object.createdAt,
        );
        final notificationId = object.id.hashCode ^ reminder.id.hashCode;

        // Schedule future reminders
        if (triggerTime.isAfter(now)) {
          await NotificationService().scheduleReminder(
            id: notificationId,
            title: object.title,
            triggerTime: triggerTime,
            config: reminder,
            payload: object.id,
          );
        }
      }
    }
  }

  String _generateSafeFileName(String basePath, String suffix, int timestamp) {
    const maxFileNameLength = 150; // Safe limit for Android filesystems
    final suffixWithTimestamp = '_${suffix}_$timestamp';
    
    if (basePath.length + suffixWithTimestamp.length <= maxFileNameLength) {
      return '$basePath$suffixWithTimestamp';
    }
    
    // If too long, truncate and add hash for uniqueness
    final availableLength = maxFileNameLength - suffixWithTimestamp.length - 8; // 8 chars for hash
    final truncatedPath = basePath.substring(0, availableLength.clamp(0, basePath.length));
    final hash = basePath.hashCode.toRadixString(16);
    
    return '${truncatedPath}_$hash$suffixWithTimestamp';
  }
}

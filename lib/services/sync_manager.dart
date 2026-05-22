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
import '../models/content_object.dart';
import '../models/task_model.dart';
import '../models/sync_action.dart';
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
  bool _isSyncing = false;

  SyncManager(this._ref);

  void start() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      if (_ref.read(settingsProvider).autoSync) {
        performSync();
      }
    });

    // Initial sync and cleanup
    _runStartupTasks();

    // Watch for external changes
    _setupVaultWatcher();

    // Periodic Backup
    _setupBackupTimer();
  }

  Future<void> _runStartupTasks() async {
    final authService = _ref.read(googleAuthServiceProvider);
    final settings = _ref.read(settingsProvider);

    // 1. Process notification actions
    await _ref.read(vaultProvider.notifier).processPendingNotificationActions();

    // 2. Perform sync if signed in
    if (settings.autoSync && await authService.ensureClient() != null) {
      await performSync();
    }

    // 3. One-off backup shortly after start
    Timer(const Duration(minutes: 5), () async {
      final backupService = _ref.read(backupServiceProvider);
      await backupService.createBackup();
      await backupService.cleanOldBackups();
    });
  }

  void _setupVaultWatcher() {
    final obsidian = _ref.read(obsidianServiceProvider);
    final watchStream = obsidian.watchVault();
    if (watchStream != null) {
      watchStream.listen((event) {
        if (event.path.endsWith('.md')) {
          _ref.invalidate(allObjectsProvider);
          if (event.path.contains('daily')) {
            final dateMatch = RegExp(
              r'(\d{4}-\d{2}-\d{2})',
            ).firstMatch(event.path);
            if (dateMatch != null) {
              final dateStr = dateMatch.group(1)!;
              _ref.invalidate(dailyNoteDataProvider(dateStr));
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
      await backupService.cleanOldBackups();
    });
  }

  void stop() {
    _syncTimer?.cancel();
  }

  Future<void> performSync() async {
    if (_isSyncing) return;

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
    _ref.read(syncStatusProvider.notifier).setStatus(SyncStatus.syncing);

    try {
      await _performSyncWithClient(authClient).timeout(_syncTimeout);
      _ref.read(syncStatusProvider.notifier).setStatus(SyncStatus.synced);
    } catch (e) {
      if (_isAuthError(e)) {
        try {
          final refreshedClient = await authService.ensureClient(
            forceRefresh: true,
          );
          if (refreshedClient != null) {
            await _performSyncWithClient(refreshedClient).timeout(_syncTimeout);
            _ref.read(syncStatusProvider.notifier).setStatus(SyncStatus.synced);
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
    }
  }

  Future<void> _performSyncWithClient(AuthClient authClient) async {
    final driveSync = _ref.read(googleDriveSyncServiceProvider);
    final obsidian = _ref.read(obsidianServiceProvider);
    final queue = _ref.read(syncQueueServiceProvider);

    final settings = _ref.read(settingsProvider);
    driveSync.init(authClient);
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
      await driveSync.syncFile(relativePath, content, localHash);
    });

    // 2. Pull remote changes after local queued edits are safely uploaded.
    debugPrint('[SyncManager] Running full Drive sync.');
    await _runFullSync(driveSync, obsidian);
    debugPrint('[SyncManager] Refreshing local notifications.');
    await _refreshNotificationsFromLocalVault();

    // 3. Regenerate Dataview queries in index.md files in each vault folder
    try {
      debugPrint('[SyncManager] Regenerating Dataview indexes.');
      final gen = DataviewGenerator(obsidian);
      await gen.regenerateAll();
    } catch (e) {
      debugPrint('[SyncManager] Failed to regenerate Dataview during sync: $e');
    }
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
  ) async {
    final remoteFiles = await driveSync.fetchRemoteFiles();
    final localFiles = await obsidian.getAllMarkdownFiles();

    final Map<String, File> localMap = {
      for (var f in localFiles) obsidian.getRelativePath(f.path): f,
    };
    final Map<String, dynamic> remoteMap = {
      for (var f in remoteFiles) f.name!: f,
    };

    // 1. Upload local files that don't exist or are newer remotely
    for (final relPath in localMap.keys) {
      final localFile = localMap[relPath]!;
      final remoteFile = remoteMap[relPath];

      final content = await localFile.readAsString();
      final localHash = driveSync.calculateHash(content);

      if (remoteFile == null) {
        // New local file
        await driveSync.syncFile(relPath, content, localHash);
      } else {
        final remoteHash = remoteFile.appProperties?['citrine_hash'];
        if (remoteHash != null && remoteHash != localHash) {
          await driveSync.syncFile(relPath, content, localHash);
        } else if (remoteHash == null &&
            await _isLocalFileNewer(localFile, remoteFile)) {
          await driveSync.syncFile(relPath, content, localHash);
        }
      }
    }

    // 2. Download remote files that don't exist locally or are newer
    for (final relPath in remoteMap.keys) {
      final remoteFile = remoteMap[relPath] as drive.File;
      if (remoteFile.mimeType == 'application/vnd.google-apps.folder') continue;
      if (!relPath.endsWith('.md')) continue;

      final localFile = localMap[relPath];
      final remoteHash = remoteFile.appProperties?['citrine_hash'];

      bool shouldDownload = false;
      if (localFile == null) {
        shouldDownload = true;
      } else {
        final content = await localFile.readAsString();
        final localHash = driveSync.calculateHash(content);
        if (remoteHash != null && remoteHash != localHash) {
          shouldDownload = true;
        } else if (remoteHash == null &&
            await _isRemoteFileNewer(remoteFile, localFile)) {
          shouldDownload = true;
        }
      }

      if (shouldDownload) {
        final content = await driveSync.downloadFile(remoteFile.id!);
        if (content != null) {
          await obsidian.writeFile(relPath, content);
          debugPrint('Downloaded $relPath from Drive');
        }
      }
    }
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

  String? _guessPathForAction(SyncAction action) {
    if (action.objectType == 'daily_note') {
      return 'daily/${action.objectId}.md';
    }
    // For habits/tasks, if the object is gone from memory,
    // we try to guess based on standard folders
    if (action.objectType == 'habit') return 'habits/${action.objectId}.md';
    if (action.objectType == 'task') return 'tasks/${action.objectId}.md';

    return null;
  }

  Future<String?> _relativePathForAction(SyncAction action) async {
    if (action.objectType == 'daily_note') {
      return 'daily/${action.objectId}.md';
    }
    final allObjects = await _ref.read(allObjectsProvider.future);
    final object = allObjects
        .where((candidate) => candidate.id == action.objectId)
        .firstOrNull;
    return object?.obsidianPath;
  }

  static final Set<int> _notifiedMissedReminders = {};

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
        // Trigger immediately if missed recently (within last 60 mins)
        else if (triggerTime.isBefore(now) &&
            triggerTime.isAfter(now.subtract(const Duration(minutes: 60)))) {
          if (_notifiedMissedReminders.contains(notificationId)) continue;

          // Check if object is already completed
          bool alreadyDone = false;
          if (object is Task && object.stage == TaskStage.finalized) {
            alreadyDone = true;
          }
          // Habit completion check would require reading the daily note specifically,
          // but for now this covers Tasks which are the most common reminders.

          if (alreadyDone) continue;

          _notifiedMissedReminders.add(notificationId);
          await NotificationService().showImmediateNotification(
            id: notificationId,
            title: 'Lembrete Atrasado: ${object.title}',
            body:
                'This should have happened at ${triggerTime.hour}:${triggerTime.minute.toString().padLeft(2, '0')}',
            payload: object.id,
          );
        }
      }
    }
  }
}

import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'obsidian_service.dart';

class BackupService {
  final ObsidianService obsidianService;

  BackupService(this.obsidianService);

  Future<File?> createBackup() async {
    final vaultDir = obsidianService.vaultDir;
    if (vaultDir == null) return null;

    final backupDir = Directory(p.join(vaultDir.path, '_backups'));
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }

    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final backupFile = File(
      p.join(backupDir.path, 'citrine_backup_$timestamp.zip'),
    );

    final encoder = ZipFileEncoder();
    encoder.create(backupFile.path);

    // Add all files from vault recursively
    final files = vaultDir.listSync(recursive: true);
    for (final entity in files) {
      if (entity is File) {
        final relativePath = p.relative(entity.path, from: vaultDir.path);
        // Don't backup existing backups or conflicts
        if (!relativePath.startsWith('_backups') &&
            !relativePath.contains('.zip')) {
          encoder.addFile(entity, relativePath);
        }
      }
    }

    encoder.close();
    await cleanOldBackups();
    return backupFile;
  }

  Future<void> cleanOldBackups({int keepCount = 1}) async {
    final vaultDir = obsidianService.vaultDir;
    if (vaultDir == null) return;
    final backupDir = Directory(p.join(vaultDir.path, '_backups'));
    if (!await backupDir.exists()) return;

    final backups = backupDir.listSync().whereType<File>().toList();
    if (backups.length <= keepCount) return;

    backups.sort(
      (a, b) => a.statSync().modified.compareTo(b.statSync().modified),
    );
    final toDelete = backups.take(backups.length - keepCount);
    for (final file in toDelete) {
      await file.delete();
    }
  }
}

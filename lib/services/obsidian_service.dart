// lib/services/obsidian_service.dart
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:watcher/watcher.dart';

class ObsidianService {
  Directory? vaultDir;
  String? _currentVaultName;

  String get vaultPath => vaultDir?.path ?? '';

  Future<void> initVault(String folderName, {String? customPath}) async {
    final normalizedCustomPath = customPath?.trim() ?? '';
    if (_currentVaultName == folderName &&
        vaultDir != null &&
        (normalizedCustomPath.isEmpty ||
            vaultDir!.path == normalizedCustomPath)) {
      return;
    }

    if (normalizedCustomPath.isNotEmpty) {
      vaultDir = Directory(normalizedCustomPath);
    } else {
      final appDocDir = await getApplicationDocumentsDirectory();
      vaultDir = Directory('${appDocDir.path}/$folderName');
    }
    _currentVaultName = folderName;
    final dir = vaultDir!;
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    await _ensureVaultFolders();
  }

  Future<void> _ensureVaultFolders() async {
    if (vaultDir == null) return;
    const folders = [
      'daily',
      'habits',
      'trackers',
      'tasks',
      'notes',
      'moods',
      'projects',
      'people',
      'organizers/areas',
      'organizers/projects',
      'organizers/activities',
      'organizers/people',
      'organizers/places',
      'organizers/labels',
      'resources',
      'sessions',
      '_attachments',
      '_deleted',
    ];
    // Create all subdirectories in parallel
    await Future.wait(
      folders.map(
        (folder) =>
            Directory('${vaultDir!.path}/$folder').create(recursive: true),
      ),
    );

    // Ensure index.md exists in root
    final indexFile = File('${vaultDir!.path}/index.md');
    if (!await indexFile.exists()) {
      await indexFile.writeAsString(
        '---\ntype: index\n---\n\n'
        '# Citrine Vault\n\n'
        'Welcome to your offline-first personal productivity vault.\n\n'
        '## Day Themes Query\n'
        '```dataview\n'
        'TABLE day_theme FROM "daily" SORT file.name DESC\n'
        '```\n',
      );
    }
  }

  Future<String?> saveAttachment(File sourceFile) async {
    if (vaultDir == null) return null;
    final fileName = sourceFile.path.split(Platform.pathSeparator).last;
    final targetPath = '${vaultDir!.path}/_attachments/$fileName';
    final targetFile = File(targetPath);

    // Handle collisions if needed, for now just overwrite or unique name
    if (await targetFile.exists()) {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final newPath = '${vaultDir!.path}/_attachments/${timestamp}_$fileName';
      await sourceFile.copy(newPath);
      return '_attachments/${timestamp}_$fileName';
    } else {
      await sourceFile.copy(targetPath);
      return '_attachments/$fileName';
    }
  }

  Future<String?> readFile(String relativePath) async {
    if (vaultDir == null) return null;
    final file = File('${vaultDir!.path}/$relativePath');
    if (await file.exists()) {
      return await file.readAsString(encoding: utf8);
    }
    return null;
  }

  Future<void> writeFile(String relativePath, String content) async {
    if (vaultDir == null) return;
    final file = File('${vaultDir!.path}/$relativePath');
    // Ensure parent directory exists
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    await file.writeAsString(content, encoding: utf8);
  }

  Future<List<File>> getFilesInFolder(String folderName) async {
    if (vaultDir == null) return [];
    final dir = Directory('${vaultDir!.path}/$folderName');
    if (!await dir.exists()) return [];

    final files = <File>[];
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        final path = entity.path.replaceAll('\\', '/');
        if (path.contains('/_attachments/') || path.contains('/_deleted/')) {
          continue;
        }
        files.add(entity);
      }
    }
    return files;
  }

  Stream<WatchEvent>? watchVault() {
    if (vaultDir == null) return null;
    return DirectoryWatcher(vaultDir!.path).events;
  }

  Future<void> deleteFile(String relativePath) async {
    if (vaultDir == null) return;
    final file = File('${vaultDir!.path}/$relativePath');
    if (await file.exists()) {
      await file.delete();
    }
  }

  // Phase 1.2 additions
  Future<String?> readFileContent(String folderName, String slug) async {
    return await readFile('$folderName/$slug.md');
  }

  Future<List<File>> getAllMarkdownFiles() async {
    if (vaultDir == null) return [];
    final files = <File>[];
    await for (final entity in vaultDir!.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File && entity.path.endsWith('.md')) {
        final path = entity.path.replaceAll('\\', '/');
        if (path.contains('/_attachments/') || path.contains('/_deleted/')) {
          continue;
        }
        files.add(entity);
      }
    }
    return files;
  }

  String getRelativePath(String absolutePath) {
    if (vaultDir == null) return absolutePath;
    final vaultPath = vaultDir!.path;
    if (absolutePath.startsWith(vaultPath)) {
      var rel = absolutePath.substring(vaultPath.length);
      if (rel.startsWith(Platform.pathSeparator)) {
        rel = rel.substring(1);
      }
      return rel.replaceAll(Platform.pathSeparator, '/');
    }
    return absolutePath;
  }

  Future<File?> getFile(String relativePath) async {
    if (vaultDir == null) return null;
    final file = File('${vaultDir!.path}/$relativePath');
    if (await file.exists()) return file;
    return null;
  }
}

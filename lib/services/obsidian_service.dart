// lib/services/obsidian_service.dart
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:watcher/watcher.dart';
import '../models/content_object.dart';
import 'markdown_parser.dart';

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
      'events',
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
      'social',
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

  Future<bool> fileExists(String relativePath) async {
    if (vaultDir == null) return false;
    return File('${vaultDir!.path}/$relativePath').exists();
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

  Future<void> appendToDailyNote(
    DateTime date,
    String sectionHeading,
    String contentToAppend,
  ) async {
    final dateStr = date.toIso8601String().split('T').first;
    final path = 'daily/$dateStr.md';
    final existing =
        await readFile(path) ??
        '---\ndate: $dateStr\ntags:\n  - daily\n---\n\n# $dateStr\n';
    final frontmatter = MarkdownParser.parseFrontmatter(existing);
    final body = MarkdownParser.extractBody(existing);
    final newBody = _appendToSection(body, sectionHeading, contentToAppend);
    await writeFile(path, generateMarkdown(frontmatter, newBody));
  }

  String _appendToSection(
    String body,
    String sectionHeading,
    String contentToAppend,
  ) {
    final normalizedHeading = sectionHeading.trim();
    final addition = contentToAppend.trim();
    if (addition.isEmpty) return body;

    final lines = body.split('\n');
    final sectionIndex = lines.indexWhere(
      (line) => line.trim() == normalizedHeading,
    );
    if (sectionIndex == -1) {
      return [
        body.trimRight(),
        '',
        normalizedHeading,
        '',
        addition,
        '',
      ].join('\n');
    }

    var insertAt = lines.length;
    for (var i = sectionIndex + 1; i < lines.length; i++) {
      final trimmed = lines[i].trimLeft();
      if (trimmed.startsWith('## ') && !trimmed.startsWith('### ')) {
        insertAt = i;
        break;
      }
    }
    lines.insertAll(insertAt, ['', addition]);
    return lines.join('\n').trimRight();
  }

  Future<List<File>> getFilesInFolder(
    String folderName, {
    bool includeDeleted = false,
  }) async {
    if (vaultDir == null) return [];
    final dir = Directory('${vaultDir!.path}/$folderName');
    if (!await dir.exists()) return [];

    final files = <File>[];
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        final path = entity.path.replaceAll('\\', '/');
        if (path.contains('/_attachments/') ||
            (!includeDeleted && path.contains('/_deleted/'))) {
          continue;
        }
        files.add(entity);
      }
    }
    return files;
  }

  Stream<WatchEvent>? watchVault() {
    if (vaultDir == null) return null;
    if (Platform.isIOS) {
      return PollingDirectoryWatcher(
        vaultDir!.path,
        pollingDelay: const Duration(minutes: 1),
      ).events;
    }
    return DirectoryWatcher(vaultDir!.path).events;
  }

  Future<void> deleteFile(String relativePath) async {
    if (vaultDir == null) return;
    final file = File('${vaultDir!.path}/$relativePath');
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> moveFile(String fromRelativePath, String toRelativePath) async {
    if (vaultDir == null) return;
    final source = File('${vaultDir!.path}/$fromRelativePath');
    if (!await source.exists()) return;

    final target = File('${vaultDir!.path}/$toRelativePath');
    if (!await target.parent.exists()) {
      await target.parent.create(recursive: true);
    }
    if (await target.exists()) {
      await target.delete();
    }
    await source.rename(target.path);
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
        if (path.contains('/_attachments/') || path.contains('/_deleted/') || path.contains('/_conflicts/') || path.contains('/_backups/')) {
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

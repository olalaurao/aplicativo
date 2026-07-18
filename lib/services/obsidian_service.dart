// lib/services/obsidian_service.dart
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:watcher/watcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/content_object.dart';
import '../models/note_model.dart';
import 'markdown_parser.dart';
import 'package:flutter/foundation.dart';

class ObsidianService {
  Directory? vaultDir;
  String? _currentVaultName;

  List<File>? _allMarkdownFilesCache;
  DateTime? _allMarkdownFilesCacheTimestamp;
  final Map<String, MapEntry<List<File>, DateTime>> _folderCache = {};
  static const _cacheValidDuration = Duration(minutes: 5);
  
  // Cache incremental: armazena timestamps de modificação para carregar apenas arquivos alterados
  final Map<String, DateTime> _fileModificationCache = {};
  DateTime? _lastFullScanTime;

  void invalidateFileCache() {
    _allMarkdownFilesCache = null;
    _allMarkdownFilesCacheTimestamp = null;
    _folderCache.clear();
    _fileModificationCache.clear();
    _lastFullScanTime = null;
  }
  
  /// Invalida cache apenas para arquivos específicos (mais eficiente que invalidação total)
  void invalidateFileCacheForPath(String relativePath) {
    _fileModificationCache.remove(relativePath);
    // Se muitos arquivos foram invalidados, limpar cache completamente
    if (_fileModificationCache.length > 1000) {
      _allMarkdownFilesCache = null;
      _allMarkdownFilesCacheTimestamp = null;
      _fileModificationCache.clear();
    }
  }

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
    invalidateFileCache();
    final dir = vaultDir!;
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    await _ensureVaultFolders();
  }

  Future<void> _ensureVaultFolders() async {
    if (vaultDir == null) return;
    const folders = [
      'app',
      'daily',
      'moods',
      'analyses',
      'goals',
      'tasks',
      'habits',
      'trackers',
      'notes',
      'resources',
      'organizers/areas',
      'organizers/projects',
      'organizers/activities',
      'organizers/people',
      'organizers/labels',
      'organizers/day_themes',
      'organizers/time_blocks',
      'organizers/values',
      'organizers/routines',
      'pillars',
      'actions',
      'pomodoros',
      '_attachments',
      '_deleted',
      '_conflicts',
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
        '# Quartzo Vault\n\n'
        'Welcome to your offline-first personal productivity vault.\n\n'
        '## Day Themes Query\n'
        '```dataview\n'
        'TABLE day_theme FROM "daily" SORT file.name DESC\n'
        '```\n',
        encoding: utf8,
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
    // Otimização: invalidar apenas o arquivo específico em vez de todo o cache
    invalidateFileCacheForPath(relativePath);
  }

  Future<void> syncCollectionToBase(Note note) async {
    if (vaultDir == null || note.subtype != NoteSubtype.collection) return;

    try {
      final decoded = jsonDecode(note.body);
      if (decoded is! Map) return;

      final schema =
          (decoded['schema'] as List?)
              ?.whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          [];
      final items =
          (decoded['items'] as List?)
              ?.whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          [];
      if (schema.isEmpty) return;

      final collectionSlug = note.slug.isNotEmpty ? note.slug : note.id;
      final itemFileNames = <String>{};
      final collectionDir = Directory('${vaultDir!.path}/$collectionSlug');
      if (!await collectionDir.exists()) {
        await collectionDir.create(recursive: true);
      }

      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        final rawId = item['id']?.toString().trim();
        final itemId = _safeFileStem(
          rawId == null || rawId.isEmpty ? 'item_${i + 1}' : rawId,
        );
        final fileName = '$itemId.md';
        itemFileNames.add(fileName);

        final frontmatter = <String, dynamic>{
          'title': _collectionItemTitle(schema, item, note.title),
          'collection_ref': '[[${note.slug}]]',
        };
        var body = '';

        for (final prop in schema) {
          final propId = prop['id']?.toString();
          if (propId == null || propId.isEmpty) continue;

          final propName = prop['name']?.toString().trim();
          final key = _propertyKey(
            propName == null || propName.isEmpty ? propId : propName,
          );
          final value = item[propId];
          final propType = prop['type']?.toString();

          if (propType == 'richText' && value != null) {
            body = value.toString();
          }
          if (value == null || value == '') continue;
          frontmatter[key] = value;
        }

        await writeFile(
          '$collectionSlug/$fileName',
          generateMarkdown(frontmatter, body),
        );
      }

      try {
        // Use listSync for faster file deletion
        final entities = collectionDir.listSync(followLinks: false);
        for (final entity in entities) {
          if (entity is! File || !entity.path.endsWith('.md')) continue;
          final fileName = entity.path.replaceAll('\\', '/').split('/').last;
          if (!itemFileNames.contains(fileName)) {
            await entity.delete();
          }
        }
      } catch (e) {
        debugPrint('Error listing collection dir for cleanup: $e');
        // Fallback to async
        await for (final entity in collectionDir.list(followLinks: false)) {
          if (entity is! File || !entity.path.endsWith('.md')) continue;
          final fileName = entity.path.replaceAll('\\', '/').split('/').last;
          if (!itemFileNames.contains(fileName)) {
            await entity.delete();
          }
        }
      }

      await writeFile(
        '$collectionSlug.base',
        generateMarkdown({
          'filters': [],
          'order': [],
          'properties': schema.map((prop) {
            final name = prop['name']?.toString().trim();
            return {
              'name': name == null || name.isEmpty
                  ? prop['id']?.toString() ?? 'Property'
                  : name,
              'type': _baseTypeForCollectionProperty(prop['type']?.toString()),
            };
          }).toList(),
          'source': {'type': 'folder', 'path': '$collectionSlug/'},
        }, ''),
      );
    } catch (e, st) {
      debugPrint('Collection base sync failed for ${note.id}: $e\n$st');
    }
  }

  String _collectionItemTitle(
    List<Map<String, dynamic>> schema,
    Map<String, dynamic> item,
    String fallback,
  ) {
    for (final prop in schema) {
      final type = prop['type']?.toString();
      if (type != 'text' && type != 'richText') continue;
      final propId = prop['id']?.toString();
      final value = propId == null ? null : item[propId];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return fallback;
  }

  String _baseTypeForCollectionProperty(String? type) {
    switch (type) {
      case 'quantity':
      case 'rating':
      case 'duration':
        return 'number';
      case 'date':
        return 'date';
      case 'selection':
        return 'select';
      case 'multiSelection':
        return 'multiselect';
      case 'checkbox':
        return 'checkbox';
      case 'text':
      case 'richText':
      case 'url':
      case 'email':
      case 'phone':
      case 'time':
      case 'relation':
      case 'media':
      default:
        return 'text';
    }
  }

  String _propertyKey(String value) {
    final key = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return key.isEmpty ? 'property' : key;
  }

  String _safeFileStem(String value) {
    final stem = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_-]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return stem.isEmpty ? 'item' : stem;
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
    bool forceRefresh = false,
  }) async {
    final now = DateTime.now();
    final cacheKey = '${folderName}_$includeDeleted';
    if (!forceRefresh &&
        _folderCache.containsKey(cacheKey) &&
        now.difference(_folderCache[cacheKey]!.value) < _cacheValidDuration) {
      return _folderCache[cacheKey]!.key;
    }

    if (vaultDir == null) return [];
    final dir = Directory('${vaultDir!.path}/$folderName');
    if (!await dir.exists()) return [];

    final files = <File>[];
    try {
      // Use listSync for faster directory scanning
      final entities = dir.listSync(
        recursive: true,
        followLinks: false,
      );
      
      for (final entity in entities) {
        if (entity is File && entity.path.endsWith('.md')) {
          final path = entity.path.replaceAll('\\', '/');
          if (path.contains('/_attachments/') ||
              path.contains('/_diagnostics/') ||
              path.contains('/crash_reports/') ||
              path.contains('/_cache/') ||
              (!includeDeleted && path.contains('/_deleted/'))) {
            continue;
          }
          // Filter out timestamped backup files (e.g., 2026-07-14_23-49-18_226_filename.md)
          final fileName = path.split('/').last;
          if (RegExp(r'^\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}_').hasMatch(fileName)) {
            continue;
          }
          files.add(entity);
        }
      }
    } catch (e) {
      debugPrint('Error scanning folder $folderName with listSync: $e');
      // Fallback to async if sync fails
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File && entity.path.endsWith('.md')) {
          final path = entity.path.replaceAll('\\', '/');
          if (path.contains('/_attachments/') ||
              path.contains('/_diagnostics/') ||
              path.contains('/crash_reports/') ||
              path.contains('/_cache/') ||
              (!includeDeleted && path.contains('/_deleted/'))) {
            continue;
          }
          final fileName = path.split('/').last;
          if (RegExp(r'^\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}_').hasMatch(fileName)) {
            continue;
          }
          files.add(entity);
        }
      }
    }
    _folderCache[cacheKey] = MapEntry(files, now);
    return files;
  }

  Stream<List<WatchEvent>>? watchVaultDebounced({
    Duration debounce = const Duration(milliseconds: 800),
  }) {
    if (vaultDir == null) return null;
    final rawStream = Platform.isIOS
        ? PollingDirectoryWatcher(
            vaultDir!.path,
            pollingDelay: const Duration(minutes: 1),
          ).events
        : DirectoryWatcher(vaultDir!.path).events;

    StreamController<List<WatchEvent>>? controller;
    Timer? timer;
    final List<WatchEvent> buffer = [];

    controller = StreamController<List<WatchEvent>>(
      onListen: () {
        final subscription = rawStream.listen((event) {
          final path = event.path.replaceAll('\\', '/');
          if (path.contains('/_attachments/') ||
              path.contains('/_deleted/') ||
              path.contains('/_backups/') ||
              path.contains('/_cache/')) {
            return;
          }
          buffer.add(event);
          timer?.cancel();
          timer = Timer(debounce, () {
            if (buffer.isNotEmpty) {
              controller?.add(List.from(buffer));
              buffer.clear();
            }
          });
        });
        controller!.onCancel = () {
          subscription.cancel();
          timer?.cancel();
        };
      },
    );

    return controller.stream;
  }

  @Deprecated('Use watchVaultDebounced() to avoid reload storms during sync.')
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
    // Otimização: invalidar apenas o arquivo específico
    invalidateFileCacheForPath(relativePath);
  }

  Future<DateTime?> getFileModificationTime(String relativePath) async {
    if (vaultDir == null) return null;
    final file = File('${vaultDir!.path}/$relativePath');
    if (await file.exists()) {
      return await file.lastModified();
    }
    return null;
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
    // Otimização: invalidar apenas os arquivos específicos
    invalidateFileCacheForPath(fromRelativePath);
    invalidateFileCacheForPath(toRelativePath);
  }

  // Phase 1.2 additions
  Future<String?> readFileContent(String folderName, String slug) async {
    return await readFile('$folderName/$slug.md');
  }

  Future<List<File>> getAllMarkdownFiles({bool forceRefresh = false}) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _allMarkdownFilesCache != null &&
        _allMarkdownFilesCacheTimestamp != null &&
        now.difference(_allMarkdownFilesCacheTimestamp!) <
            _cacheValidDuration) {
      return _allMarkdownFilesCache!;
    }
    if (vaultDir == null) return [];
    
    // Otimização: usar listSync para scan mais rápido em vez de await for
    final files = <File>[];
    try {
      final entities = vaultDir!.listSync(
        recursive: true,
        followLinks: false,
      );
      
      for (final entity in entities) {
        if (entity is File && entity.path.endsWith('.md')) {
          final path = entity.path.replaceAll('\\', '/');
          if (path.contains('/_attachments/') ||
              path.contains('/_deleted/') ||
              path.contains('/_conflicts/') ||
              path.contains('/_backups/') ||
              path.contains('/_cache/')) {
            continue;
          }
          files.add(entity);
        }
      }
    } catch (e) {
      debugPrint('Error scanning vault directory: $e');
      // Fallback para método async se sync falhar
      await for (final entity in vaultDir!.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File && entity.path.endsWith('.md')) {
          final path = entity.path.replaceAll('\\', '/');
          if (path.contains('/_attachments/') ||
              path.contains('/_deleted/') ||
              path.contains('/_conflicts/') ||
              path.contains('/_backups/') ||
              path.contains('/_cache/')) {
            continue;
          }
          files.add(entity);
        }
      }
    }
    
    _allMarkdownFilesCache = files;
    _allMarkdownFilesCacheTimestamp = now;
    _lastFullScanTime = now;
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

  Future<void> fixEntryTypeMigration() async {
    if (vaultDir == null) return;
    final files = await getAllMarkdownFiles();
    for (final file in files) {
      try {
        final content = await file.readAsString(encoding: utf8);
        final frontmatter = MarkdownParser.parseFrontmatter(content);
        final type = frontmatter['type']?.toString();
        if (type == 'journal_entry' || type == 'entry') {
          var changed = false;
          if (type == 'journal_entry') {
            frontmatter['type'] = 'entry';
            changed = true;
          }
          final entryType = frontmatter['entry_type']?.toString();
          if (entryType != null && entryType.startsWith('_')) {
            frontmatter['entry_type'] = entryType.substring(1);
            changed = true;
          }
          if (changed) {
            final body = MarkdownParser.extractBody(content);
            await file.writeAsString(
              generateMarkdown(frontmatter, body),
              encoding: utf8,
            );
            debugPrint('Migrated journal entry file: ${file.path}');
          }
        }
      } catch (e) {
        debugPrint('Error migrating file ${file.path}: $e');
      }
    }
  }

  Future<void> migrateDailyHabitCompletions(SharedPreferences prefs) async {
    if (vaultDir == null) return;
    const migrationKey = 'daily_note_habits_migration_done';
    if (prefs.getBool(migrationKey) == true) return;

    final files = await getAllMarkdownFiles();
    for (final file in files) {
      final relativePath = getRelativePath(file.path);
      final isDailyFile =
          relativePath == 'daily' ||
          relativePath.startsWith('daily/') ||
          relativePath.contains('/daily/');
      if (!isDailyFile || !relativePath.endsWith('.md')) {
        continue;
      }

      try {
        final content = await file.readAsString(encoding: utf8);
        final frontmatter = MarkdownParser.parseFrontmatter(content);
        if (frontmatter['habits'] is Map) {
          final habitData = Map<String, dynamic>.from(
            frontmatter['habits'] as Map,
          );
          for (final entry in habitData.entries) {
            frontmatter[entry.key] = entry.value;
          }
          frontmatter.remove('habits');
          final body = MarkdownParser.extractBody(content);
          await file.writeAsString(
            generateMarkdown(frontmatter, body),
            encoding: utf8,
          );
          debugPrint('Migrated daily habits file: ${file.path}');
        }
      } catch (e) {
        debugPrint('Error migrating daily habits file ${file.path}: $e');
      }
    }

    await prefs.setBool(migrationKey, true);
  }

  Future<List<File>> searchRawMarkdownFiles(Set<String> searchKeys) async {
    final files = await getAllMarkdownFiles();
    final results = <File>[];
    for (final file in files) {
      try {
        final content = await file.readAsString(encoding: utf8);
        final lowerContent = content.toLowerCase();
        if (searchKeys.any((key) =>
            lowerContent.contains('[[$key]]') ||
            lowerContent.contains('[[$key|') ||
            lowerContent.contains('[[moods/$key]]') ||
            lowerContent.contains('[[moods/$key|'))) {
          results.add(file);
        }
      } catch (e) {
        debugPrint('Error reading file for search ${file.path}: $e');
      }
    }
    return results;
  }
}

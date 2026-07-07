import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/googleapis_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'dart:io';
import 'dart:convert';
import 'markdown_parser.dart';

class GoogleDriveSyncService {
  drive.DriveApi? _driveApi;
  String? _vaultFolderId;
  String? get vaultFolderId => _vaultFolderId;
  final Map<String, String> _folderIdCache = {};

  void init(AuthClient client) {
    _driveApi = drive.DriveApi(client);
  }

  String _queryStringLiteral(String value) {
    return value.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
  }

  Future<void> setupVaultFolder(String folderName) async {
    if (_driveApi == null) throw Exception('Drive API not initialized');

    final query =
        "mimeType='application/vnd.google-apps.folder' and name='${_queryStringLiteral(folderName)}' and trashed=false";
    final fileList = await _driveApi!.files.list(
      q: query,
      spaces: 'drive',
      includeItemsFromAllDrives: true,
      supportsAllDrives: true,
    );

    if (fileList.files != null && fileList.files!.isNotEmpty) {
      _vaultFolderId = fileList.files!.first.id;
    } else {
      final folder = drive.File()
        ..name = folderName
        ..mimeType = 'application/vnd.google-apps.folder';
      final created = await _driveApi!.files.create(
        folder,
        supportsAllDrives: true,
      );
      _vaultFolderId = created.id;
    }
  }

  Future<void> useExistingVaultFolder(String folderId) async {
    if (_driveApi == null) throw Exception('Drive API not initialized');
    final folder =
        await _driveApi!.files.get(
              folderId,
              supportsAllDrives: true,
              $fields: 'id, name, mimeType, trashed',
            )
            as drive.File;
    if (folder.mimeType != 'application/vnd.google-apps.folder' ||
        folder.trashed == true) {
      throw Exception('The selected Google Drive folder is not valid.');
    }
    _vaultFolderId = folder.id;
    _folderIdCache.clear();
  }

  Future<String> _getOrCreateFolder(String path) async {
    if (_vaultFolderId == null) throw Exception('Vault folder not initialized');
    if (_folderIdCache.containsKey(path)) return _folderIdCache[path]!;

    final parts = path.split('/').where((p) => p.isNotEmpty).toList();
    String currentParentId = _vaultFolderId!;
    String currentPath = "";

    for (final part in parts) {
      currentPath += "/$part";
      if (_folderIdCache.containsKey(currentPath)) {
        currentParentId = _folderIdCache[currentPath]!;
        continue;
      }

      final query =
          "mimeType='application/vnd.google-apps.folder' and name='${_queryStringLiteral(part)}' and '${_queryStringLiteral(currentParentId)}' in parents and trashed=false";
      final fileList = await _driveApi!.files.list(
        q: query,
        spaces: 'drive',
        includeItemsFromAllDrives: true,
        supportsAllDrives: true,
      );

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        currentParentId = fileList.files!.first.id!;
      } else {
        final folder = drive.File()
          ..name = part
          ..parents = [currentParentId]
          ..mimeType = 'application/vnd.google-apps.folder';
        final created = await _driveApi!.files.create(
          folder,
          supportsAllDrives: true,
        );
        currentParentId = created.id!;
      }
      _folderIdCache[currentPath] = currentParentId;
    }
    return currentParentId;
  }

  Future<bool> syncFile(
    String relativePath,
    String content,
    String localHash, {
    String? baseHash,
  }) async {
    if (_driveApi == null || _vaultFolderId == null) {
      throw Exception('Drive API not initialized');
    }

    final pathParts = relativePath.split('/');
    final fileName = pathParts.last;
    final folderPath = pathParts.sublist(0, pathParts.length - 1).join('/');

    final parentId = folderPath.isEmpty
        ? _vaultFolderId!
        : await _getOrCreateFolder(folderPath);

    // 1. Check if file exists and its remote hash
    final query =
        "name='${_queryStringLiteral(fileName)}' and '${_queryStringLiteral(parentId)}' in parents and trashed=false";
    final fileList = await _driveApi!.files.list(
      q: query,
      spaces: 'drive',
      includeItemsFromAllDrives: true,
      supportsAllDrives: true,
      $fields: 'files(id, name, appProperties, md5Checksum)',
    );

    final contentBytes = utf8.encode(content);
    final media = drive.Media(Stream.value(contentBytes), contentBytes.length);

    if (fileList.files != null && fileList.files!.isNotEmpty) {
      final remoteFile = fileList.files!.first;
      final remoteId = remoteFile.id!;
      final remoteHash = remoteFile.appProperties?['Quartzo_hash'];

      // Conflict Resolution:
      // If remoteHash exists and is different from our baseHash, someone else modified it.
      if (baseHash != null && remoteHash != null && remoteHash != baseHash) {
        await _handleConflict(relativePath, content, remoteId, fileName);
        return false; // Stop sync for this file, let user resolve
      }

      final updateFile = drive.File()
        ..name = fileName
        ..appProperties = {'Quartzo_hash': localHash};

      await _driveApi!.files.update(
        updateFile,
        remoteId,
        uploadMedia: media,
        supportsAllDrives: true,
      );
      return true;
    } else {
      // Create new file
      final newFile = drive.File()
        ..name = fileName
        ..parents = [parentId]
        ..appProperties = {'Quartzo_hash': localHash};

      await _driveApi!.files.create(
        newFile,
        uploadMedia: media,
        supportsAllDrives: true,
      );
      return true;
    }
  }

  Future<void> _handleConflict(
    String relativePath,
    String localContent,
    String remoteId,
    String fileName,
  ) async {
    // 1. Download remote content
    final response =
        await _driveApi!.files.get(
              remoteId,
              downloadOptions: drive.DownloadOptions.fullMedia,
              supportsAllDrives: true,
            )
            as drive.Media;
    final remoteBytes = await response.stream.fold<List<int>>(
      [],
      (p, e) => p..addAll(e),
    );
    final remoteContent = utf8.decode(remoteBytes);

    // 2. Attempt Simple Merge for Frontmatter
    final localFM = MarkdownParser.parseFrontmatter(localContent);
    final remoteFM = MarkdownParser.parseFrontmatter(remoteContent);
    final localBody = MarkdownParser.extractBody(localContent);
    final remoteBody = MarkdownParser.extractBody(remoteContent);

    final mergedFM = MarkdownParser.mergeFrontmatter(localFM, remoteFM);

    // For body, if it's a daily note, we can try to merge sections
    String mergedBody = localBody;
    final isDailyPath =
        relativePath == 'daily' ||
        relativePath.startsWith('daily/') ||
        relativePath.contains('/daily/');
    if (localFM['type'] == 'daily_note' || isDailyPath) {
      // Very naive body merge: if remote has things local doesn't, append them?
      // Better: just keep both in different files if body differs significantly.
      if (localBody != remoteBody) {
        mergedBody = "$localBody\n\n--- REMOTE CONTENT ---\n\n$remoteBody";
      }
    } else {
      if (localBody != remoteBody) {
        // Not a daily note, and bodies differ. Fallback to conflict files.
        await _saveConflictFiles(
          relativePath,
          localContent,
          remoteContent,
          fileName,
        );
        return;
      }
    }

    // 3. Upload merged version
    final mergedContent =
        "---\n${mergedFM.entries.map((e) => "${e.key}: ${e.value}").join('\n')}\n---\n\n$mergedBody";
    final mergedBytes = utf8.encode(mergedContent);
    final media = drive.Media(Stream.value(mergedBytes), mergedBytes.length);
    final updateFile = drive.File()
      ..name = fileName
      ..appProperties = {'Quartzo_hash': calculateHash(mergedContent)};

    await _driveApi!.files.update(
      updateFile,
      remoteId,
      uploadMedia: media,
      supportsAllDrives: true,
    );
    debugPrint('Conflict resolved via merge for $relativePath');
  }

  Future<void> _saveConflictFiles(
    String relativePath,
    String localContent,
    String remoteContent,
    String fileName,
  ) async {
    final conflictsFolderId = await _getOrCreateFolder('_conflicts');
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    final localConflictFile = drive.File()
      ..name = '${fileName}_local_$timestamp.md'
      ..parents = [conflictsFolderId];
    final localBytes = utf8.encode(localContent);
    await _driveApi!.files.create(
      localConflictFile,
      uploadMedia: drive.Media(Stream.value(localBytes), localBytes.length),
      supportsAllDrives: true,
    );

    final remoteConflictFile = drive.File()
      ..name = '${fileName}_remote_$timestamp.md'
      ..parents = [conflictsFolderId];
    final remoteBytes = utf8.encode(remoteContent);
    await _driveApi!.files.create(
      remoteConflictFile,
      uploadMedia: drive.Media(Stream.value(remoteBytes), remoteBytes.length),
      supportsAllDrives: true,
    );

    debugPrint('Conflict detected and saved to _conflicts for $relativePath');
  }

  Future<void> saveConflictPair({
    required String relativePath,
    required String localContent,
    required String remoteContent,
  }) async {
    if (_driveApi == null || _vaultFolderId == null) {
      throw Exception('Drive API not initialized');
    }
    final fileName = relativePath.split('/').last;
    await _saveConflictFiles(
      relativePath,
      localContent,
      remoteContent,
      fileName,
    );
  }

  Future<void> deleteFile(String relativePath, String fileId) async {
    if (_driveApi == null) return;

    // 1. Ensure _deleted folder exists
    final deletedFolderId = await _getOrCreateFolder('_deleted');

    // 2. Move file to _deleted instead of trashing immediately
    // In Google Drive V3, moving is done by updating 'parents'
    final file =
        await _driveApi!.files.get(
              fileId,
              supportsAllDrives: true,
              $fields: 'parents',
            )
            as drive.File;
    final previousParents = file.parents?.join(',') ?? '';

    await _driveApi!.files.update(
      drive.File(),
      fileId,
      addParents: deletedFolderId,
      removeParents: previousParents,
      supportsAllDrives: true,
    );
  }

  Future<void> createBackup(List<File> files, {String? rootPath}) async {
    final archive = Archive();

    for (final file in files) {
      final bytes = await file.readAsBytes();
      String path = file.path;
      if (rootPath != null && path.startsWith(rootPath)) {
        path = path.substring(rootPath.length);
        if (path.startsWith(Platform.pathSeparator)) {
          path = path.substring(1);
        }
      }
      archive.addFile(ArchiveFile(path, bytes.length, bytes));
    }

    final zipEncoder = ZipEncoder();
    final zipData = zipEncoder.encode(archive);
    if (zipData == null) return;

    final backupsFolderId = await _getOrCreateFolder('_backups');
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final media = drive.Media(Stream.value(zipData), zipData.length);

    final driveFile = drive.File()
      ..name = 'backup_$timestamp.zip'
      ..parents = [backupsFolderId];

    await _driveApi!.files.create(
      driveFile,
      uploadMedia: media,
      supportsAllDrives: true,
    );
    await cleanOldRemoteBackups(keepCount: 1);
  }

  Future<void> createBackupFromFile(File zipFile) async {
    if (_driveApi == null) throw Exception('Drive API not initialized');

    final backupsFolderId = await _getOrCreateFolder('_backups');
    final fileName = zipFile.path.split(Platform.pathSeparator).last;
    final media = drive.Media(zipFile.openRead(), await zipFile.length());

    final driveFile = drive.File()
      ..name = fileName
      ..parents = [backupsFolderId];

    await _driveApi!.files.create(
      driveFile,
      uploadMedia: media,
      supportsAllDrives: true,
    );
    await cleanOldRemoteBackups(keepCount: 1);
  }

  Future<void> cleanOldRemoteBackups({int keepCount = 1}) async {
    if (_driveApi == null || _vaultFolderId == null) return;

    final backupsFolderId = await _getOrCreateFolder('_backups');
    final fileList = await _driveApi!.files.list(
      q: "'${_queryStringLiteral(backupsFolderId)}' in parents and trashed=false",
      spaces: 'drive',
      includeItemsFromAllDrives: true,
      supportsAllDrives: true,
      orderBy: 'modifiedTime desc',
      $fields: 'files(id, name, modifiedTime)',
    );

    final backups = (fileList.files ?? <drive.File>[])
        .where((file) => (file.name ?? '').endsWith('.zip'))
        .toList();
    if (backups.length <= keepCount) return;

    for (final backup in backups.skip(keepCount)) {
      final id = backup.id;
      if (id == null) continue;
      await _driveApi!.files.delete(id, supportsAllDrives: true);
    }
  }

  Future<List<drive.File>> fetchRemoteFiles() async {
    if (_driveApi == null || _vaultFolderId == null) return [];

    final files = <drive.File>[];
    await _fetchRemoteFilesRecursive(
      parentId: _vaultFolderId!,
      relativeFolder: '',
      results: files,
    );
    return files;
  }

  Future<void> _fetchRemoteFilesRecursive({
    required String parentId,
    required String relativeFolder,
    required List<drive.File> results,
  }) async {
    String? pageToken;
    do {
      final fileList = await _driveApi!.files.list(
        q: "'${_queryStringLiteral(parentId)}' in parents and trashed=false",
        spaces: 'drive',
        pageToken: pageToken,
        includeItemsFromAllDrives: true,
        supportsAllDrives: true,
        $fields:
            'nextPageToken, files(id, name, mimeType, appProperties, modifiedTime)',
      );

      for (final item in fileList.files ?? <drive.File>[]) {
        final name = item.name ?? '';
        if (name.isEmpty) continue;

        final relativePath = relativeFolder.isEmpty
            ? name
            : '$relativeFolder/$name';
        final isFolder = item.mimeType == 'application/vnd.google-apps.folder';

        if (isFolder) {
          if (_shouldSkipRemoteFolder(name)) continue;
          final folderId = item.id;
          if (folderId == null) continue;
          await _fetchRemoteFilesRecursive(
            parentId: folderId,
            relativeFolder: relativePath,
            results: results,
          );
        } else {
          item.name = relativePath;
          results.add(item);
        }
      }

      pageToken = fileList.nextPageToken;
    } while (pageToken != null);
  }

  bool _shouldSkipRemoteFolder(String name) {
    return name == '_attachments' ||
        name == '_conflicts' ||
        name == '_deleted' ||
        name == '_backups';
  }

  String calculateHash(String content) {
    return sha256.convert(utf8.encode(content)).toString();
  }

  Future<String?> downloadFile(String fileId) async {
    if (_driveApi == null) return null;
    try {
      final drive.Media response =
          await _driveApi!.files.get(
                fileId,
                downloadOptions: drive.DownloadOptions.fullMedia,
                supportsAllDrives: true,
              )
              as drive.Media;
      final bytes = await response.stream.fold<List<int>>(
        [],
        (p, e) => p..addAll(e),
      );
      return utf8.decode(bytes);
    } catch (e) {
      debugPrint('Error downloading file $fileId: $e');
      return null;
    }
  }

  Future<List<drive.File>> listFolders({String? parentId}) async {
    if (_driveApi == null) return [];

    String query =
        "mimeType='application/vnd.google-apps.folder' and trashed=false";
    if (parentId != null) {
      query += " and '${_queryStringLiteral(parentId)}' in parents";
    } else {
      query += " and 'root' in parents";
    }

    final fileList = await _driveApi!.files.list(
      q: query,
      spaces: 'drive',
      includeItemsFromAllDrives: true,
      supportsAllDrives: true,
      orderBy: 'folder,name',
      $fields: 'files(id, name, parents)',
    );

    return fileList.files ?? [];
  }

  Future<List<drive.File>> listSharedFolders() async {
    if (_driveApi == null) return [];
    final fileList = await _driveApi!.files.list(
      q: "mimeType='application/vnd.google-apps.folder' and sharedWithMe and trashed=false",
      spaces: 'drive',
      includeItemsFromAllDrives: true,
      supportsAllDrives: true,
      orderBy: 'folder,name',
      $fields: 'files(id, name, parents)',
    );
    return fileList.files ?? [];
  }
}

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class VaultCacheEntry {
  final int mtime;
  final String type;
  final Map<String, dynamic> frontmatter;
  final String body;

  VaultCacheEntry({
    required this.mtime,
    required this.type,
    required this.frontmatter,
    required this.body,
  });

  Map<String, dynamic> toJson() => {
        'mtime': mtime,
        'type': type,
        'frontmatter': frontmatter,
        'body': body,
      };

  factory VaultCacheEntry.fromJson(Map<String, dynamic> json) {
    return VaultCacheEntry(
      mtime: json['mtime'] as int,
      type: json['type'] as String,
      frontmatter: json['frontmatter'] as Map<String, dynamic>? ?? {},
      body: json['body'] as String? ?? '',
    );
  }
}

class VaultCacheService {
  static const _cacheFileName = 'vault_index.json';

  static File _getCacheFile(String vaultPath, String cacheDirectoryPath) {
    // Use a hash of the vault path to support multiple vaults if needed
    final vaultHash = vaultPath.hashCode.abs();
    final cacheDir = Directory('$cacheDirectoryPath/vault_cache_$vaultHash');
    if (!cacheDir.existsSync()) {
      cacheDir.createSync(recursive: true);
    }
    return File('${cacheDir.path}/$_cacheFileName');
  }

  /// Loads the cache from disk synchronously. Returns an empty map if it doesn't exist or is corrupted.
  static Map<String, VaultCacheEntry> load(String vaultPath, String cacheDirectoryPath) {
    try {
      final file = _getCacheFile(vaultPath, cacheDirectoryPath);
      if (!file.existsSync()) {
        return {};
      }
      
      final contents = file.readAsStringSync();
      final decoded = jsonDecode(contents) as Map<String, dynamic>;
      
      return decoded.map((key, value) => MapEntry(
        key,
        VaultCacheEntry.fromJson(value as Map<String, dynamic>),
      ));
    } catch (e) {
      debugPrint('Failed to load vault cache: $e');
      return {};
    }
  }

  /// Saves the cache back to disk synchronously.
  static void save(String vaultPath, String cacheDirectoryPath, Map<String, VaultCacheEntry> cache) {
    try {
      final file = _getCacheFile(vaultPath, cacheDirectoryPath);
      final tempFile = File('${file.path}.tmp');
      
      final encoded = jsonEncode(
        cache.map((key, value) => MapEntry(key, value.toJson())),
      );
      
      tempFile.writeAsStringSync(encoded, flush: true);
      tempFile.renameSync(file.path);
    } catch (e) {
      debugPrint('Failed to save vault cache: $e');
    }
  }
}

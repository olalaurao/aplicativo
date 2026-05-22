// lib/services/moc_service.dart
import 'obsidian_service.dart';

class MocService {
  static Future<void> updateMoc(
    ObsidianService obsidianService,
    String folder,
  ) async {
    final files = await obsidianService.getFilesInFolder(folder);

    final mocPath = '$folder/index.md';
    final buffer = StringBuffer();
    buffer.writeln('---');
    buffer.writeln('type: moc');
    buffer.writeln('folder: $folder');
    buffer.writeln('updated: ${DateTime.now().toIso8601String()}');
    buffer.writeln('---');
    buffer.writeln('\n# Map of Content: ${folder.toUpperCase()}\n');

    // Sort files by name
    files.sort((a, b) => a.path.compareTo(b.path));

    for (final file in files) {
      if (file.path.endsWith('.md') && !file.path.endsWith('index.md')) {
        final fileName = file.path.split('/').last.replaceAll('.md', '');
        buffer.writeln('- [[$fileName]]');
      }
    }

    await obsidianService.writeFile(mocPath, buffer.toString());
  }
}

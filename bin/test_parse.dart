import 'dart:io';
import 'package:yaml/yaml.dart';

void main() {
  final dir = Directory('vault');
  if (!dir.existsSync()) {
    stdout.writeln('Vault not found.');
    return;
  }

  final files = dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.md'));

  for (final file in files) {
    try {
      final content = file.readAsStringSync();
      final yamlMatch = RegExp(
        r'^---\n(.*?)\n---\n',
        dotAll: true,
      ).firstMatch(content);
      if (yamlMatch != null) {
        final yamlStr = yamlMatch.group(1)!;
        final doc = loadYaml(yamlStr);
        if (doc is YamlMap) {
          final frontmatter = doc.cast<String, dynamic>();
          // Let's print out anything that might be incorrectly typed
          frontmatter.forEach((k, v) {
            if (v is YamlList &&
                k != 'tags' &&
                k != 'organizers' &&
                k != 'reminder_minutes_before') {
              stdout.writeln(
                'Warning: List found for key "$k" in ${file.path}: $v',
              );
            }
          });
        }
      }
    } catch (e) {
      stdout.writeln('Error reading ${file.path}: $e');
    }
  }
  stdout.writeln('Done parsing.');
}

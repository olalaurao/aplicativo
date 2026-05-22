import 'dart:io';

void main() {
  final file = File('lib/ui/screens/home_screen.dart');
  final lines = file.readAsLinesSync();
  // Remove lines 327 to 339 (inclusive, 0-indexed: 327 is index 326, 339 is index 338. Wait, if I want to remove line 328 to 340 it's index 327 to 339).
  // Actually, wait, let's just find the indexes programmatically.
  final newLines = <String>[];
  int i = 0;
  while (i < lines.length) {
    if (lines[i].contains("'ConteÃƒÂºdo': [") || lines[i].contains("'Conteúdo': [") || lines[i].contains("'ConteÃºdo': [")) {
      // Find the next two occurrences and remove the first two
      break;
    }
    newLines.add(lines[i]);
    i++;
  }
  
  // Just manual index removal since we know the lines
  final file2 = File('lib/ui/screens/home_screen.dart');
  final lines2 = file2.readAsLinesSync();
  final out = [...lines2.sublist(0, 327), ...lines2.sublist(340)];
  file2.writeAsStringSync(out.join('\n'));
}



import '../models/note_model.dart';
import '../providers/vault_provider.dart';

class CollectionRow {
  final String noteSlug;
  final String? blockId;
  final int lineIndex;
  final String rawText;
  final String displayTitle;
  final String? subtitle;

  const CollectionRow({
    required this.noteSlug,
    this.blockId,
    required this.lineIndex,
    required this.rawText,
    required this.displayTitle,
    this.subtitle,
  });
}

/// Converts a display title to a kebab-case block id (matches ContentObject.slug).
String slugify(String value) {
  const accents = {
    'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
    'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
    'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
    'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
    'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
    'ç': 'c', 'ñ': 'n',
    'À': 'a', 'Á': 'a', 'Â': 'a', 'Ã': 'a', 'Ä': 'a',
    'È': 'e', 'É': 'e', 'Ê': 'e', 'Ë': 'e',
    'Ì': 'i', 'Í': 'i', 'Î': 'i', 'Ï': 'i',
    'Ò': 'o', 'Ó': 'o', 'Ô': 'o', 'Õ': 'o', 'Ö': 'o',
    'Ù': 'u', 'Ú': 'u', 'Û': 'u', 'Ü': 'u',
    'Ç': 'c', 'Ñ': 'n',
  };
  return value
      .toLowerCase()
      .trim()
      .split('')
      .map((c) => accents[c] ?? c)
      .join()
      .replaceAll(' ', '-')
      .replaceAll(RegExp(r'[^a-z0-9-]'), '');
}

class CollectionRowService {
  static List<CollectionRow> parseRows(Note note) {
    final lines = note.body.split('\n');
    final rows = <CollectionRow>[];
    for (var i = 0; i < lines.length; i++) {
      final trimmed = lines[i].trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final blockMatch = RegExp(r'\s\^(\S+)\s*$').firstMatch(trimmed);
      final blockId = blockMatch?.group(1);
      final withoutBlock = blockId != null
          ? trimmed.substring(0, blockMatch!.start)
          : trimmed;
      final parts = withoutBlock.split(RegExp(r'\||::'));
      final namePart = parts[0].trim();
      final emojiMatch =
          RegExp(r'^(\p{Emoji})\s*', unicode: true).firstMatch(namePart);
      final displayTitle = emojiMatch != null
          ? namePart.substring(emojiMatch.end).trim()
          : namePart;
      rows.add(CollectionRow(
        noteSlug: note.slug,
        blockId: blockId,
        lineIndex: i,
        rawText: withoutBlock.trim(),
        displayTitle: displayTitle.isEmpty ? namePart : displayTitle,
        subtitle: parts.length > 1
            ? parts.sublist(1).join(' · ').trim()
            : null,
      ));
    }
    return rows;
  }

  static Future<String> ensureBlockId(
    dynamic ref,
    Note note,
    CollectionRow row,
  ) async {
    if (row.blockId != null) return row.blockId!;
    final newId = slugify(row.displayTitle);
    final lines = note.body.split('\n');
    lines[row.lineIndex] = '${row.rawText} ^$newId';
    await ref.read(vaultProvider.notifier).updateObject(note.copyWith(body: lines.join('\n')));
    return newId;
  }
}

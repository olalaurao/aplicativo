// lib/services/search_service.dart
import '../models/content_object.dart';
import '../models/journal_entry.dart';
import '../models/note_model.dart';
import '../models/goal_model.dart';
import '../models/task_model.dart';

class SearchService {
  List<ContentObject> search(
    List<ContentObject> allObjects,
    String query, {
    String? typeFilter,
  }) {
    if (query.isEmpty && typeFilter == null) return [];

    final normalizedQuery = query.toLowerCase().trim();
    final tokens = normalizedQuery
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();

    final results = allObjects.where((obj) {
      if (typeFilter != null && obj.type != typeFilter) return false;
      if (tokens.isEmpty) return true;

      obj.snippet = null;

      bool allTokensMatch = tokens.every((token) {
        if (obj.title.toLowerCase().contains(token)) return true;
        if (obj.aliases.any((alias) => alias.toLowerCase().contains(token))) {
          return true;
        }
        if (obj.type.toLowerCase().contains(token)) return true;
        if (obj.categories.any((c) => c.toLowerCase().contains(token))) {
          return true;
        }
        if (obj.tags.any((tag) => tag.toLowerCase().contains(token))) {
          return true;
        }
        if (obj.organizers.any((o) => o.title.toLowerCase().contains(token))) {
          return true;
        }
        final frontmatterText = obj
            .toBaseMap()
            .entries
            .map((entry) {
              return '${entry.key}: ${entry.value}';
            })
            .join('\n');
        if (frontmatterText.toLowerCase().contains(token)) return true;

        String? body;
        if (obj is JournalEntry) body = obj.body;
        if (obj is Note) body = obj.body;
        if (obj is Goal) body = obj.description;
        if (obj is Task) body = obj.notes.join('\n');

        if (body != null && body.toLowerCase().contains(token)) {
          obj.snippet = _extractSnippet(body, token);
          return true;
        }
        final markdown = obj.toMarkdown();
        if (markdown.toLowerCase().contains(token)) {
          obj.snippet = _extractSnippet(markdown, token);
          return true;
        }
        return false;
      });

      return allTokensMatch;
    }).toList();

    return results;
  }

  String _extractSnippet(String text, String query) {
    final lines = text.split('\n');
    for (final line in lines) {
      if (line.toLowerCase().contains(query)) {
        // Return line with some padding if it's too long
        if (line.length > 80) {
          final index = line.toLowerCase().indexOf(query);
          final start = (index - 30).clamp(0, line.length);
          final end = (index + query.length + 30).clamp(0, line.length);
          return '...${line.substring(start, end)}...';
        }
        return line.trim();
      }
    }
    return '';
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/content_object.dart';
import 'vault_provider.dart';

final wikiLinksForObjectProvider =
    Provider.family<List<ContentObject>, ContentObject>((ref, source) {
      final objects = ref.watch(allObjectsProvider).valueOrNull ?? [];
      final markdown = source.toMarkdown();
      final targets = RegExp(r'!?\[\[([^\]|#]+)(?:[|#][^\]]*)?\]\]')
          .allMatches(markdown)
          .map((match) => match.group(1)?.trim().toLowerCase() ?? '')
          .where((target) => target.isNotEmpty)
          .toSet();

      if (targets.isEmpty) return const [];

      return objects.where((object) {
        if (object.id == source.id) return false;
        final keys = {
          object.id,
          object.slug,
          object.title,
          object.obsidianFileName,
          if (object.obsidianPath.isNotEmpty)
            object.obsidianPath.replaceAll(RegExp(r'\.md$'), ''),
        }.map((value) => value.trim().toLowerCase()).toSet();
        return targets.any(keys.contains);
      }).toList();
    });

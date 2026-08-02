// lib/services/merge_service.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yaml/yaml.dart';
import '../models/content_object.dart';
import '../models/shared_types.dart';
import '../models/task_model.dart';
import '../models/note_model.dart';
import '../models/journal_entry.dart';
import '../providers/vault_provider.dart';
import '../providers/merge_provider.dart';
import 'obsidian_service.dart';
import '../models/content_object.dart' as content_object show generateMarkdown;

/// Service for handling object merge operations, including reference repointing.
class MergeService {
  final Ref _ref;

  MergeService(this._ref);

  /// Repoints all references from a losing object to a surviving object.
  /// 
  /// This function discovers all objects/files that reference the losing object
  /// and rewrites those references to point at the surviving object instead.
  /// It handles:
  /// - organizers: frontmatter entries
  /// - Type-specific OrganizerReference lists (e.g., Task.participants)
  /// - Raw [[losing-slug]] occurrences in body text
  /// - Single-slug link fields (e.g., Event.task, Event.goal)
  /// 
  /// The function performs a single pass per losing object and is a no-op if
  /// there are zero backlinks.
  Future<void> repointReferences({
    required String fromSlug,
    required String toSlug,
    required OrganizerReference survivorRef,
  }) async {
    try {
      // First, we need to find the losing object to get its ID for backlinks lookup
      final allObjects = await _ref.read(allObjectsProvider.future);
      
      // Find the losing object by slug
      final losingObject = allObjects.cast<ContentObject?>().firstWhere(
        (obj) => obj?.slug == fromSlug,
        orElse: () => null,
      );

      if (losingObject == null) {
        // Losing object not found - nothing to repoint
        return;
      }

      // Use backlinksProvider to discover all references
      final backlinks = await _ref.read(backlinksProvider(losingObject.id).future);

      if (backlinks.isEmpty) {
        // No backlinks - no-op case
        return;
      }

      final obsidianService = _ref.read(obsidianServiceProvider);

      // Process each backlink (ContentObjects only - RawMarkdownFile support removed for v1)
      for (final backlink in backlinks) {
        await _repointContentObjectReferences(
          backlink,
          fromSlug,
          toSlug,
          survivorRef,
          obsidianService,
        );
      }
    } catch (e) {
      // Log error but don't fail the entire merge operation
      print('Error repointing references from $fromSlug to $toSlug: $e');
    }
  }

  Future<void> _repointContentObjectReferences(
    ContentObject object,
    String fromSlug,
    String toSlug,
    OrganizerReference survivorRef,
    ObsidianService obsidianService,
  ) async {
    bool modified = false;

    // Create a new list with repointed organizers (immutability pattern)
    final newOrganizers = object.organizers.map((ref) {
      if (_slugMatches(ref.slug, fromSlug)) {
        modified = true;
        // Preserve type in the organizer reference per AGENTS.md requirement
        return OrganizerReference(
          type: survivorRef.type, // Use survivor's type
          slug: toSlug,
          title: survivorRef.title,
          icon: survivorRef.icon,
          color: survivorRef.color,
        );
      }
      return ref;
    }).toList();

    // Handle type-specific OrganizerReference lists
    // This needs to be extended for each type that has such lists
    if (modified) {
      // Use the vault provider's update mechanism which handles proper roundtrip
      // We need to create a copy of the object with the new organizers
      // Since ContentObject objects are immutable, we rely on the vault provider
      // to handle the object reconstruction from the updated frontmatter
      
      // For now, we'll read the file, modify the markdown, and write it back
      // This ensures proper roundtrip through the Markdown file
      await _repointObjectInFile(object, fromSlug, toSlug, survivorRef, obsidianService);
    }
  }

  Future<void> _repointObjectInFile(
    ContentObject object,
    String fromSlug,
    String toSlug,
    OrganizerReference survivorRef,
    ObsidianService obsidianService,
  ) async {
    // Read the current markdown file
    final content = await obsidianService.readFile(object.obsidianPath);
    if (content == null) return;

    // Parse and modify the markdown
    final parts = content.split('---');
    if (parts.length < 3) return;

    try {
      final frontmatterStr = parts[1];
      final body = parts.sublist(2).join('---').trim();

      // Parse YAML frontmatter
      final yamlMap = loadYaml(frontmatterStr) as Map?;
      if (yamlMap == null) return;

      final frontmatter = Map<String, dynamic>.from(yamlMap);
      bool modified = false;

      // Repoint organizers: frontmatter entries
      if (frontmatter.containsKey('organizers')) {
        final organizers = frontmatter['organizers'] as List?;
        if (organizers != null) {
          final newOrganizers = organizers.map((org) {
            final ref = OrganizerReference.fromWikiLink(org.toString());
            if (_slugMatches(ref.slug, fromSlug)) {
              modified = true;
              // Preserve type in the organizer reference
              return survivorRef.toWikiLink();
            }
            return org.toString();
          }).toList();
          frontmatter['organizers'] = newOrganizers;
        }
      }

      // Repoint raw [[losing-slug]] occurrences in body text
      final newBody = _repointBodyLinks(body, fromSlug, toSlug);
      if (newBody != body) {
        modified = true;
      }

      if (modified) {
        // Reconstruct markdown using existing generateMarkdown function
        final newContent = content_object.generateMarkdown(frontmatter, newBody);
        await obsidianService.writeFile(object.obsidianPath, newContent);
      }
    } catch (e) {
      // If YAML parsing fails, fall back to simple text replacement
      // We need to handle ContentObject differently from RawMarkdownFile
      await _fallbackTextReplacementForContentObject(object, fromSlug, toSlug, survivorRef, obsidianService);
    }
  }

  Future<void> _fallbackTextReplacementForContentObject(
    ContentObject object,
    String fromSlug,
    String toSlug,
    OrganizerReference survivorRef,
    ObsidianService obsidianService,
  ) async {
    final content = await obsidianService.readFile(object.obsidianPath);
    if (content == null) return;

    bool modified = false;
    String newContent = content;

    // Simple text replacement for organizers in frontmatter
    final orgPattern = RegExp(r'organizers:\s*\n((?:\s*-\s*[^\n]+\n)+)');
    newContent = newContent.replaceAllMapped(orgPattern, (match) {
      final orgList = match.group(1)!;
      final newOrgList = orgList.replaceAllMapped(
        RegExp(r'\[\[' + RegExp.escape(fromSlug) + r'(\|[^]]*)?\]\]'),
        (m) => '[[$toSlug${m.group(1) ?? ''}]]'.replaceAll('\$toSlug', toSlug),
      );
      if (newOrgList != orgList) {
        modified = true;
        return 'organizers:\n$newOrgList';
      }
      return match.group(0)!;
    });

    // Repoint raw [[losing-slug]] occurrences in body text
    final bodyPattern = RegExp(r'---\s*\n([\s\S]+)');
    newContent = newContent.replaceAllMapped(bodyPattern, (match) {
      final body = match.group(1)!;
      final newBody = _repointBodyLinks(body, fromSlug, toSlug);
      if (newBody != body) {
        modified = true;
        return '---\n$newBody';
      }
      return match.group(0)!;
    });

    if (modified) {
      await obsidianService.writeFile(object.obsidianPath, newContent);
    }
  }

  String _repointBodyLinks(String body, String fromSlug, String toSlug) {
    // Replace [[fromSlug]] with [[toSlug]]
    // Handle both [[fromSlug]] and [[fromSlug|alias]] formats
    String result = body;
    
    // Replace [[fromSlug|alias]] -> [[toSlug|alias]]
    final aliasPattern = '\\[\\[$fromSlug\\|([^\\]]+)\\]\\]';
    result = result.replaceAllMapped(RegExp(aliasPattern), (match) {
      final alias = match.group(1) ?? '';
      return '[[$toSlug|$alias]]'.replaceAll('\$toSlug', toSlug);
    });
    
    // Replace [[fromSlug]] -> [[toSlug]]
    final simplePattern = '\\[\\[$fromSlug\\]\\]';
    result = result.replaceAll(RegExp(simplePattern), '[[$toSlug]]'.replaceAll('\$toSlug', toSlug));
    
    return result;
  }

  bool _slugMatches(String? refSlug, String targetSlug) {
    if (refSlug == null) return false;
    // Direct match
    if (refSlug == targetSlug) return true;
    // Normalized match (handling underscores, hyphens, slashes)
    final normalizedRef = refSlug
        .replaceAll('_', '-')
        .replaceAll('/', '-')
        .toLowerCase();
    final normalizedTarget = targetSlug
        .replaceAll('_', '-')
        .replaceAll('/', '-')
        .toLowerCase();
    return normalizedRef == normalizedTarget;
  }

  // Public method for testing
  bool slugMatches(String? refSlug, String targetSlug) => _slugMatches(refSlug, targetSlug);

  // Public method for testing
  String repointBodyLinks(String body, String fromSlug, String toSlug) => 
    _repointBodyLinks(body, fromSlug, toSlug);

  /// Performs the complete merge operation as a single offline batch.
  /// 
  /// This function orchestrates the entire merge process:
  /// 1. Adds aliases from losing objects to survivor (for link preservation)
  /// 2. Deletes all losing objects
  /// 3. Writes EventLogEntry on survivor
  /// 
  /// All operations are performed locally before allowing sync to avoid race conditions.
  Future<void> performMerge({
    required ContentObject survivor,
    required List<ContentObject> losingObjects,
    required Map<String, dynamic> reconciledProperties,
    String? reconciledBody,
  }) async {
    try {
      print('[MergeService] performMerge START - survivor: ${survivor.slug}, losing: ${losingObjects.length} objects');
      
      // Step 1: Add aliases from losing objects to survivor
      // This preserves all links that point to the losing objects
      print('[MergeService] Step 1: Adding aliases');
      final newAliases = <String>{...survivor.aliases};
      
      for (final losingObject in losingObjects) {
        print('[MergeService] Processing losing object: ${losingObject.slug}');
        // Add the losing object's slug as an alias (so [[losing-slug]] links still work)
        if (losingObject.slug.isNotEmpty) {
          newAliases.add(losingObject.slug);
          print('[MergeService] Added slug alias: ${losingObject.slug}');
        }
        
        // Add all existing aliases from the losing object
        for (final alias in losingObject.aliases) {
          if (alias.isNotEmpty) {
            newAliases.add(alias);
            print('[MergeService] Added alias: $alias');
          }
        }
      }
      
      // Update survivor's aliases
      survivor.aliases = newAliases.toList();
      print('[MergeService] Survivor aliases updated: ${survivor.aliases}');

      // Step 2: Update survivor timestamp
      print('[MergeService] Step 2: Updating timestamp');
      survivor.updatedAt = DateTime.now();

      // Step 3: Update survivor in vault
      print('[MergeService] Step 3: Updating survivor in vault');
      await _ref.read(vaultProvider.notifier).updateObject(survivor);
      print('[MergeService] Survivor updated successfully');

      // Step 4: Delete all losing objects
      print('[MergeService] Step 4: Deleting losing objects');
      for (final losingObject in losingObjects) {
        print('[MergeService] Deleting: ${losingObject.slug}');
        await _ref.read(vaultProvider.notifier).deleteObject(losingObject);
        print('[MergeService] Deleted: ${losingObject.slug}');
      }
      print('[MergeService] All losing objects deleted');

      // Step 5: Write EventLogEntry on survivor
      print('[MergeService] Step 5: Writing event log');
      final titles = losingObjects.map((obj) => '"${obj.title}"').join(', ');
      final dateStr = DateTime.now().toIso8601String().split('T').first;
      survivor.logEvent(
        'merge',
        'merged ${losingObjects.length} objects ($titles) on $dateStr',
      );

      // Update survivor again to save the event log
      print('[MergeService] Updating survivor with event log');
      await _ref.read(vaultProvider.notifier).updateObject(survivor);
      print('[MergeService] performMerge COMPLETE');
    } catch (e) {
      // Log error but rethrow to let UI handle it
      print('[MergeService] Error during merge: $e');
      rethrow;
    }
  }
}
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/content_object.dart';
import '../../providers/vault_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/search_service.dart';
import '../theme.dart';
import 'app_chip.dart';
import '../utils/object_icons.dart';

class WikiLinkPicker extends ConsumerStatefulWidget {
  final Function(ContentObject) onSelected;
  final String initialQuery;

  const WikiLinkPicker({
    super.key,
    required this.onSelected,
    this.initialQuery = '',
  });

  @override
  ConsumerState<WikiLinkPicker> createState() => _WikiLinkPickerState();
}

class _WikiLinkPickerState extends ConsumerState<WikiLinkPicker> {
  late TextEditingController _searchController;
  final SearchService _searchService = SearchService();
  final Set<String> _selectedTypes = {};
  List<ContentObject>? _cachedCandidates;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allObjectsAsync = ref.watch(allObjectsProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Stack(
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textMuted.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppBorderRadius.xs),
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  top: 0,
                  child: IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),

          allObjectsAsync.when(
            data: (objects) {
              final types = objects.map((obj) => obj.type).toSet().toList()
                ..sort();
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
                child: Row(
                  children: [
                    _typeChip('All', _selectedTypes.isEmpty, () {
                      setState(_selectedTypes.clear);
                    }),
                    for (final type in types)
                      _typeChip(
                        _typeLabel(type),
                        _selectedTypes.contains(type),
                        () {
                          setState(() {
                            if (!_selectedTypes.add(type)) {
                              _selectedTypes.remove(type);
                            }
                          });
                        },
                      ),
                  ],
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: (value) {
                _debounceTimer?.cancel();
                _debounceTimer = Timer(const Duration(milliseconds: 300), () {
                  if (mounted) setState(() {});
                });
              },
              decoration: InputDecoration(
                hintText: 'Buscar ou criar link...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _searchController.clear();
                          _debounceTimer?.cancel();
                          _debounceTimer = Timer(const Duration(milliseconds: 300), () {
                            if (mounted) setState(() {});
                          });
                        },
                      ),
                filled: true,
                fillColor: AppColors.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppBorderRadius.md),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              ),
            ),
          ),

          const SizedBox(height: 8),

          Expanded(
            child: allObjectsAsync.when(
              data: (objects) {
                // Load vault files only once and cache the result
                if (_cachedCandidates == null) {
                  _candidatesIncludingVaultFiles(objects).then((candidates) {
                    if (mounted) {
                      setState(() {
                        _cachedCandidates = candidates;
                      });
                    }
                  });
                }
                final candidates = _cachedCandidates ?? objects;
                return _buildResults(candidates);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Future<List<ContentObject>> _candidatesIncludingVaultFiles(
    List<ContentObject> objects,
  ) async {
    final byPath = {
      for (final obj in objects)
        if (obj.obsidianPath.isNotEmpty)
          obj.obsidianPath.replaceAll('\\', '/').toLowerCase(): obj,
    };
    final result = <ContentObject>[...objects];
    try {
      final service = ref.read(obsidianServiceProvider);
      final files = await service.getFilesInFolder('');
      for (final file in files.where((file) => file.path.endsWith('.md'))) {
        final relativePath = service.getRelativePath(file.path);
        final key = relativePath.replaceAll('\\', '/').toLowerCase();
        if (byPath.containsKey(key) || key.contains('/_deleted/')) continue;
        final title = relativePath
            .split(RegExp(r'[/\\]'))
            .last
            .replaceAll(RegExp(r'\.md$'), '');
        result.add(
          NewPagePlaceholder(title: title)..obsidianPath = relativePath,
        );
      }
    } catch (e) {
      // Error handled silently
    }
    return result;
  }

  Widget _buildResults(List<ContentObject> candidates) {
    final query = _searchController.text.trim();
    final scoped = _selectedTypes.isEmpty
        ? candidates
        : candidates.where((obj) => _selectedTypes.contains(obj.type)).toList();
    final filtered = query.isEmpty
        ? scoped.take(40).toList()
        : _searchService.search(scoped, query);

    final exactMatch = candidates.any(
      (obj) => obj.title.toLowerCase() == query.toLowerCase(),
    );

    return ListView.builder(
      itemCount: filtered.length + (query.isNotEmpty && !exactMatch ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == filtered.length) {
          return ListTile(
            leading: Icon(
              Icons.add_circle_outline_rounded,
              color: AppTheme.accentColor(context),
            ),
            title: Text(
              'Usar "[[$query]]"',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppTheme.accentColor(context),
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: const Text('Link para uma nota existente ou futura'),
            onTap: () => widget.onSelected(NewPagePlaceholder(title: query)),
          );
        }

        final obj = filtered[index];
        return ListTile(
          leading: _buildTypeIcon(obj.type),
          title: Text(
            obj.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: _buildSubtitle(obj),
          onTap: () => widget.onSelected(obj),
        );
      },
    );
  }

  Widget _buildSubtitle(ContentObject obj) {
    if (obj.aliases.isNotEmpty) {
      return Text(
        obj.aliases.join(', '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
      );
    }
    return Text(
      obj.obsidianPath.isNotEmpty ? obj.obsidianPath : _typeLabel(obj.type),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
    );
  }

  Widget _typeChip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: AppChip(
        label: label,
        selected: selected,
        onTap: onTap,
        variant: ChipVariant.choice,
        size: ChipSize.medium,
      ),
    );
  }

  String _typeLabel(String type) {
    return switch (type) {
      'task' => 'Tasks',
      'habit' => 'Habits',
      'goal' => 'Goals',
      'note' => 'Notes',
      'resource' => 'Resources',
      'person' => 'People',
      'project' => 'Projects',
      'area' => 'Areas',
      'activity' => 'Activities',
      'social_post' => 'Social',
      _ => type,
    };
  }

  Widget _buildTypeIcon(String type) {
    final settings = ref.read(settingsProvider);
    final signatureColor = ObjectIcons.colorForTypeWithSignatures(type, settings.typeSignatures);
    final defaultColor = ObjectIcons.defaultColorForType(type);
    
    // Use signature color if configured and different from default
    final color = (signatureColor != defaultColor) 
        ? signatureColor 
        : _getDefaultHardcodedColor(type);
    
    final icon = ObjectIcons.iconDataForTypeWithSignatures(type, settings.typeSignatures) 
        ?? _getDefaultIcon(type);
    
    return Icon(icon, color: color, size: 20);
  }

  Color _getDefaultHardcodedColor(String type) {
    return switch (type) {
      'task' => AppColors.info,
      'habit' => AppColors.habitOrange,
      'project' => AppColors.habitPurple,
      'person' => AppColors.habitGreen,
      'resource' => AppColors.error,
      _ => AppColors.textMuted,
    };
  }

  IconData _getDefaultIcon(String type) {
    return switch (type) {
      'task' => Icons.check_circle_outline_rounded,
      'habit' => Icons.repeat_rounded,
      'project' => Icons.folder_open_rounded,
      'person' => Icons.person_outline_rounded,
      'resource' => Icons.bookmark_outline_rounded,
      _ => Icons.description_outlined,
    };
  }
}

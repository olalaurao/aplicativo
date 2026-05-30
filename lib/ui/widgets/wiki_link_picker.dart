import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/content_object.dart';
import '../../providers/vault_provider.dart';
import '../../services/search_service.dart';
import '../theme.dart';

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

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
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
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  top: 0,
                  child: IconButton(
                    tooltip: 'Fechar',
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
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    _typeChip('Todos', _selectedTypes.isEmpty, () {
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
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Buscar ou criar link...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => setState(_searchController.clear),
                      ),
                filled: true,
                fillColor: AppColors.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),

          const SizedBox(height: 8),

          Expanded(
            child: allObjectsAsync.when(
              data: (objects) {
                return FutureBuilder<List<ContentObject>>(
                  future: _candidatesIncludingVaultFiles(objects),
                  builder: (context, snapshot) {
                    final candidates = snapshot.data ?? objects;
                    return _buildResults(candidates);
                  },
                );
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
      debugPrint('WikiLinkPicker failed to load raw vault files: $e');
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
            leading: const Icon(
              Icons.add_circle_outline_rounded,
              color: AppColors.primary,
            ),
            title: Text(
              'Usar "[[$query]]"',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.primary,
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
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.primary.withValues(alpha: 0.14),
        backgroundColor: AppColors.surfaceVariant,
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.divider,
        ),
      ),
    );
  }

  String _typeLabel(String type) {
    return switch (type) {
      'task' => 'Tarefas',
      'habit' => 'Hábitos',
      'goal' => 'Metas',
      'note' => 'Notas',
      'resource' => 'Recursos',
      'person' => 'Pessoas',
      'project' => 'Projetos',
      'area' => 'Áreas',
      'activity' => 'Atividades',
      'social_post' => 'Social',
      _ => type,
    };
  }

  Widget _buildTypeIcon(String type) {
    IconData icon;
    Color color;
    switch (type) {
      case 'task':
        icon = Icons.check_circle_outline_rounded;
        color = AppColors.info;
        break;
      case 'habit':
        icon = Icons.repeat_rounded;
        color = AppColors.habitOrange;
        break;
      case 'project':
        icon = Icons.folder_open_rounded;
        color = AppColors.habitPurple;
        break;
      case 'person':
        icon = Icons.person_outline_rounded;
        color = AppColors.habitGreen;
        break;
      case 'resource':
        icon = Icons.bookmark_outline_rounded;
        color = AppColors.error;
        break;
      default:
        icon = Icons.description_outlined;
        color = AppColors.textMuted;
    }
    return Icon(icon, color: color, size: 20);
  }
}

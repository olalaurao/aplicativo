import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/vault_provider.dart';
import '../../providers/settings_provider.dart';
import '../../models/resource_model.dart';
import '../../models/saved_filter.dart';
import '../../services/markdown_parser.dart';
import '../../services/resource_metadata_service.dart';
import '../theme.dart';
import '../forms/create_resource_form.dart';
import '../widgets/empty_state.dart';
import '../widgets/filter_sort_sheet.dart';
import 'universal_detail_view.dart';

enum ResourceViewMode { shelfHighlights, list, grid }

class ResourcesScreen extends ConsumerStatefulWidget {
  const ResourcesScreen({super.key});

  @override
  ConsumerState<ResourcesScreen> createState() => _ResourcesScreenState();
}

// Quick-access type filters shown as chips
const _resourceTypeFilters = [
  (label: 'Todos os tipos', emoji: '✨', values: <String>[]),
  (label: 'Livro', emoji: '📗', values: ['book', 'livro']),
  (label: 'Filme', emoji: '🎬', values: ['movie', 'filme']),
  (label: 'Série', emoji: '📺', values: ['series', 'série', 'tv show', 'show']),
  (label: 'Podcast', emoji: '🎙️', values: ['podcast']),
  (label: 'Artigo', emoji: '📄', values: ['article', 'artigo']),
];

class _ResourcesScreenState extends ConsumerState<ResourcesScreen> {
  ResourceViewMode _resourceViewMode = ResourceViewMode.shelfHighlights;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _clipboardBannerShown = false;

  SavedFilter? _activeFilter;
  List<SavedFilter> _savedFilters = [];
  // Index into _resourceTypeFilters; 0 = "All types" (no type filter)
  int _selectedTypeIndex = 0;
  
  // Bulk selection
  final Set<String> _selectedIds = {};
  bool _isSelectionMode = false;
  
  // Configurable grid fields
  static const _availableFields = [
    'status',
    'rating',
    'category',
    'author',
    'year',
    'priority',
  ];
  final Set<String> _visibleGridFields = {'status', 'rating'};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(
        () => _savedFilters = ref.read(settingsProvider).filtersFor('resource'),
      );
      _checkClipboardUrl();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<T> _applyFilterAndSort<T>(List<T> all) {
    final typeFilter = _resourceTypeFilters[_selectedTypeIndex];
    var result = (_activeFilter?.apply(all) ?? all).where((item) {
      final res = item as Resource;
      // Type filter
      if (typeFilter.values.isNotEmpty) {
        final rt = res.mediaType.toLowerCase();
        if (!typeFilter.values.any((v) => rt.contains(v) || v.contains(rt))) {
          return false;
        }
      }
      // Search query
      if (_searchQuery.isEmpty) return true;
      final haystack = [
        res.title,
        res.author,
        res.category,
        res.mediaType,
        res.synopsis,
        ...res.tags,
        ...res.aliases,
      ].whereType<String>().join(' ').toLowerCase();
      return haystack.contains(_searchQuery.toLowerCase());
    }).toList();

    final sort = _activeFilter?.sortBy ?? SortField.modified;
    final asc = _activeFilter?.sortAscending ?? false;
    result.sort((a, b) {
      final cmp = switch (sort) {
        SortField.title => (a as dynamic).title.compareTo((b as dynamic).title),
        SortField.created =>
          ((a as dynamic).createdAt ?? DateTime(0)).compareTo(
            (b as dynamic).createdAt ?? DateTime(0),
          ),
        SortField.modified =>
          ((a as dynamic).updatedAt ?? DateTime(0)).compareTo(
            (b as dynamic).updatedAt ?? DateTime(0),
          ),
        SortField.manual => ((a as dynamic).order ?? 0).compareTo(
          (b as dynamic).order ?? 0,
        ),
        SortField.rating => ((a as dynamic).rating ?? 0).compareTo(
          (b as dynamic).rating ?? 0,
        ),
        SortField.status => ((a as dynamic).status?.name ?? '').compareTo(
          (b as dynamic).status?.name ?? '',
        ),
        SortField.type => ((a as dynamic).mediaType ?? '').compareTo(
          (b as dynamic).mediaType ?? '',
        ),
        _ => 0,
      };
      return asc ? cmp : -cmp;
    });
    return result;
  }

  void _openFilterSheet() => FilterSortSheet.show(
    context: context,
    ref: ref,
    targetType: 'resource',
    currentFilter: _activeFilter,
    availableProperties: ResourceFilterProperties.all,
    onApply: (f) => setState(() {
      _activeFilter = f;
      _savedFilters = ref.read(settingsProvider).filtersFor('resource');
      if (f != null) {
        if (f.viewMode == ViewMode.grid) {
          _resourceViewMode = ResourceViewMode.grid;
        } else {
          _resourceViewMode = ResourceViewMode.list;
        }
      }
    }),
  );

  @override
  Widget build(BuildContext context) {
    final resources = ref.watch(resourcesProvider);
    final filtered = _applyFilterAndSort(resources).cast<Resource>();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        key: const PageStorageKey('resources-scroll'),
        slivers: [
          SliverAppBar(
            title: _isSelectionMode
                ? Text('${_selectedIds.length} selecionados')
                : const Text('Media & Resources'),
            floating: true,
            pinned: true,
            actions: [
              if (_isSelectionMode) ...[
                IconButton(
                  icon: const Icon(Icons.select_all_rounded),
                  onPressed: () {
                    final filtered = _applyFilterAndSort(ref.watch(resourcesProvider));
                    setState(() {
                      _selectedIds.clear();
                      _selectedIds.addAll(filtered.map((r) => r.id));
                    });
                  },
                  tooltip: 'Selecionar todos',
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => setState(() {
                    _isSelectionMode = false;
                    _selectedIds.clear();
                  }),
                  tooltip: 'Cancelar seleção',
                ),
              ] else ...[
                IconButton(
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  onPressed: () => setState(() => _isSelectionMode = true),
                  tooltip: 'Seleção múltipla',
                ),
                if (_resourceViewMode == ResourceViewMode.grid)
                  IconButton(
                    icon: const Icon(Icons.view_column_rounded),
                    onPressed: _showFieldConfigDialog,
                    tooltip: 'Configurar campos',
                  ),
                IconButton(
                  icon: const Icon(Icons.tune_rounded),
                  onPressed: _openFilterSheet,
                ),
                IconButton(
                  icon: Icon(
                    _resourceViewMode == ResourceViewMode.shelfHighlights
                        ? Icons.auto_awesome_mosaic_rounded
                        : _resourceViewMode == ResourceViewMode.list
                            ? Icons.view_list_rounded
                            : Icons.grid_view_rounded,
                  ),
                  tooltip: _resourceViewMode == ResourceViewMode.shelfHighlights
                      ? 'Visualização Geral'
                      : _resourceViewMode == ResourceViewMode.list
                          ? 'Visualização em Lista'
                          : 'Visualização em Grade',
                  onPressed: () => setState(() {
                    _resourceViewMode = switch (_resourceViewMode) {
                      ResourceViewMode.shelfHighlights => ResourceViewMode.list,
                      ResourceViewMode.list => ResourceViewMode.grid,
                      ResourceViewMode.grid => ResourceViewMode.shelfHighlights,
                    };
                  }),
                ),
                IconButton(
                  icon: const Icon(Icons.content_paste_search_rounded),
                  tooltip: 'Importar link',
                  onPressed: _importFromClipboardOrPrompt,
                ),
                IconButton(
                  icon: const Icon(Icons.add_link_rounded),
                  onPressed: _openCreateResource,
                ),
              ],
            ],
          ),
          SliverToBoxAdapter(child: _buildSearchField()),
          if (_isSelectionMode && _selectedIds.isNotEmpty)
            SliverToBoxAdapter(child: _buildBulkActionBar()),
          // ── Saved-filter chips ──────────────────────────────────────────────
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Row(
                children: [
                  _chip(
                    'Todos',
                    _activeFilter == null,
                    () => setState(() => _activeFilter = null),
                    emoji: '🗂️',
                  ),
                  ..._savedFilters.map(
                    (f) => _chip(
                      f.name,
                      _activeFilter?.id == f.id,
                      () => setState(() => _activeFilter = f),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ── Quick type-filter chips ─────────────────────────────────────────
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Row(
                children: List.generate(_resourceTypeFilters.length, (i) {
                  final tf = _resourceTypeFilters[i];
                  return _chip(
                    tf.label,
                    _selectedTypeIndex == i,
                    () => setState(() => _selectedTypeIndex = i),
                    emoji: tf.emoji,
                  );
                }),
              ),
            ),
          ),
          if (filtered.isEmpty)
            SliverFillRemaining(
              child: EmptyState(
                icon: Icons.local_library_rounded,
                headline: 'Your library is empty',
                subtext:
                    'Save books, movies, articles and other resources to keep everything organized in one place.',
                ctaLabel: 'Add Resource',
                onCta: _openCreateResource,
              ),
            )
          else if (_resourceViewMode == ResourceViewMode.shelfHighlights) ...[
            SliverToBoxAdapter(child: _buildShelf(filtered)),
            SliverToBoxAdapter(child: _buildHighlightsFeed(filtered)),
          ] else if (_resourceViewMode == ResourceViewMode.grid)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.58,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildResourceGridTile(context, filtered[index]),
                  childCount: filtered.length,
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => Padding(
                    key: ValueKey(filtered[index].id),
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildResourceListTile(context, filtered[index]),
                  ),
                  childCount: filtered.length,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _chip(
    String label,
    bool selected,
    VoidCallback onTap, {
    String? emoji,
  }) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.accentColor(context)
                : AppTheme.surfaceVariantColor(context),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (emoji != null) ...[
                Text(emoji, style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? Colors.black
                      : AppTheme.textSecondaryColor(context),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildBulkActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.accentColor(context).withValues(alpha: 0.08),
        border: Border(
          bottom: BorderSide(color: AppTheme.accentColor(context).withValues(alpha: 0.2)),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _bulkActionChip('Status', Icons.check_circle_outline, _showBulkStatusPicker),
            const SizedBox(width: 8),
            _bulkActionChip('Rating', Icons.star_outline, _showBulkRatingPicker),
            const SizedBox(width: 8),
            _bulkActionChip('Categoria', Icons.category, _showBulkCategoryPicker),
            const SizedBox(width: 8),
            _bulkActionChip('Prioridade', Icons.flag, _showBulkPriorityPicker),
          ],
        ),
      ),
    );
  }

  Widget _bulkActionChip(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.accentColor(context).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.accentColor(context).withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppTheme.accentColor(context)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.accentColor(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBulkStatusPicker() {
    final resources = ref.read(resourcesProvider);
    final selectedResources = resources.where((r) => _selectedIds.contains(r.id)).toList();
    
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Alterar Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...ResourceStatus.values.map((status) => ListTile(
              title: Text(_resourceStatusLabel(status)),
              onTap: () async {
                for (final resource in selectedResources) {
                  final updated = resource.copyWith(status: status);
                  await ref.read(resourcesProvider.notifier).updateResource(updated);
                }
                if (mounted) {
                  Navigator.pop(ctx);
                  setState(() {
                    _isSelectionMode = false;
                    _selectedIds.clear();
                  });
                }
              },
            )),
          ],
        ),
      ),
    );
  }

  void _showBulkRatingPicker() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Alterar Rating', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(5, (i) => IconButton(
                icon: const Icon(Icons.star_rounded, size: 32, color: AppColors.warning),
                onPressed: () async {
                  final resources = ref.read(resourcesProvider);
                  final selectedResources = resources.where((r) => _selectedIds.contains(r.id)).toList();
                  for (final resource in selectedResources) {
                    final updated = resource.copyWith(rating: i + 1);
                    await ref.read(resourcesProvider.notifier).updateResource(updated);
                  }
                  if (mounted) {
                    Navigator.pop(ctx);
                    setState(() {
                      _isSelectionMode = false;
                      _selectedIds.clear();
                    });
                  }
                },
              )),
            ),
          ],
        ),
      ),
    );
  }

  void _showBulkCategoryPicker() {
    final resources = ref.read(resourcesProvider);
    final allCategories = resources.map((r) => r.category).whereType<String>().toSet().toList();
    
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Alterar Categoria', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (allCategories.isEmpty)
              const Text('Nenhuma categoria disponível')
            else
              ...allCategories.map((cat) => ListTile(
                title: Text(cat),
                onTap: () async {
                  final selectedResources = resources.where((r) => _selectedIds.contains(r.id)).toList();
                  for (final resource in selectedResources) {
                    final updated = resource.copyWith(category: cat);
                    await ref.read(resourcesProvider.notifier).updateResource(updated);
                  }
                  if (mounted) {
                    Navigator.pop(ctx);
                    setState(() {
                      _isSelectionMode = false;
                      _selectedIds.clear();
                    });
                  }
                },
              )),
            ListTile(
              title: const Text('Remover categoria'),
              onTap: () async {
                final selectedResources = resources.where((r) => _selectedIds.contains(r.id)).toList();
                for (final resource in selectedResources) {
                  final updated = resource.copyWith(category: null);
                  await ref.read(resourcesProvider.notifier).updateResource(updated);
                }
                if (mounted) {
                  Navigator.pop(ctx);
                  setState(() {
                    _isSelectionMode = false;
                    _selectedIds.clear();
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showBulkPriorityPicker() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Alterar Prioridade', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...ResourcePriority.values.map((priority) => ListTile(
              title: Text(priority.name),
              onTap: () async {
                final resources = ref.read(resourcesProvider);
                final selectedResources = resources.where((r) => _selectedIds.contains(r.id)).toList();
                for (final resource in selectedResources) {
                  final updated = resource.copyWith(priority: priority);
                  await ref.read(resourcesProvider.notifier).updateResource(updated);
                }
                if (mounted) {
                  Navigator.pop(ctx);
                  setState(() {
                    _isSelectionMode = false;
                    _selectedIds.clear();
                  });
                }
              },
            )),
          ],
        ),
      ),
    );
  }

  String _resourceStatusLabel(ResourceStatus status) => switch (status) {
    ResourceStatus.toConsume => 'Quero consumir',
    ResourceStatus.inProgress => 'Lendo',
    ResourceStatus.completed => 'Concluído',
    ResourceStatus.dropped => 'Abandonado',
  };

  void _showFieldConfigDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Configurar campos da grade'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _availableFields.map((field) => CheckboxListTile(
            title: Text(_fieldLabel(field)),
            value: _visibleGridFields.contains(field),
            onChanged: (value) {
              setState(() {
                if (value == true) {
                  _visibleGridFields.add(field);
                } else {
                  _visibleGridFields.remove(field);
                }
              });
            },
          )).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  String _fieldLabel(String field) => switch (field) {
    'status' => 'Status',
    'rating' => 'Rating',
    'category' => 'Categoria',
    'author' => 'Autor',
    'year' => 'Ano',
    'priority' => 'Prioridade',
    _ => field,
  };

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Buscar recurso',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => setState(() {
                    _searchController.clear();
                    _searchQuery = '';
                  }),
                ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _buildShelf(List<Resource> resources) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
        child: Text(
          'RECENTES',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.10,
            color: AppTheme.textMutedColor(context),
          ),
        ),
      ),
      SizedBox(
        height: 148,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: resources.take(8).length,
          separatorBuilder: (context, index) => const SizedBox(width: 8),
          itemBuilder: (ctx, i) =>
              _buildShelfItem(ctx, resources.take(8).toList()[i]),
        ),
      ),
    ],
  );

  Widget _buildShelfItem(
    BuildContext context,
    Resource resource,
  ) => GestureDetector(
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UniversalDetailView(object: resource)),
    ),
    child: SizedBox(
      width: 72,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 64,
              height: 90,
              child: resource.coverImage?.isNotEmpty == true
                  ? Image.network(
                      resource.coverImage!,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, stack) =>
                          _fallbackIcon(resource),
                    )
                  : _fallbackIcon(resource),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            resource.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
          ),
          Text(
            resource.author ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 8,
              color: AppTheme.textMutedColor(context),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _fallbackIcon(Resource r) {
    final emoji = switch (r.mediaType.toLowerCase()) {
      'book' || 'livro' => '📗',
      'podcast' => '🎙️',
      'movie' || 'filme' => '🎬',
      'article' => '📄',
      _ => '📚',
    };
    return Container(
      color: AppColors.surfaceVariant,
      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 28))),
    );
  }

  Widget _buildHighlightsFeed(List<Resource> resources) {
    final highlights = <({Resource r, String text, String? tag})>[];
    for (final r in resources) {
      if (r.synopsis == null || r.synopsis!.isEmpty) continue;
      final hls = MarkdownParser.extractHighlights(r.synopsis!);
      highlights.addAll(
        hls.take(2).map((h) => (r: r, text: h.text, tag: h.tag)),
      );
    }
    if (highlights.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            '✨ HIGHLIGHTS RECENTES',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.10,
              color: AppTheme.textMutedColor(context),
            ),
          ),
        ),
        ...highlights.map(
          (hl) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UniversalDetailView(object: hl.r),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _resourceColor(hl.r).withValues(alpha: 0.08),
                  border: Border(
                    left: BorderSide(color: _resourceColor(hl.r), width: 2),
                  ),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_resourceEmoji(hl.r)} ${hl.r.title}${hl.tag != null ? " · #${hl.tag}" : ""}',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: _resourceColor(hl.r),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '"${hl.text}"',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.textSecondaryColor(context),
                        height: 1.55,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color _resourceColor(Resource r) => switch (r.mediaType.toLowerCase()) {
    'podcast' => AppColors.info,
    'book' || 'livro' => AppTheme.accentColor(context),
    _ => AppColors.habitPurple,
  };

  String _resourceEmoji(Resource r) => switch (r.mediaType.toLowerCase()) {
    'book' || 'livro' => '📗',
    'podcast' => '🎙️',
    'movie' || 'filme' => '🎬',
    'article' => '📄',
    _ => '📚',
  };

  Widget _buildResourceListTile(BuildContext context, Resource resource) {
    final isSelected = _selectedIds.contains(resource.id);
    
    return GestureDetector(
      onTap: _isSelectionMode
          ? () {
              setState(() {
                if (isSelected) {
                  _selectedIds.remove(resource.id);
                } else {
                  _selectedIds.add(resource.id);
                }
              });
            }
          : () {
              context.push('/detail/${resource.id}', extra: {'object': resource});
            },
      onLongPress: () {
        setState(() {
          _isSelectionMode = true;
          _selectedIds.add(resource.id);
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accentColor(context).withValues(alpha: 0.1) : null,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: AppTheme.accentColor(context), width: 2)
              : null,
        ),
        child: ListTile(
          leading: Stack(
            children: [
              SizedBox(
                width: 40,
                child: AspectRatio(
                  aspectRatio: 1 / 1.414,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: resource.coverImage?.isNotEmpty == true
                        ? Image.network(
                            resource.coverImage!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _fallbackIcon(resource),
                          )
                        : _fallbackIcon(resource),
                  ),
                ),
              ),
              if (_isSelectionMode)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isSelected ? Icons.check_circle : Icons.circle_outlined,
                      color: isSelected ? AppTheme.accentColor(context) : Colors.white,
                      size: 18,
                    ),
                  ),
                ),
            ],
          ),
          title: Text(
            resource.title,
            style: const TextStyle(fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildStatusChip(resource.status),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      resource.author ?? 'Unknown',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              _buildRatingRow(resource),
            ],
          ),
          trailing: _isSelectionMode ? null : const Icon(Icons.chevron_right_rounded, size: 20),
        ),
      ),
    );
  }

  Widget _buildResourceGridTile(BuildContext context, Resource resource) {
    final isSelected = _selectedIds.contains(resource.id);
    
    return GestureDetector(
      onTap: _isSelectionMode
          ? () {
              setState(() {
                if (isSelected) {
                  _selectedIds.remove(resource.id);
                } else {
                  _selectedIds.add(resource.id);
                }
              });
            }
          : () {
              context.push('/detail/${resource.id}', extra: {'object': resource});
            },
      onLongPress: () {
        setState(() {
          _isSelectionMode = true;
          _selectedIds.add(resource.id);
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accentColor(context).withValues(alpha: 0.1) : null,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: AppTheme.accentColor(context), width: 2)
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      resource.coverImage?.isNotEmpty == true
                          ? Image.network(
                              resource.coverImage!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  _fallbackIcon(resource),
                            )
                          : _fallbackIcon(resource),
                      if (_isSelectionMode)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isSelected ? Icons.check_circle : Icons.circle_outlined,
                              color: isSelected ? AppTheme.accentColor(context) : Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      Positioned(
                        bottom: 4,
                        left: 4,
                        child: _buildStatusChip(resource.status),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        resource.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      ..._buildConfiguredFields(resource),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (_visibleGridFields.contains('rating'))
                            _buildRatingRow(resource),
                          Text(
                            _resourceEmoji(resource),
                            style: const TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(ResourceStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _resourceStatusColor(status).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _resourceStatusLabel(status),
        style: const TextStyle(
          fontSize: 8,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _resourceStatusColor(ResourceStatus status) => switch (status) {
    ResourceStatus.inProgress => AppColors.habitOrange,
    ResourceStatus.completed => AppColors.success,
    ResourceStatus.toConsume => AppColors.info,
    ResourceStatus.dropped => AppColors.error,
  };

  List<Widget> _buildConfiguredFields(Resource resource) {
    final fields = <Widget>[];
    
    if (_visibleGridFields.contains('author') && resource.author != null) {
      fields.add(
        Text(
          resource.author!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 9,
            color: AppTheme.textMutedColor(context),
          ),
        ),
      );
    }
    
    if (_visibleGridFields.contains('category') && resource.category != null) {
      fields.add(
        Text(
          resource.category!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 9,
            color: AppColors.info,
          ),
        ),
      );
    }
    
    if (_visibleGridFields.contains('year') && resource.year != null) {
      fields.add(
        Text(
          resource.year.toString(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 9,
            color: AppTheme.textMutedColor(context),
          ),
        ),
      );
    }
    
    if (_visibleGridFields.contains('priority') && resource.priority != ResourcePriority.none) {
      fields.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: _priorityColor(resource.priority).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            resource.priority.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 8,
              color: _priorityColor(resource.priority),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }
    
    return fields;
  }

  Color _priorityColor(ResourcePriority priority) => switch (priority) {
    ResourcePriority.high => AppColors.error,
    ResourcePriority.medium => AppColors.warning,
    ResourcePriority.low => AppColors.info,
    ResourcePriority.none => AppColors.textMuted,
  };

  Widget _buildRatingRow(Resource resource) {
    return Row(
      children: List.generate(
        5,
        (i) => Icon(
          Icons.star_rounded,
          size: 16,
          color: i < resource.rating
              ? AppColors.warning
              : AppColors.textMuted.withValues(alpha: 0.2),
        ),
      ),
    );
  }

  void _openCreateResource() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateResourceForm()),
    );
  }

  Future<void> _checkClipboardUrl() async {
    if (_clipboardBannerShown || !mounted) return;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    final uri = Uri.tryParse(text);
    if (text.isEmpty || uri == null || !uri.hasScheme) return;
    if (!ResourceMetadataService.isResourceUrl(text)) return;

    final source = ResourceMetadataService.detectSource(text);
    _clipboardBannerShown = true;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        leading: const Icon(Icons.link_rounded),
        content: Text(
          'Link de ${_sourceLabel(source)} detectado. Importar como recurso?',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                ScaffoldMessenger.of(context).hideCurrentMaterialBanner(),
            child: const Text('Ignorar'),
          ),
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreateResourceForm(initialUrl: text),
                ),
              );
            },
            child: const Text('Importar'),
          ),
        ],
      ),
    );
  }

  String _sourceLabel(ResourceSource source) {
    return switch (source) {
      ResourceSource.openLibrary => 'OpenLibrary',
      ResourceSource.googleBooks => 'Google Books',
      ResourceSource.imdb => 'IMDB',
      ResourceSource.amazon => 'Amazon',
      ResourceSource.goodreads => 'Goodreads',
      ResourceSource.unknown => 'web',
    };
  }

  Future<void> _importFromClipboardOrPrompt() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final url = data?.text?.trim() ?? '';
    if (url.isNotEmpty && ResourceMetadataService.isResourceUrl(url)) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CreateResourceForm(initialUrl: url)),
      );
      return;
    }
    if (!mounted) return;
    await _showUrlInputDialog(context);
  }

  Future<void> _showUrlInputDialog(BuildContext context) async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Importar link'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Cole um link de livro, filme ou série',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                final url = controller.text.trim();
                if (!ResourceMetadataService.isResourceUrl(url)) return;
                Navigator.pop(dialogContext);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateResourceForm(initialUrl: url),
                  ),
                );
              },
              child: const Text('Buscar'),
            ),
          ],
        );
      },
    );
  }
}


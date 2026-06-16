import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/vault_provider.dart';
import '../../providers/settings_provider.dart';
import '../../models/resource_model.dart';
import '../../models/saved_filter.dart';
import '../../services/markdown_parser.dart';
import '../theme.dart';
import '../forms/create_resource_form.dart';
import '../widgets/empty_state.dart';
import '../widgets/filter_sort_sheet.dart';
import 'universal_detail_view.dart';

enum ResourceViewMode { shelfHighlights, listHighlights }

class ResourcesScreen extends ConsumerStatefulWidget {
  const ResourcesScreen({super.key});

  @override
  ConsumerState<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends ConsumerState<ResourcesScreen> {
  ResourceViewMode _resourceViewMode = ResourceViewMode.shelfHighlights;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  SavedFilter? _activeFilter;
  List<SavedFilter> _savedFilters = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() => _savedFilters = ref.read(settingsProvider).filtersFor('resource'));
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<T> _applyFilterAndSort<T>(List<T> all) {
    var result = (_activeFilter?.apply(all) ?? all).where((item) {
      if (_searchQuery.isEmpty) return true;
      final res = item as Resource;
      final haystack = [
        res.title, res.author, res.category, res.resourceType,
        res.synopsis, ...res.tags, ...res.aliases,
      ].whereType<String>().join(' ').toLowerCase();
      return haystack.contains(_searchQuery.toLowerCase());
    }).toList();

    final sort = _activeFilter?.sortBy ?? SortField.modified;
    final asc  = _activeFilter?.sortAscending ?? false;
    result.sort((a, b) {
      final cmp = switch (sort) {
        SortField.title    => (a as dynamic).title.compareTo((b as dynamic).title),
        SortField.created  => ((a as dynamic).createdAt ?? DateTime(0))
                                .compareTo((b as dynamic).createdAt ?? DateTime(0)),
        SortField.modified => ((a as dynamic).updatedAt ?? DateTime(0))
                                .compareTo((b as dynamic).updatedAt ?? DateTime(0)),
        SortField.manual   => ((a as dynamic).order ?? 0).compareTo((b as dynamic).order ?? 0),
        SortField.rating   => ((a as dynamic).rating ?? 0).compareTo((b as dynamic).rating ?? 0),
        SortField.status   => ((a as dynamic).status?.name ?? '').compareTo((b as dynamic).status?.name ?? ''),
        SortField.type     => ((a as dynamic).resourceType ?? '').compareTo((b as dynamic).resourceType ?? ''),
        _ => 0,
      };
      return asc ? cmp : -cmp;
    });
    return result;
  }

  void _openFilterSheet() => FilterSortSheet.show(
    context: context, ref: ref,
    targetType: 'resource',
    currentFilter: _activeFilter,
    availableProperties: ResourceFilterProperties.all,
    onApply: (f) => setState(() {
      _activeFilter = f;
      _savedFilters = ref.read(settingsProvider).filtersFor('resource');
      if (f != null) {
        if (f.viewMode == ViewMode.grid) _resourceViewMode = ResourceViewMode.shelfHighlights;
        else _resourceViewMode = ResourceViewMode.listHighlights;
      }
    }));

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
            title: const Text('Media & Resources'),
            floating: true,
            pinned: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.tune_rounded),
                onPressed: _openFilterSheet,
              ),
              IconButton(
                icon: Icon(
                  _resourceViewMode == ResourceViewMode.listHighlights
                      ? Icons.view_list_rounded
                      : Icons.grid_view_rounded,
                ),
                onPressed: () => setState(() {
                  _resourceViewMode = _resourceViewMode == ResourceViewMode.shelfHighlights
                      ? ResourceViewMode.listHighlights
                      : ResourceViewMode.shelfHighlights;
                }),
              ),
              IconButton(
                icon: const Icon(Icons.add_link_rounded),
                onPressed: _openCreateResource,
              ),
            ],
          ),
          SliverToBoxAdapter(child: _buildSearchField()),
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  _chip('Todos', _activeFilter == null, () => setState(() => _activeFilter = null)),
                  ..._savedFilters.map((f) => _chip(f.name, _activeFilter?.id == f.id,
                    () => setState(() => _activeFilter = f))),
                ],
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
          ] else
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

  Widget _chip(String label, bool selected, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : AppTheme.surfaceVariantColor(context),
        borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
        color: selected ? Colors.black : AppTheme.textSecondaryColor(context)))));

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
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.fromLTRB(16,12,16,6),
        child: Text('RECENTES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
          letterSpacing: 0.10, color: AppTheme.textMutedColor(context)))),
      SizedBox(height: 108, child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: resources.take(8).length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) => _buildShelfItem(ctx, resources.take(8).toList()[i]))),
    ]);

  Widget _buildShelfItem(BuildContext context, Resource resource) =>
    GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => UniversalDetailView(object: resource))),
      child: SizedBox(width: 72, child: Column(children: [
        Container(
          width: 72, height: 72, clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10),
            color: AppColors.surfaceVariant),
          child: resource.coverImage?.isNotEmpty == true
            ? Image.network(resource.coverImage!, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallbackIcon(resource))
            : _fallbackIcon(resource)),
        const SizedBox(height: 4),
        Text(resource.title, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700)),
        Text(resource.author ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 8, color: AppTheme.textMutedColor(context))),
      ])));

  Widget _fallbackIcon(Resource r) {
    final emoji = switch (r.resourceType.toLowerCase()) {
      'book' || 'livro' => '📗', 'podcast' => '🎙️',
      'movie' || 'filme' => '🎬', 'article' => '📄', _ => '📚',
    };
    return Container(color: AppColors.surfaceVariant,
      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 28))));
  }

  Widget _buildHighlightsFeed(List<Resource> resources) {
    final highlights = <({Resource r, String text, String? tag})>[];
    for (final r in resources) {
      if (r.synopsis == null || r.synopsis!.isEmpty) continue;
      final hls = MarkdownParser.extractHighlights(r.synopsis!);
      highlights.addAll(hls.take(2).map((h) => (r: r, text: h.text, tag: h.tag)));
    }
    if (highlights.isEmpty) return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.fromLTRB(16,16,16,8),
        child: Text('✨ HIGHLIGHTS RECENTES', style: TextStyle(fontSize: 10,
          fontWeight: FontWeight.w700, letterSpacing: 0.10,
          color: AppTheme.textMutedColor(context)))),
      ...highlights.map((hl) => Padding(
        padding: const EdgeInsets.fromLTRB(16,0,16,8),
        child: GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => UniversalDetailView(object: hl.r))),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: _resourceColor(hl.r).withOpacity(0.08),
              border: Border(left: BorderSide(color: _resourceColor(hl.r), width: 2)),
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(8), bottomRight: Radius.circular(8))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${_resourceEmoji(hl.r)} ${hl.r.title}${hl.tag != null ? " · #${hl.tag}" : ""}',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                  color: _resourceColor(hl.r))),
              const SizedBox(height: 3),
              Text('"${hl.text}"', style: TextStyle(fontSize: 10,
                color: AppTheme.textSecondaryColor(context),
                height: 1.55, fontStyle: FontStyle.italic)),
            ]))))),
    ]);
  }

  Color _resourceColor(Resource r) => switch (r.resourceType.toLowerCase()) {
    'podcast' => AppColors.info, 'book' || 'livro' => AppColors.primary,
    _ => AppColors.habitPurple };

  String _resourceEmoji(Resource r) => switch (r.resourceType.toLowerCase()) {
    'book' || 'livro' => '📗', 'podcast' => '🎙️',
    'movie' || 'filme' => '🎬', 'article' => '📄', _ => '📚',
  };

  Widget _buildResourceListTile(BuildContext context, Resource resource) {
    return GestureDetector(
      onTap: () {
        context.push('/detail/${resource.id}', extra: {'object': resource});
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: AppTheme.cardDecoration(context),
        child: ListTile(
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
              image:
                  resource.coverImage != null &&
                      resource.coverImage!.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(resource.coverImage!),
                      fit: BoxFit.cover,
                      onError: (_, _) {},
                    )
                  : null,
            ),
            child:
                resource.coverImage == null || resource.coverImage!.isEmpty
                ? _fallbackIcon(resource)
                : null,
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
              Text(
                resource.author ?? 'Unknown',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 2),
              _buildRatingRow(resource),
            ],
          ),
          trailing: const Icon(Icons.chevron_right_rounded, size: 20),
        ),
      ),
    );
  }

  Widget _buildRatingRow(Resource resource) {
    return Row(
      children: List.generate(
        5,
        (i) => Icon(
          Icons.star_rounded,
          size: 16,
          color: i < resource.rating
              ? AppColors.warning
              : AppColors.textMuted.withOpacity(0.2),
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
}

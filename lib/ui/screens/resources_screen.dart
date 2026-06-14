// lib/ui/screens/resources_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/vault_provider.dart';
import '../../providers/settings_provider.dart';
import '../../models/resource_model.dart';
import '../theme.dart';
import '../forms/create_resource_form.dart';
import '../widgets/empty_state.dart';
import '../widgets/object_action_wrapper.dart';
import '../widgets/rich_text_editor.dart';
import 'universal_detail_view.dart';

class ResourcesScreen extends ConsumerStatefulWidget {
  const ResourcesScreen({super.key});

  @override
  ConsumerState<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends ConsumerState<ResourcesScreen> {
  bool _isGridView = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Set<String> _selectedTypes = {};
  final Set<ResourceStatus> _selectedStatuses = {};
  final Set<String> _selectedCategories = {};
  String _sortBy = 'manual'; // manual, title, rating, modified
  bool _sortAscending = true;
  String? _expandedResourceId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resources = ref.watch(resourcesProvider);
    final settings = ref.watch(settingsProvider);

    final categories =
        resources
            .map((resource) => resource.category?.trim())
            .whereType<String>()
            .where((category) => category.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    List<Resource> filtered = resources.where((resource) {
      if (_selectedTypes.isNotEmpty &&
          !_selectedTypes.contains(resource.resourceType)) {
        return false;
      }
      if (_selectedStatuses.isNotEmpty &&
          !_selectedStatuses.contains(resource.status)) {
        return false;
      }
      if (_selectedCategories.isNotEmpty &&
          !_selectedCategories.contains(resource.category?.trim())) {
        return false;
      }
      if (_searchQuery.trim().isNotEmpty) {
        final query = _searchQuery.toLowerCase().trim();
        final haystack = [
          resource.title,
          resource.author,
          resource.category,
          resource.resourceType,
          resource.synopsis,
          ...resource.tags,
          ...resource.aliases,
        ].whereType<String>().join(' ').toLowerCase();
        if (!haystack.contains(query)) return false;
      }
      return true;
    }).toList();

    // Sorting
    filtered.sort((a, b) {
      final result = switch (_sortBy) {
        'manual' => (a.order ?? 0).compareTo(b.order ?? 0),
        'title' => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        'status' => a.status.name.compareTo(b.status.name),
        'type' => a.resourceType.toLowerCase().compareTo(
          b.resourceType.toLowerCase(),
        ),
        'category' => (a.category ?? '').toLowerCase().compareTo(
          (b.category ?? '').toLowerCase(),
        ),
        'rating' => a.rating.compareTo(b.rating),
        'modified' || _ => a.updatedAt.compareTo(b.updatedAt),
      };
      return _sortAscending ? result : -result;
    });

    final types =
        settings.resourceTypeFilters
            .where((t) => t.trim().isNotEmpty)
            .toSet()
            .toList()
          ..sort();

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
              _buildDisplaySettingsButton(),
              _buildSortButton(),
              IconButton(
                icon: const Icon(Icons.tune_rounded),
                tooltip: 'Editar filtros',
                onPressed: () => _showFilterEditor(types),
              ),
              IconButton(
                icon: Icon(
                  _isGridView
                      ? Icons.view_list_rounded
                      : Icons.grid_view_rounded,
                ),
                onPressed: () => setState(() => _isGridView = !_isGridView),
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
                  _clearFilterChip(),
                  ...types.map(
                    (type) => _filterChip(
                      type,
                      _selectedTypes.contains(type),
                      () => setState(() {
                        if (!_selectedTypes.add(type)) {
                          _selectedTypes.remove(type);
                        }
                      }),
                    ),
                  ),
                  ...ResourceStatus.values.map(
                    (status) => _filterChip(
                      _statusLabel(status),
                      _selectedStatuses.contains(status),
                      () => setState(() {
                        if (!_selectedStatuses.add(status)) {
                          _selectedStatuses.remove(status);
                        }
                      }),
                    ),
                  ),
                  ...categories.map(
                    (category) => _filterChip(
                      category,
                      _selectedCategories.contains(category),
                      () => setState(() {
                        if (!_selectedCategories.add(category)) {
                          _selectedCategories.remove(category);
                        }
                      }),
                    ),
                  ),
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
          else if (_isGridView)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.65,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) =>
                      _buildResourceCard(context, filtered[index]),
                  childCount: filtered.length,
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverReorderableList(
                itemBuilder: (context, index) => Padding(
                  key: ValueKey(filtered[index].id),
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildResourceListTile(context, filtered[index]),
                ),
                itemCount: filtered.length,
                onReorder: (oldIndex, newIndex) {
                  if (_sortBy != 'manual') return;
                  _onReorder(filtered, oldIndex, newIndex);
                },
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

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

  Widget _buildSortButton() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.sort_rounded),
      onSelected: (val) => setState(() {
        if (val == 'direction') {
          _sortAscending = !_sortAscending;
        } else {
          _sortBy = val;
        }
      }),
      itemBuilder: (ctx) => [
        const PopupMenuItem(value: 'manual', child: Text('Sort Manually')),
        const PopupMenuItem(value: 'modified', child: Text('Sort by Modified')),
        const PopupMenuItem(value: 'rating', child: Text('Sort by Rating')),
        const PopupMenuItem(value: 'title', child: Text('Sort by Title')),
        const PopupMenuItem(value: 'status', child: Text('Sort by Status')),
        const PopupMenuItem(value: 'type', child: Text('Sort by Type')),
        const PopupMenuItem(value: 'category', child: Text('Sort by Category')),
        PopupMenuItem(
          value: 'direction',
          child: Text(_sortAscending ? 'Direction: Asc' : 'Direction: Desc'),
        ),
      ],
    );
  }

  Widget _buildDisplaySettingsButton() {
    final settings = ref.watch(settingsProvider);
    final visibleFields = settings.visibleResourceFields;

    return PopupMenuButton<String>(
      icon: const Icon(Icons.settings_display_rounded),
      tooltip: 'Display Settings',
      onSelected: (val) {
        final newFields = List<String>.from(visibleFields);
        if (newFields.contains(val)) {
          newFields.remove(val);
        } else {
          newFields.add(val);
        }
        ref
            .read(settingsProvider.notifier)
            .updateVisibleResourceFields(newFields);
      },
      itemBuilder: (ctx) => [
        CheckedPopupMenuItem(
          value: 'author',
          checked: visibleFields.contains('author'),
          child: const Text('Show Author'),
        ),
        CheckedPopupMenuItem(
          value: 'rating',
          checked: visibleFields.contains('rating'),
          child: const Text('Show Rating'),
        ),
        CheckedPopupMenuItem(
          value: 'type',
          checked: visibleFields.contains('type'),
          child: const Text('Show Type'),
        ),
      ],
    );
  }

  void _onReorder(List<Resource> list, int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = list.removeAt(oldIndex);
      list.insert(newIndex, item);

      // Update order field for all items in the list to persist
      for (int i = 0; i < list.length; i++) {
        final current = list[i];
        if (current.order != i) {
          final updated = current.copyWith(order: i);
          ref.read(vaultProvider.notifier).updateObject(updated);
        }
      }
    });
  }

  Widget _clearFilterChip() {
    final selected =
        _selectedTypes.isEmpty &&
        _selectedStatuses.isEmpty &&
        _selectedCategories.isEmpty;
    return _filterChip('Todos', selected, () {
      setState(() {
        _selectedTypes.clear();
        _selectedStatuses.clear();
        _selectedCategories.clear();
      });
    });
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : AppTheme.surfaceVariantColor(context),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected
                ? Colors.white
                : AppTheme.textSecondaryColor(context),
          ),
        ),
      ),
    );
  }

  void _showFilterEditor(List<String> currentTypes) {
    final controller = TextEditingController();
    final filters = List<String>.from(currentTypes);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          void addFilter() {
            final value = controller.text.trim();
            if (value.isEmpty || filters.contains(value)) return;
            setSheetState(() {
              filters.add(value);
              filters.sort();
              controller.clear();
            });
          }

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                16 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Filtros de recursos',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => addFilter(),
                          decoration: const InputDecoration(
                            hintText: 'Novo filtro',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        icon: const Icon(Icons.add_rounded),
                        onPressed: addFilter,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: filters.length,
                      itemBuilder: (context, index) {
                        final filter = filters[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            filter,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () async {
                              final updated = await _editFilterName(filter);
                              if (updated == null || updated.isEmpty) return;
                              setSheetState(() => filters[index] = updated);
                            },
                          ),
                          leading: IconButton(
                            icon: const Icon(Icons.delete_outline_rounded),
                            color: AppColors.error,
                            onPressed: () => setSheetState(() {
                              _selectedTypes.remove(filter);
                              filters.removeAt(index);
                            }),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        ref
                            .read(settingsProvider.notifier)
                            .updateResourceTypeFilters(filters);
                        Navigator.pop(context);
                        setState(() {});
                      },
                      child: const Text('Salvar filtros'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).whenComplete(controller.dispose);
  }

  String _statusLabel(ResourceStatus status) {
    return switch (status) {
      ResourceStatus.toConsume => 'Para ler',
      ResourceStatus.inProgress => 'Lendo',
      ResourceStatus.completed => 'Concluído',
      ResourceStatus.dropped => 'Abandonado',
    };
  }

  Future<String?> _editFilterName(String current) async {
    final controller = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar filtro'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Nome do filtro'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Widget _buildResourceCard(BuildContext context, Resource resource) {
    return ObjectActionWrapper(
      object: resource,
      child: InkWell(
        onTap: () => context.push('/detail/${resource.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: AppTheme.cardDecoration(context),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  color: AppColors.surfaceVariant,
                  child:
                      resource.coverImage != null &&
                          resource.coverImage!.isNotEmpty
                      ? Image.network(
                          resource.coverImage!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.broken_image_outlined,
                            color: AppColors.textMuted,
                          ),
                        )
                      : const Icon(
                          Icons.local_library_rounded,
                          color: AppColors.textMuted,
                          size: 40,
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      resource.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    const SizedBox(height: 4),
                    if (ref
                        .watch(settingsProvider)
                        .visibleResourceFields
                        .contains('author'))
                      Text(
                        resource.author ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (ref
                        .watch(settingsProvider)
                        .visibleResourceFields
                        .contains('author'))
                      const SizedBox(height: 4),
                    if (ref
                        .watch(settingsProvider)
                        .visibleResourceFields
                        .contains('rating')) ...[
                      _buildRatingRow(resource),
                      const SizedBox(height: 6),
                    ],
                    if (ref
                        .watch(settingsProvider)
                        .visibleResourceFields
                        .contains('type'))
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: AppTheme.badgeDecoration(AppColors.info),
                        child: Text(
                          resource.resourceType.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: AppColors.info,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResourceListTile(BuildContext context, Resource resource) {
    final isExpanded = _expandedResourceId == resource.id;

    return ObjectActionWrapper(
      object: resource,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: AppTheme.cardDecoration(context),
        child: Column(
          children: [
            ListTile(
              onTap: () => context.push('/detail/${resource.id}'),
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
                    ? const Icon(
                        Icons.local_library_rounded,
                        color: AppColors.textMuted,
                      )
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
                  if (ref
                      .watch(settingsProvider)
                      .visibleResourceFields
                      .contains('author'))
                    Text(
                      resource.author ?? 'Unknown',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  if (ref
                      .watch(settingsProvider)
                      .visibleResourceFields
                      .contains('rating')) ...[
                    const SizedBox(height: 2),
                    _buildRatingRow(resource),
                  ],
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      isExpanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 20,
                    ),
                    onPressed: () => setState(() {
                      _expandedResourceId = isExpanded ? null : resource.id;
                    }),
                  ),
                  IconButton(
                    icon: const Icon(Icons.open_in_new_rounded, size: 20),
                    tooltip: 'Open in Obsidian',
                    onPressed: () => _openInObsidian(resource),
                  ),
                ],
              ),
            ),
            if (isExpanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Container(
                  height: 150,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).scaffoldBackgroundColor.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.divider.withValues(alpha: 0.5),
                    ),
                  ),
                  child: RichTextEditor(
                    content: resource.synopsis ?? '',
                    expands: true,
                    placeholder: 'Add your thoughts about this resource...',
                    onChanged: (newContent) {
                      final updated = resource.copyWith(
                        synopsis: newContent,
                        updatedAt: DateTime.now(),
                      );
                      ref.read(vaultProvider.notifier).updateObject(updated);
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingRow(Resource resource) {
    return Row(
      children: List.generate(
        5,
        (i) => GestureDetector(
          onTap: () {
            final newResource = resource.copyWith(rating: i + 1);
            ref.read(vaultProvider.notifier).updateObject(newResource);
          },
          child: Icon(
            Icons.star_rounded,
            size: 16,
            color: i < resource.rating
                ? AppColors.warning
                : AppColors.textMuted.withValues(alpha: 0.2),
          ),
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

  Future<void> _openInObsidian(Resource resource) async {
    if (resource.obsidianPath.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This resource has not been saved yet.')),
      );
      return;
    }

    final settings = ref.read(settingsProvider);
    final uri = Uri.parse(
      'obsidian://open?vault=${Uri.encodeComponent(settings.vaultName)}&file=${Uri.encodeComponent(resource.obsidianPath)}',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open in Obsidian.')),
      );
    }
  }
}

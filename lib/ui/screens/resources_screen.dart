// lib/ui/screens/resources_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  String _selectedType = 'All';
  String _sortBy = 'manual'; // manual, title, rating, modified
  String? _expandedResourceId;

  @override
  Widget build(BuildContext context) {
    final resources = ref.watch(resourcesProvider);
    
    // Filtering
    List<Resource> filtered = _selectedType == 'All'
        ? resources
        : resources.where((r) => r.resourceType == _selectedType).toList();

    // Sorting
    filtered.sort((a, b) {
      switch (_sortBy) {
        case 'manual':
          return (a.order ?? 0).compareTo(b.order ?? 0);
        case 'title':
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        case 'rating':
          return b.rating.compareTo(a.rating);
        case 'modified':
        default:
          final aTime = a.updatedAt ?? a.createdAt ?? DateTime(0);
          final bTime = b.updatedAt ?? b.createdAt ?? DateTime(0);
          return bTime.compareTo(aTime);
      }
    });

    final types = resources.map((r) => r.resourceType).toSet().toList()..sort();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: const Text('Media & Resources'),
            floating: true,
            pinned: true,
            actions: [
              _buildDisplaySettingsButton(),
              _buildSortButton(),
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
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  _filterChip('All', _selectedType == 'All'),
                  ...types.map((t) => _filterChip(t, _selectedType == t)),
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

  Widget _buildSortButton() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.sort_rounded),
      onSelected: (val) => setState(() => _sortBy = val),
      itemBuilder: (ctx) => [
        const PopupMenuItem(value: 'manual', child: Text('Sort Manually')),
        const PopupMenuItem(value: 'modified', child: Text('Sort by Modified')),
        const PopupMenuItem(value: 'rating', child: Text('Sort by Rating')),
        const PopupMenuItem(value: 'title', child: Text('Sort by Title')),
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
        ref.read(settingsProvider.notifier).updateVisibleResourceFields(newFields);
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

  Widget _filterChip(String label, bool selected) {
    return GestureDetector(
      onTap: () => setState(() => _selectedType = label),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppTheme.surfaceVariantColor(context),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppTheme.textSecondaryColor(context),
          ),
        ),
      ),
    );
  }

  Widget _buildResourceCard(BuildContext context, Resource resource) {
    return ObjectActionWrapper(
      object: resource,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UniversalDetailView(object: resource),
          ),
        ),
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
                  child: resource.coverImage != null && resource.coverImage!.isNotEmpty
                      ? Image.network(
                          resource.coverImage!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
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
                    if (ref.watch(settingsProvider).visibleResourceFields.contains('author'))
                      Text(
                        resource.author ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (ref.watch(settingsProvider).visibleResourceFields.contains('author'))
                      const SizedBox(height: 4),
                    if (ref.watch(settingsProvider).visibleResourceFields.contains('rating')) ...[
                      _buildRatingRow(resource),
                      const SizedBox(height: 6),
                    ],
                    if (ref.watch(settingsProvider).visibleResourceFields.contains('type'))
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
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UniversalDetailView(object: resource),
                ),
              ),
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                  image: resource.coverImage != null && resource.coverImage!.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(resource.coverImage!),
                          fit: BoxFit.cover,
                          onError: (_, __) {},
                        )
                      : null,
                ),
                child: resource.coverImage == null || resource.coverImage!.isEmpty
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
                  if (ref.watch(settingsProvider).visibleResourceFields.contains('author'))
                    Text(
                      resource.author ?? 'Unknown',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  if (ref.watch(settingsProvider).visibleResourceFields.contains('rating')) ...[
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
                      isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
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
                    color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
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


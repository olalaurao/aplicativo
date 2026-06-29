// lib/ui/screens/organizer_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/organizer_model.dart';
import '../../models/content_object.dart';
import '../../models/note_model.dart';
import '../../models/social_post.dart';
import '../../providers/vault_provider.dart';
import '../../providers/wiki_link_resolver_provider.dart';
import '../theme.dart';
import '../widgets/object_action_wrapper.dart';
import '../widgets/social_post_grid_card.dart';
import 'social_post_detail.dart';
import 'universal_detail_view.dart';
import '../forms/create_organizer_form.dart';
import '../forms/create_task_form.dart';
import '../forms/create_note_form.dart';
import '../forms/create_goal_form.dart';
import '../forms/create_habit_form.dart';
import '../forms/create_resource_form.dart';
import '../forms/create_project_form.dart';
import '../../models/shared_types.dart';

class OrganizerDetailScreen extends ConsumerStatefulWidget {
  final Organizer organizer;

  const OrganizerDetailScreen({super.key, required this.organizer});

  @override
  ConsumerState<OrganizerDetailScreen> createState() =>
      _OrganizerDetailScreenState();
}

class _SocialPostMiniCard extends StatelessWidget {
  final SocialPost post;

  const _SocialPostMiniCard({required this.post});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SocialPostDetail(post: post)),
      ),
      child: SizedBox(
        width: 80,
        height: 120,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            fit: StackFit.expand,
            children: [
              SocialPostThumbnail(post: post, borderRadius: BorderRadius.zero),
              Positioned(
                left: 6,
                right: 6,
                bottom: 6,
                child: SocialPlatformBadge(
                  platform: post.platform,
                  fontSize: 8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrganizerProperty {
  final String label;
  final String value;
  final IconData icon;

  const _OrganizerProperty({
    required this.label,
    required this.value,
    required this.icon,
  });
}

class _PropertyCell extends StatelessWidget {
  final _OrganizerProperty property;
  final Color color;

  const _PropertyCell({required this.property, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(property.icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                property.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                property.value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimaryColor(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OrganizerDetailScreenState extends ConsumerState<OrganizerDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedPeriod = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final associatedItemsAsync = ref.watch(
      backlinksProvider(widget.organizer.id),
    );
    final color = widget.organizer.color != null
        ? _parseColor(widget.organizer.color!)
        : AppColors.primary;

    final allItems = associatedItemsAsync.valueOrNull ?? [];
    final outgoingItems = ref.watch(
      wikiLinksForObjectProvider(widget.organizer),
    );
    final timelineCount = allItems.length;
    final itemsCount = allItems.where((i) => i.type != 'social_post').length;
    final notesCount = _notesForOrganizer().length;
    final allOrganizers = ref.watch(organizersProvider);
    final childrenCount = allOrganizers
        .where((o) => o.parentId == widget.organizer.id)
        .length;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                tooltip: 'Editar',
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          CreateOrganizerForm(organizer: widget.organizer),
                    ),
                  );
                },
              ),
              IconButton(
                tooltip: 'Ver detalhes',
                icon: const Icon(Icons.info_outline_rounded, size: 20),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          UniversalDetailView(object: widget.organizer),
                    ),
                  );
                },
              ),
            ],
          ),

          // ─── Header ───
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Colored icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      _typeIcon(widget.organizer.organizerType),
                      size: 24,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.organizer.title,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: AppTheme.chipDecoration(color),
                    child: Text(
                      widget.organizer.organizerType.name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ),
                  if (widget.organizer.parentId != null) ...[
                    const SizedBox(height: 12),
                    Consumer(
                      builder: (context, ref, _) {
                        final parent = ref
                            .watch(organizersProvider)
                            .where((o) => o.id == widget.organizer.parentId)
                            .firstOrNull;
                        if (parent == null) return const SizedBox.shrink();
                        return InkWell(
                          onTap: () => Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  OrganizerDetailScreen(organizer: parent),
                            ),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.arrow_upward_rounded,
                                  size: 14,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Parent: ${parent.title}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 20),
                  _buildPropertiesCard(color),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // ─── Tab Bar ───
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(3),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textMuted,
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                tabs: [
                  Tab(
                    text:
                        'Timeline${timelineCount > 0 ? " ($timelineCount)" : ""}',
                  ),
                  Tab(text: 'Items${itemsCount > 0 ? " ($itemsCount)" : ""}'),
                  Tab(
                    text:
                        'Outgoing${outgoingItems.isNotEmpty ? " (${outgoingItems.length})" : ""}',
                  ),
                  Tab(
                    text:
                        'Children${childrenCount > 0 ? " ($childrenCount)" : ""}',
                  ),
                  Tab(text: 'Notes${notesCount > 0 ? " ($notesCount)" : ""}'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildTimeline(context, associatedItemsAsync),
            _buildItemsList(context, associatedItemsAsync),
            _buildOutgoingList(context, outgoingItems),
            _buildChildrenList(context),
            _buildNotesList(context),
          ],
        ),
      ),
      bottomNavigationBar: _buildAddButtons(context),
    );
  }

  Widget _buildPropertiesCard(Color color) {
    final properties = _organizerProperties();
    if (properties.isEmpty) return const SizedBox.shrink();

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CreateOrganizerForm(organizer: widget.organizer),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardFillColor(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.dividerColor(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune_rounded, size: 16, color: color),
                const SizedBox(width: 8),
                const Text(
                  'PROPERTIES',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final property in properties)
                      SizedBox(
                        width: itemWidth,
                        child: _PropertyCell(property: property, color: color),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  List<_OrganizerProperty> _organizerProperties() {
    final organizer = widget.organizer;
    final properties = <_OrganizerProperty>[
      _OrganizerProperty(
        label: 'NAME',
        value: organizer.title,
        icon: _typeIcon(organizer.organizerType),
      ),
      _OrganizerProperty(
        label: 'TYPE',
        value: organizer.organizerType.name,
        icon: Icons.category_outlined,
      ),
    ];

    if (organizer.icon?.trim().isNotEmpty == true) {
      properties.add(
        _OrganizerProperty(
          label: 'ICON',
          value: organizer.icon!,
          icon: Icons.emoji_symbols_outlined,
        ),
      );
    }
    if (organizer.state?.trim().isNotEmpty == true) {
      properties.add(
        _OrganizerProperty(
          label: 'STATE',
          value: organizer.state!,
          icon: Icons.flag_outlined,
        ),
      );
    }
    if (organizer.priority?.trim().isNotEmpty == true) {
      properties.add(
        _OrganizerProperty(
          label: 'PRIORITY',
          value: organizer.priority!,
          icon: Icons.local_fire_department_outlined,
        ),
      );
    }
    if (organizer.startDate != null) {
      properties.add(
        _OrganizerProperty(
          label: 'START',
          value: DateFormat('MMM d, yyyy').format(organizer.startDate!),
          icon: Icons.play_arrow_rounded,
        ),
      );
    }
    if (organizer.endDate != null) {
      properties.add(
        _OrganizerProperty(
          label: 'DUE',
          value: DateFormat('MMM d, yyyy').format(organizer.endDate!),
          icon: Icons.event_outlined,
        ),
      );
    }
    if (organizer.parentId?.trim().isNotEmpty == true) {
      final parent = ref
          .read(organizersProvider)
          .where((item) => item.id == organizer.parentId)
          .firstOrNull;
      properties.add(
        _OrganizerProperty(
          label: 'PARENT',
          value: parent?.title ?? organizer.parentId!,
          icon: Icons.account_tree_outlined,
        ),
      );
    }

    return properties;
  }

  Widget _buildTimeline(
    BuildContext context,
    AsyncValue<List<ContentObject>> itemsAsync,
  ) {
    return itemsAsync.when(
      data: (items) {
        final filteredItems = _filterItemsByPeriod(items);
        if (filteredItems.isEmpty) {
          return _buildEmptyState(
            'No activity yet',
            'Content tagged to this organizer will appear here',
          );
        }
        final sortedItems = filteredItems.toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: sortedItems.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) return _buildPeriodSelector();
            final itemIndex = index - 1;
            final item = sortedItems[itemIndex];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ObjectActionWrapper(
                object: item,
                child: InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UniversalDetailView(object: item),
                    ),
                  ),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: AppTheme.cardDecorationFlat(context),
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Icon(
                          _objectTypeIcon(_getObjectCategory(item)),
                          size: 20,
                          color: _objectTypeColor(_getObjectCategory(item)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_objectTypeLabel(_getObjectCategory(item))} • ${DateFormat('MMM d').format(item.createdAt)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: AppColors.textMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildPeriodSelector() {
    const periods = [('7d', '7d'), ('1m', '1m'), ('3m', '3m'), ('all', 'All')];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final period in periods) ...[
              FilterChip(
                label: Text(period.$2),
                selected: _selectedPeriod == period.$1,
                showCheckmark: false,
                side: BorderSide.none,
                selectedColor: AppColors.accent,
                backgroundColor: AppColors.surfaceVariant,
                labelStyle: TextStyle(
                  color: _selectedPeriod == period.$1
                      ? Colors.white
                      : AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
                onSelected: (_) {
                  setState(() => _selectedPeriod = period.$1);
                },
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }

  List<ContentObject> _filterItemsByPeriod(List<ContentObject> items) {
    final now = DateTime.now();
    final cutoff = switch (_selectedPeriod) {
      '7d' => now.subtract(const Duration(days: 7)),
      '1m' => DateTime(now.year, now.month - 1, now.day),
      '3m' => DateTime(now.year, now.month - 3, now.day),
      _ => null,
    };
    if (cutoff == null) return items;
    return items.where((item) {
      final relevantDate = item.updatedAt.isAfter(item.createdAt)
          ? item.updatedAt
          : item.createdAt;
      return !relevantDate.isBefore(cutoff);
    }).toList();
  }

  Widget _buildItemsList(
    BuildContext context,
    AsyncValue<List<ContentObject>> itemsAsync,
  ) {
    return itemsAsync.when(
      data: (items) {
        final socialPosts = _postsForOrganizer();
        final visibleItems = items
            .where((item) => item is! SocialPost && item.type != 'social_post')
            .toList();
        if (visibleItems.isEmpty && socialPosts.isEmpty) {
          return _buildEmptyState(
            'No items',
            'Items associated with this organizer will appear here',
          );
        }

        final grouped = <String, List<ContentObject>>{};
        for (final item in visibleItems) {
          grouped.putIfAbsent(_getObjectCategory(item), () => []).add(item);
        }

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (socialPosts.isNotEmpty) ...[
              _buildSocialPostsSection(socialPosts),
              const SizedBox(height: 18),
            ],
            ...grouped.entries.map((entry) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, top: 8),
                    child: Text(
                      _objectTypeLabel(entry.key),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  ...entry.value.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: ObjectActionWrapper(
                        object: item,
                        child: InkWell(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => UniversalDetailView(object: item),
                            ),
                          ),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: AppTheme.cardDecorationFlat(context),
                            child: Row(
                              children: [
                                Icon(
                                  _objectTypeIcon(_getObjectCategory(item)),
                                  size: 18,
                                  color: _objectTypeColor(
                                    _getObjectCategory(item),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    item.title,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  size: 18,
                                  color: AppColors.textMuted,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildOutgoingList(BuildContext context, List<ContentObject> items) {
    if (items.isEmpty) {
      return _buildEmptyState(
        'No outgoing links',
        'Wiki-links in this organizer body will appear here',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ObjectActionWrapper(
            object: item,
            child: InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UniversalDetailView(object: item),
                ),
              ),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: AppTheme.cardDecorationFlat(context),
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(
                      _objectTypeIcon(_getObjectCategory(item)),
                      size: 20,
                      color: _objectTypeColor(_getObjectCategory(item)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildChildrenList(BuildContext context) {
    final allOrganizers = ref.watch(organizersProvider);
    final children = allOrganizers
        .where((o) => o.parentId == widget.organizer.id)
        .toList();

    if (children.isEmpty) {
      return _buildEmptyState(
        'No sub-organizers',
        'Organizers that have this as a parent will appear here',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: children.length,
      itemBuilder: (context, index) {
        final item = children[index];
        final itemColor = item.color != null
            ? _parseColor(item.color!)
            : AppColors.primary;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OrganizerDetailScreen(organizer: item),
              ),
            ),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: AppTheme.cardDecorationFlat(context),
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: itemColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _typeIcon(item.organizerType),
                      size: 16,
                      color: itemColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotesList(BuildContext context) {
    final notes = _notesForOrganizer();
    if (notes.isEmpty) {
      return _buildEmptyState(
        'No notes linked to this ${widget.organizer.organizerType.name} yet.',
        'Notes associated with this organizer will appear here',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ObjectActionWrapper(
            object: note,
            child: InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UniversalDetailView(object: note),
                ),
              ),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: AppTheme.cardDecorationFlat(context),
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Text(
                      _noteSubtypeIcon(note.subtype),
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            note.displayTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _notePreview(note),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _relativeDate(note.updatedAt),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<Note> _notesForOrganizer() {
    return ref
        .watch(notesProvider)
        .where(
          (note) => note.organizers.any(
            (organizer) => organizer.matches(
              widget.organizer.id,
              widget.organizer.slug,
              widget.organizer.title,
            ),
          ),
        )
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  String _noteSubtypeIcon(NoteSubtype subtype) {
    return switch (subtype) {
      NoteSubtype.text => '📝',
      NoteSubtype.outline => '🗂',
      NoteSubtype.collection => '🗃',
    };
  }

  String _notePreview(Note note) {
    final normalized = note.body
        .replaceAll(RegExp(r'[#*_`\[\]{}]'), '')
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .join(' ');
    return normalized.isEmpty ? note.subtype.name : normalized;
  }

  String _relativeDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays == 0) return 'today';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 30) return '${diff.inDays}d';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo';
    return '${(diff.inDays / 365).floor()}y';
  }

  List<SocialPost> _postsForOrganizer() {
    final posts = ref.watch(socialPostsProvider);
    return posts
        .where(
          (post) => post.organizers.any(
            (organizer) => organizer.matches(
              widget.organizer.id,
              widget.organizer.slug,
              widget.organizer.title,
            ),
          ),
        )
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Widget _buildSocialPostsSection(List<SocialPost> posts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'POSTS SOCIAIS',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: posts.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) =>
                _SocialPostMiniCard(post: posts[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 48,
            color: AppColors.textMuted.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  IconData _typeIcon(OrganizerType type) {
    switch (type) {
      case OrganizerType.area:
        return Icons.layers_outlined;
      case OrganizerType.project:
        return Icons.folder_outlined;
      case OrganizerType.activity:
        return Icons.sports_outlined;
      case OrganizerType.person:
        return Icons.person_outline_rounded;
      case OrganizerType.place:
        return Icons.place_outlined;
      case OrganizerType.label:
        return Icons.label_outline_rounded;
      case OrganizerType.task:
        return Icons.check_circle_outline;
      case OrganizerType.goal:
        return Icons.flag_rounded;
      case OrganizerType.habit:
        return Icons.loop_rounded;
      case OrganizerType.tracker:
        return Icons.analytics_outlined;
    }
  }

  String _getObjectCategory(ContentObject item) {
    if (item is Organizer) {
      return item.organizerType.name;
    }
    return item.type;
  }

  IconData _objectTypeIcon(String type) {
    switch (type) {
      case 'task':
        return Icons.check_circle_outline;
      case 'habit':
        return Icons.cached_rounded;
      case 'goal':
        return Icons.flag_outlined;
      case 'entry':
        return Icons.auto_stories_rounded;
      case 'calendar_session':
        return Icons.calendar_today_outlined;
      case 'area':
        return Icons.layers_outlined;
      case 'project':
        return Icons.folder_outlined;
      case 'activity':
        return Icons.sports_outlined;
      case 'person':
        return Icons.person_outline_rounded;
      case 'place':
        return Icons.place_outlined;
      case 'label':
        return Icons.label_outline_rounded;
      default:
        return Icons.article_outlined;
    }
  }

  Color _objectTypeColor(String type) {
    switch (type) {
      case 'task':
        return AppColors.info;
      case 'habit':
        return AppColors.habitGreen;
      case 'goal':
        return AppColors.habitOrange;
      case 'entry':
        return AppColors.habitPurple;
      case 'calendar_session':
        return AppColors.primary;
      case 'area':
        return AppColors.primary;
      case 'project':
        return AppColors.priorityHigh;
      case 'activity':
        return AppColors.habitGreen;
      case 'person':
        return AppColors.habitPink;
      case 'place':
        return AppColors.info;
      case 'label':
        return AppColors.textSecondary;
      default:
        return AppColors.textSecondary;
    }
  }

  String _objectTypeLabel(String type) {
    switch (type) {
      case 'task':
        return 'Tasks';
      case 'habit':
        return 'Habits';
      case 'goal':
        return 'Goals';
      case 'entry':
        return 'Journal';
      case 'calendar_session':
        return 'Sessions';
      case 'area':
        return 'Áreas';
      case 'project':
        return 'Projetos';
      case 'activity':
        return 'Atividades';
      case 'label':
        return 'Etiquetas';
      case 'person':
        return 'Pessoas';
      case 'place':
        return 'Lugares';
      default:
        return type.isEmpty
            ? ''
            : type.substring(0, 1).toUpperCase() + type.substring(1);
    }
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceAll('#', '0xFF')));
    } catch (_) {
      return AppColors.primary;
    }
  }

  Widget _buildAddButtons(BuildContext context) {
    final refRef = OrganizerReference(
      slug: widget.organizer.slug,
      title: widget.organizer.title,
      type: widget.organizer.type,
    );

    Widget chipButton({
      required String label,
      required IconData icon,
      required Color color,
      required VoidCallback onTap,
    }) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ActionChip(
          onPressed: onTap,
          avatar: Icon(icon, size: 16, color: color),
          label: Text(label),
          labelStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimaryColor(context),
          ),
          backgroundColor: color.withValues(alpha: 0.08),
          side: BorderSide(color: color.withValues(alpha: 0.2)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      );
    }

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: AppTheme.cardFillColor(context),
        border: Border(
          top: BorderSide(color: AppTheme.dividerColor(context), width: 0.5),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Text(
              'Add to Organizer:',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppTheme.textMutedColor(context),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 12),
            chipButton(
              label: 'Tarefa',
              icon: Icons.check_circle_outline,
              color: AppColors.info,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreateTaskForm(
                    initialOrganizers: [refRef],
                  ),
                ),
              ),
            ),
            chipButton(
              label: 'Nota',
              icon: Icons.article_outlined,
              color: AppColors.habitPurple,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreateNoteForm(
                    initialOrganizers: [refRef],
                  ),
                ),
              ),
            ),
            chipButton(
              label: 'Objetivo',
              icon: Icons.flag_outlined,
              color: AppColors.habitOrange,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreateGoalForm(
                    initialOrganizers: [refRef],
                  ),
                ),
              ),
            ),
            chipButton(
              label: 'Hábito',
              icon: Icons.cached_rounded,
              color: AppColors.habitGreen,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreateHabitForm(
                    initialOrganizers: [refRef],
                  ),
                ),
              ),
            ),
            chipButton(
              label: 'Recurso',
              icon: Icons.auto_stories_rounded,
              color: AppColors.habitPink,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreateResourceForm(
                    initialOrganizers: [refRef],
                  ),
                ),
              ),
            ),
            chipButton(
              label: 'Projeto',
              icon: Icons.folder_outlined,
              color: AppColors.primary,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreateProjectForm(
                    initialOrganizers: [refRef],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

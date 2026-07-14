// lib/ui/screens/organize_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/vault_provider.dart';
import '../../models/organizer_model.dart';
import '../theme.dart';
import 'organizer_detail_screen.dart';
import '../forms/create_organizer_form.dart';
import '../../models/content_object.dart';
import '../../models/goal_model.dart';
import '../../models/habit_model.dart';
import '../../models/tracker_model.dart';
import 'universal_detail_view.dart';
import '../widgets/object_action_wrapper.dart';
import '../widgets/overdue_section.dart';

class OrganizeScreen extends ConsumerStatefulWidget {
  const OrganizeScreen({super.key});

  @override
  ConsumerState<OrganizeScreen> createState() => _OrganizeScreenState();
}

class _OrganizeScreenState extends ConsumerState<OrganizeScreen> {
  String _searchQuery = '';
  String _activeFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final allOrganizers = ref.watch(organizersProvider);
    final organizers = allOrganizers
        .where(
          (o) => o.title.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Organizers'),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: CustomScrollView(
        slivers: [
          // ─── Header ───
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppTheme.accentColor(context).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.add_rounded,
                            size: 20,
                            color: AppTheme.accentColor(context),
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CreateOrganizerForm(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Search bar
                  TextField(
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText: 'Search...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      filled: true,
                      fillColor: AppTheme.surfaceVariantColor(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildFilterChips(),
                ],
              ),
            ),
          ),

          // ─── Sections ───
          ..._buildSections(context, organizers),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  List<Widget> _buildSections(
    BuildContext context,
    List<Organizer> organizers,
  ) {
    final allObjects = ref.watch(allObjectsProvider).value ?? [];
    final allGoals = allObjects.whereType<Goal>().toList();
    final goals = allGoals
        .where(
          (o) => o.title.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();

    final allHabits = allObjects.whereType<Habit>().toList();
    final habits = allHabits
        .where(
          (o) => o.title.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();

    final allTrackers = ref.watch(trackersProvider);
    final trackers = allTrackers
        .where(
          (o) => o.title.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();

    final sections = <_OrganizerSection>[
      _OrganizerSection(
        'Areas',
        Icons.layers_outlined,
        AppTheme.accentColor(context),
        organizers.where((o) => o.organizerType == OrganizerType.area).toList(),
      ),
      _OrganizerSection(
        'Projetos',
        Icons.folder_outlined,
        AppColors.info,
        organizers
            .where((o) => o.organizerType == OrganizerType.project)
            .toList(),
      ),
      _OrganizerSection(
        'Goals',
        Icons.track_changes_rounded,
        AppColors.habitOrange,
        goals,
      ),
      _OrganizerSection(
        'Habits',
        Icons.loop_rounded,
        AppColors.habitGreen,
        habits,
      ),
      _OrganizerSection(
        'Trackers',
        Icons.analytics_outlined,
        AppTheme.accentColor(context),
        trackers,
      ),
      _OrganizerSection(
        'Activities',
        Icons.sports_outlined,
        AppColors.habitGreen,
        organizers
            .where((o) => o.organizerType == OrganizerType.activity)
            .toList(),
      ),
      _OrganizerSection(
        'People',
        Icons.people_outline_rounded,
        AppColors.habitPink,
        organizers
            .where((o) => o.organizerType == OrganizerType.person)
            .toList(),
      ),
      _OrganizerSection(
        'Labels',
        Icons.label_outline_rounded,
        AppTheme.textSecondaryColor(context),
        organizers
            .where((o) => o.organizerType == OrganizerType.label)
            .toList(),
      ),
    ];

    final filteredSections = sections.where((s) {
      if (_activeFilter == 'All') return true;
      if (_activeFilter == 'Families') return false; // Handled separately
      if (_activeFilter == 'Goals') return s.title == 'Goals';
      if (_activeFilter == 'Projects') return s.title == 'Projetos';
      if (_activeFilter == 'People') return s.title == 'People';
      return true;
    }).toList();

    final widgets = <Widget>[];

    if (_activeFilter == 'Families') {
      final roots = organizers.where((o) => o.parentId == null).toList();
      final families = roots.map((root) {
        return _OrganizerSection(
          root.title,
          _typeIcon(root.organizerType),
          root.color != null ? _parseColor(root.color!) : AppTheme.accentColor(context),
          [root, ...organizers.where((o) => o.parentId == root.id)],
        );
      }).toList();

      for (final family in families) {
        widgets.add(
          SliverToBoxAdapter(child: _buildSectionCard(context, family)),
        );
      }
    } else {
      for (final section in filteredSections) {
        if (section.items.isEmpty && section.title != 'Projetos') continue;
        if (section.title == 'Projetos') {
          widgets.add(
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: OverdueSection(filterTypes: ['project']),
              ),
            ),
          );
        }
        if (section.items.isEmpty) continue;
        widgets.add(
          SliverToBoxAdapter(child: _buildSectionCard(context, section)),
        );
      }
    }

    if (widgets.isEmpty &&
        (_activeFilter == 'Goals' ||
            _activeFilter == 'Projects' ||
            _activeFilter == 'People')) {
      final emptyLabel = switch (_activeFilter) {
        'Goals' => 'Nenhuma meta encontrada',
        'Projects' => 'Nenhum projeto encontrado',
        'People' => 'Nenhuma pessoa encontrada',
        _ => 'Nenhum item encontrado',
      };
      widgets.add(
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Text(
              _searchQuery.isEmpty ? emptyLabel : 'Nenhum resultado encontrado',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMutedColor(context),
              ),
            ),
          ),
        ),
      );
    }

    if (organizers.isEmpty &&
        goals.isEmpty &&
        habits.isEmpty &&
        trackers.isEmpty) {
      widgets.add(
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.category_outlined,
                  size: 56,
                  color: AppTheme.accentColor(context).withValues(alpha: 0.3),
                ),
                const SizedBox(height: 12),
                Text(
                  _searchQuery.isEmpty
                      ? 'No organizers yet'
                      : 'No results found',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                if (_searchQuery.isEmpty)
                  Text(
                    'Create areas, projects and labels to organize your content',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textMutedColor(context),
                      fontSize: 14,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  Widget _buildSectionCard(BuildContext context, _OrganizerSection section) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        decoration: AppTheme.cardDecoration(context),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: section.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(section.icon, size: 20, color: section.color),
            ),
            title: Row(
              children: [
                Text(
                  section.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariantColor(context),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    section.items.length.toString(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textMutedColor(context),
                    ),
                  ),
                ),
              ],
            ),
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 4,
            ),
            childrenPadding: EdgeInsets.zero,
            initiallyExpanded: _searchQuery.isNotEmpty,
            children: [
              Divider(
                height: 1,
                color: AppTheme.dividerColor(context).withValues(alpha: 0.5),
              ),
              if (section.items.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No items in ${section.title.toLowerCase()} yet',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textMutedColor(context),
                    ),
                  ),
                )
              else
                ...section.items.map(
                  (item) => _buildOrganizerRow(context, item, section.color),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrganizerRow(
    BuildContext context,
    ContentObject item,
    Color sectionColor,
  ) {
    String? itemColorStr;
    if (item is Organizer) itemColorStr = item.color;
    if (item is Goal) itemColorStr = item.color;
    if (item is Habit) itemColorStr = item.color;
    if (item is TrackerDefinition) itemColorStr = item.color;

    return ObjectActionWrapper(
      object: item,
      child: InkWell(
        onTap: () {
          if (item is Organizer) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OrganizerDetailScreen(organizer: item),
              ),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => UniversalDetailView(object: item),
              ),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: itemColorStr != null
                      ? _parseColor(itemColorStr)
                      : sectionColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppTheme.textMutedColor(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = ['All', 'Families', 'Goals', 'Projects', 'People'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters
            .map(
              (f) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(f),
                  selected: _activeFilter == f,
                  onSelected: (val) => setState(() => _activeFilter = f),
                  backgroundColor: Colors.transparent,
                  selectedColor: AppTheme.accentColor(context).withValues(alpha: 0.1),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: _activeFilter == f
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: _activeFilter == f
                        ? AppTheme.accentColor(context)
                        : AppColors.textSecondary,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: _activeFilter == f
                          ? AppTheme.accentColor(context)
                          : AppColors.divider,
                    ),
                  ),
                  showCheckmark: false,
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceAll('#', '0xFF')));
    } catch (_) {
      return AppTheme.accentColor(context);
    }
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
      case OrganizerType.dayTheme:
        return Icons.wb_sunny_outlined;
      case OrganizerType.timeBlock:
        return Icons.timer_outlined;
    }
  }
}

class _OrganizerSection {
  final String title;
  final IconData icon;
  final Color color;
  final List<ContentObject> items;

  _OrganizerSection(this.title, this.icon, this.color, this.items);
}

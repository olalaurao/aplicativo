// lib/ui/widgets/navigation_shortcut_picker.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/vault_provider.dart';
import '../../models/navigation_item.dart';
import '../../models/organizer_model.dart';
import '../theme.dart';

class NavigationShortcutPicker extends ConsumerStatefulWidget {
  const NavigationShortcutPicker({super.key});

  @override
  ConsumerState<NavigationShortcutPicker> createState() =>
      _NavigationShortcutPickerState();
}

class _NavigationShortcutPickerState
    extends ConsumerState<NavigationShortcutPicker> {
  String _searchQuery = '';

  static final List<Map<String, dynamic>> _quickActions = [
    {
      'label': 'New Task',
      'route': '/?action=new_task',
      'type': 'action',
      'icon': Icons.check_circle_outline_rounded,
    },
    {
      'label': 'New Habit',
      'route': '/?action=new_habit',
      'type': 'action',
      'icon': Icons.repeat_rounded,
    },
    {
      'label': 'New Journal Entry',
      'route': '/?action=new_entry',
      'type': 'action',
      'icon': Icons.edit_note_rounded,
    },
    {
      'label': 'Planner',
      'route': '/planner',
      'type': 'screen',
      'icon': Icons.calendar_today_rounded,
    },
    {
      'label': 'Trackers',
      'route': '/trackers',
      'type': 'screen',
      'icon': Icons.analytics_rounded,
    },
    {
      'label': 'Pomodoro',
      'route': '/pomodoro',
      'type': 'screen',
      'icon': Icons.timer_rounded,
    },
    {
      'label': 'Goals',
      'route': '/goals',
      'type': 'screen',
      'icon': Icons.flag_rounded,
    },
    {
      'label': 'Habits',
      'route': '/habits',
      'type': 'screen',
      'icon': Icons.repeat_rounded,
    },
    {
      'label': 'Notes',
      'route': '/notes',
      'type': 'screen',
      'icon': Icons.note_alt_outlined,
    },
    {
      'label': 'People',
      'route': '/people',
      'type': 'screen',
      'icon': Icons.people_outline_rounded,
    },
    {
      'label': 'Resources',
      'route': '/resources',
      'type': 'screen',
      'icon': Icons.folder_outlined,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final allObjectsAsync = ref.watch(allObjectsProvider);
    final organizersAsync = ref.watch(organizersProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: AppTheme.sheetDecoration(context),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Add Shortcut',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Tap any item to add. You can choose to pin it to the footer bar.',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textMutedColor(context),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Search notes, goals, screens...',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: AppColors.surfaceVariant,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: allObjectsAsync.when(
              data: (objects) {
                final organizers = organizersAsync;

                final filteredQuickActions = _quickActions
                    .where((a) => (a['label'] as String)
                        .toLowerCase()
                        .contains(_searchQuery.toLowerCase()))
                    .toList();

                final filteredObjects = objects
                    .where(
                      (o) => o.title
                          .toLowerCase()
                          .contains(_searchQuery.toLowerCase()),
                    )
                    .toList();
                final filteredOrganizers = organizers
                    .where(
                      (Organizer o) => o.title
                          .toLowerCase()
                          .contains(_searchQuery.toLowerCase()),
                    )
                    .toList();

                return ListView(
                  children: [
                    if (filteredQuickActions.isNotEmpty) ...[
                      _buildHeader('Quick Actions & Screens'),
                      ...filteredQuickActions.map(
                        (a) => _buildStaticItem(context, a),
                      ),
                    ],
                    if (filteredOrganizers.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildHeader('Organizers'),
                      ...filteredOrganizers.map(
                        (Organizer o) => _buildItem(
                          context,
                          o.title,
                          o.organizerType.name,
                          o.id,
                          _getIcon(o.organizerType.name),
                          '/organizer/${o.id}',
                        ),
                      ),
                    ],
                    if (filteredObjects.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildHeader('Objects'),
                      ...filteredObjects.map(
                        (o) => _buildItem(
                          context,
                          o.title,
                          o.type,
                          o.id,
                          _getIcon(o.type),
                          '/detail/${o.id}',
                        ),
                      ),
                    ],
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error loading: $e'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textMuted,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Future<void> _pickItem(BuildContext context, NavigationItem newItem) async {
    final pinToFooter = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add "${newItem.label}"'),
        content: const Text(
          'Pin this shortcut to the bottom navigation bar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Only in More'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Pin to Footer',
              style: TextStyle(color: AppTheme.accentColor(context)),
            ),
          ),
        ],
      ),
    );
    if (pinToFooter == null) return;
    final result = NavigationItem(
      section: newItem.section,
      label: newItem.label,
      route: newItem.route,
      inBottomBar: pinToFooter,
      isCustom: true,
      id: newItem.id,
      type: newItem.type,
    );
    if (!context.mounted) return;
    Navigator.pop(context, result);
  }

  Widget _buildStaticItem(BuildContext context, Map<String, dynamic> action) {
    final icon = action['icon'] as IconData;
    final label = action['label'] as String;
    final route = action['route'] as String;
    final type = action['type'] as String;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppTheme.accentColor(context).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: AppTheme.accentColor(context)),
      ),
      title: Text(
        label,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        type.toUpperCase(),
        style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
      ),
      onTap: () {
        final newItem = NavigationItem(
          section: NavSection.shortcut,
          label: label,
          route: route,
          inBottomBar: false,
          isCustom: true,
          id: route,
          type: type,
        );
        _pickItem(context, newItem);
      },
    );
  }

  Widget _buildItem(
    BuildContext context,
    String title,
    String type,
    String id,
    IconData icon,
    String route,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppTheme.accentColor(context).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: AppTheme.accentColor(context)),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        type.toUpperCase(),
        style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
      ),
      onTap: () {
        final newItem = NavigationItem(
          section: NavSection.shortcut,
          label: title,
          route: route,
          inBottomBar: false,
          isCustom: true,
          id: id,
          type: type,
        );
        _pickItem(context, newItem);
      },
    );
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'task':
        return Icons.check_circle_outline_rounded;
      case 'goal':
        return Icons.flag_rounded;
      case 'habit':
        return Icons.repeat_rounded;
      case 'note':
        return Icons.note_alt_outlined;
      case 'area':
        return Icons.category_outlined;
      case 'project':
        return Icons.assignment_rounded;
      case 'person':
        return Icons.person_outline_rounded;
      case 'activity':
        return Icons.local_activity_outlined;
      default:
        return Icons.link_rounded;
    }
  }
}

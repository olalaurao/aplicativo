import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../models/dashboard_block.dart';
import '../../../models/content_object.dart';
import '../../../models/tracker_model.dart';
import '../../../models/mood_model.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/vault_provider.dart';
import '../../../services/component_registry.dart';
import '../../theme.dart';
import '../standard_sheet.dart';
import '../form_section.dart';
import '../app_switch_tile.dart';
import '../app_dropdown.dart';

class DashboardComponentConfigSheet extends ConsumerStatefulWidget {
  final DashboardBlock block;

  const DashboardComponentConfigSheet({super.key, required this.block});

  static Future<void> show(BuildContext context, DashboardBlock block) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DashboardComponentConfigSheet(block: block),
    );
  }

  @override
  ConsumerState<DashboardComponentConfigSheet> createState() => _DashboardComponentConfigSheetState();
}

class _DashboardComponentConfigSheetState extends ConsumerState<DashboardComponentConfigSheet> {
  late Map<String, dynamic> _metadata;

  @override
  void initState() {
    super.initState();
    _metadata = Map.from(widget.block.metadata);
  }

  void _updateMeta(String key, dynamic value) {
    setState(() {
      _metadata[key] = value;
    });
  }

  void _save() {
    ref.read(dashboardProvider.notifier).updateBlock(widget.block.copyWith(metadata: _metadata));
    if (context.canPop()) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final maxContentHeight = MediaQuery.of(context).size.height * 0.78
        - MediaQuery.of(context).padding.bottom;
    return StandardSheet(
      radius: SheetRadius.large,
      showHandle: true,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Configure ${widget.block.title}',
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: _save,
                  child: const Text('Save'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxContentHeight),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildConfigForm(),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildConfigForm() {
    switch (widget.block.type) {
      case BlockType.todayTimeline:
        return FormSection(
          title: 'Timeline Settings',
          description: 'Adjust how your timeline looks.',
          children: [
            AppSwitchTile(
              value: _metadata['showUntimedGroup'] ?? true,
              onChanged: (v) => _updateMeta('showUntimedGroup', v),
              title: 'Show Untimed Items',
              subtitle: 'Display items with no specific time at the top.',
            ),
            // Could add maxItems slider here
          ],
        );
      case BlockType.todayDial:
        return FormSection(
          title: 'Day Dial Settings',
          description: 'Adjust the dial display.',
          children: [
            AppSwitchTile(
              value: _metadata['showLegend'] ?? true,
              onChanged: (v) => _updateMeta('showLegend', v),
              title: 'Show Legend',
              subtitle: 'Display schedule below the dial.',
            ),
            const SizedBox(height: 16),
            AppDropdown<String>(
              value: ref.watch(settingsProvider).plannerColorMode,
              items: const [
                DropdownMenuItem(value: 'category', child: Text('Category Colors')),
                DropdownMenuItem(value: 'type', child: Text('Type Colors')),
                DropdownMenuItem(value: 'default', child: Text('Default Colors')),
              ],
              onChanged: (v) {
                if (v != null) {
                  ref.read(settingsProvider.notifier).updatePlannerColorMode(v);
                }
              },
              label: 'Color Mode',
            ),
          ],
        );
      case BlockType.shoppingQuickAdd:
        return FormSection(
          title: 'Shopping List',
          description: 'Select which list to add items to by default.',
          children: [
            // Should be a WikiLink picker, but for simplicity we'll just allow creating default if none.
            // Because full UniversalSearchPickerSheet requires more integration here.
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Defaults to the most recently updated list if none selected.',
                style: Theme.of(context).textTheme.bodySmall!,
              ),
            ),
          ],
        );
      case BlockType.weekOverview:
        return FormSection(
          title: 'Week Overview Settings',
          description: 'Configure the weekly view.',
          children: [
            AppSwitchTile(
              value: _metadata['weekStartsMonday'] ?? true,
              onChanged: (v) => _updateMeta('weekStartsMonday', v),
              title: 'Week starts on Monday',
              subtitle: 'If off, week starts on Sunday.',
            ),
          ],
        );
      case BlockType.monthOverview:
        final maxChips = _metadata['maxChipsPerCell'] as int? ?? 2;
        final rawKinds = _metadata['visibleKinds'];
        // All known item kinds
        const allKinds = [
          ('entry',     'Journal Entry'),
          ('task',      'Task'),
          ('event',     'Event'),
          ('habitSlot', 'Habit'),
          ('pomodoro',  'Pomodoro'),
          ('reminder',  'Reminder'),
          ('timeBlock', 'Time Block'),
        ];
        // Current selection: null/empty list = all selected
        Set<String> selectedKinds;
        if (rawKinds is List && rawKinds.isNotEmpty) {
          selectedKinds = rawKinds.map((e) => e.toString()).toSet();
        } else {
          selectedKinds = allKinds.map((e) => e.$1).toSet();
        }

        void toggleKind(String kind, bool checked) {
          if (checked) {
            selectedKinds.add(kind);
          } else {
            selectedKinds.remove(kind);
          }
          // If all are selected, store null (= show all) to keep metadata clean
          final allNames = allKinds.map((e) => e.$1).toSet();
          if (selectedKinds.containsAll(allNames)) {
            _updateMeta('visibleKinds', null);
          } else {
            _updateMeta('visibleKinds', selectedKinds.toList());
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FormSection(
              title: 'Month Overview Settings',
              description: 'Configure the calendar month view.',
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Items per cell', style: Theme.of(context).textTheme.bodyMedium),
                            Text('Max items shown in each day cell', style: Theme.of(context).textTheme.bodySmall!.copyWith(color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: maxChips > 1 ? () => _updateMeta('maxChipsPerCell', maxChips - 1) : null,
                            color: AppColors.accent,
                          ),
                          SizedBox(
                            width: 28,
                            child: Text('$maxChips', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.bold)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: maxChips < 6 ? () => _updateMeta('maxChipsPerCell', maxChips + 1) : null,
                            color: AppColors.accent,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FormSection(
              title: 'Visible Item Types',
              description: 'Choose which types of items appear in the calendar cells.',
              children: allKinds.map((pair) {
                final kind = pair.$1;
                final label = pair.$2;
                return StatefulBuilder(builder: (ctx, setSt) {
                  final isOn = selectedKinds.contains(kind);
                  return AppSwitchTile(
                    value: isOn,
                    onChanged: (v) {
                      setSt(() => toggleKind(kind, v));
                    },
                    title: label,
                  );
                });
              }).toList(),
            ),
          ],
        );
      case BlockType.goalsProjectsOverview:
        return FormSection(
          title: 'Goals & Projects Settings',
          description: 'Configure what to show and how to sort it.',
          children: [
            AppDropdown<String>(
              value: _metadata['typeFilter'] ?? 'all',
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All')),
                DropdownMenuItem(value: 'goals_only', child: Text('Goals Only')),
                DropdownMenuItem(value: 'projects_only', child: Text('Projects Only')),
              ],
              onChanged: (v) => _updateMeta('typeFilter', v),
              label: 'Filter',
            ),
            const SizedBox(height: 16),
            AppDropdown<String>(
              value: _metadata['sortMode'] ?? 'progress_asc',
              items: const [
                DropdownMenuItem(value: 'progress_asc', child: Text('Least Progress First')),
                DropdownMenuItem(value: 'progress_desc', child: Text('Most Progress First')),
              ],
              onChanged: (v) => _updateMeta('sortMode', v),
              label: 'Sort By',
            ),
            const SizedBox(height: 16),
            AppSwitchTile(
              value: _metadata['includeCompleted'] ?? false,
              onChanged: (v) => _updateMeta('includeCompleted', v),
              title: 'Include Completed',
              subtitle: 'Show goals and projects that are already finished.',
            ),
          ],
        );
      case BlockType.pinnedObject:
        final objectTitle = _metadata['objectTitle'] as String? ?? '';
        return FormSection(
          title: 'Pinned Item',
          description: 'Pin any ContentObject to always show on your dashboard.',
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                objectTitle.isEmpty ? 'No item selected' : 'Pinned: $objectTitle',
                style: Theme.of(context).textTheme.bodyMedium!,
              ),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.of(context).push<Map<String, dynamic>?>(
                  MaterialPageRoute(
                    builder: (_) => const _ObjectPickerPage(),
                  ),
                );
                if (result != null) {
                  _updateMeta('objectId', result['id']);
                  _updateMeta('objectType', result['type']);
                  _updateMeta('objectTitle', result['title']);
                }
              },
              icon: const Icon(Icons.search_rounded, size: 18),
              label: Text(objectTitle.isEmpty ? 'Select Item' : 'Change Item'),
            ),
          ],
        );
      case BlockType.trackerAnalysis:
        final trackerTitle = _metadata['trackerTitle'] as String? ?? '';
        return FormSection(
          title: 'Tracker Analysis',
          description: 'Select a tracker or mood to show a chart for.',
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                trackerTitle.isEmpty ? 'No tracker selected' : 'Tracker: $trackerTitle',
                style: Theme.of(context).textTheme.bodyMedium!,
              ),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.of(context).push<Map<String, dynamic>?>(
                  MaterialPageRoute(
                    builder: (_) => const _TrackerPickerPage(),
                  ),
                );
                if (result != null) {
                  _updateMeta('trackerId', result['id']);
                  _updateMeta('trackerTitle', result['title']);
                }
              },
              icon: const Icon(Icons.search_rounded, size: 18),
              label: Text(trackerTitle.isEmpty ? 'Select Tracker' : 'Change Tracker'),
            ),
            const SizedBox(height: 16),
            AppDropdown<String>(
              value: _metadata['chartType'] ?? 'bar',
              items: const [
                DropdownMenuItem(value: 'bar', child: Text('Bar Chart')),
                DropdownMenuItem(value: 'line', child: Text('Line Chart')),
              ],
              onChanged: (v) => _updateMeta('chartType', v),
              label: 'Chart Type',
            ),
            const SizedBox(height: 16),
            AppDropdown<int>(
              value: _metadata['daysBack'] ?? 30,
              items: const [
                DropdownMenuItem(value: 7, child: Text('Last 7 days')),
                DropdownMenuItem(value: 14, child: Text('Last 14 days')),
                DropdownMenuItem(value: 30, child: Text('Last 30 days')),
                DropdownMenuItem(value: 90, child: Text('Last 90 days')),
              ],
              onChanged: (v) => _updateMeta('daysBack', v),
              label: 'Period',
            ),
          ],
        );
      default:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text('No configuration available for this component.', style: Theme.of(context).textTheme.bodySmall!),
          ),
        );
    }
  }
}

class AddComponentSheet extends ConsumerWidget {
  const AddComponentSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddComponentSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(dashboardProvider).valueOrNull ?? [];
    final currentTypes = dashboardState.map((b) => b.type).toSet();

    final availableComponents = componentRegistry.where((c) {
      if (!c.allowMultipleInstances && currentTypes.contains(c.type)) return false;
      return true;
    }).toList();

    return StandardSheet(
      radius: SheetRadius.large,
      showHandle: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Text('Add Component', style: Theme.of(context).textTheme.titleMedium!),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: availableComponents.length,
              itemBuilder: (context, index) {
                final def = availableComponents[index];
                return ListTile(
                  key: ValueKey(def.type.name),
                  leading: Icon(def.icon, color: AppColors.accent),
                  title: Text(def.defaultTitle),
                  subtitle: Text(def.description, style: Theme.of(context).textTheme.bodySmall!),
                  onTap: () async {
                    if (context.canPop()) context.pop();
                    await ref.read(dashboardProvider.notifier).addBlock(
                      def.type,
                      def.defaultTitle,
                      metadata: def.defaultMetadata,
                    );
                    // Get the newly added block to configure
                    final state = ref.read(dashboardProvider).valueOrNull ?? [];
                    if (state.isNotEmpty) {
                      final newBlock = state.last;
                      if (context.mounted) {
                        DashboardComponentConfigSheet.show(context, newBlock);
                      }
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Picker pages used in config sheets ───────────────────────────────────────

class _ObjectPickerPage extends ConsumerStatefulWidget {
  const _ObjectPickerPage();
  @override
  ConsumerState<_ObjectPickerPage> createState() => _ObjectPickerPageState();
}

class _ObjectPickerPageState extends ConsumerState<_ObjectPickerPage> {
  final _ctrl = TextEditingController();
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(allObjectsProvider).valueOrNull ?? [];
    final filtered = _query.isEmpty
        ? all
        : all.where((o) => o.title.toLowerCase().contains(_query.toLowerCase())).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Select Object')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _ctrl,
              decoration: const InputDecoration(
                hintText: 'Search...',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (context, i) {
                final obj = filtered[i];
                return ListTile(
                  key: ValueKey(obj.id),
                  title: Text(obj.title),
                  subtitle: Text(obj.type.toUpperCase()),
                  onTap: () => Navigator.of(context).pop({
                    'id': obj.id,
                    'type': obj.type,
                    'title': obj.title,
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackerPickerPage extends ConsumerStatefulWidget {
  const _TrackerPickerPage();
  @override
  ConsumerState<_TrackerPickerPage> createState() => _TrackerPickerPageState();
}

class _TrackerPickerPageState extends ConsumerState<_TrackerPickerPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(allObjectsProvider).valueOrNull ?? [];
    final trackers = all.whereType<TrackerDefinition>().cast<ContentObject>().toList()
      + all.whereType<MoodDefinition>().cast<ContentObject>().toList();
    final filtered = _query.isEmpty
        ? trackers
        : trackers.where((o) => o.title.toLowerCase().contains(_query.toLowerCase())).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Select Tracker / Mood')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search...',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (context, i) {
                final obj = filtered[i];
                return ListTile(
                  key: ValueKey(obj.id),
                  leading: Icon(
                    obj is MoodDefinition ? Icons.emoji_emotions_outlined : Icons.bar_chart_rounded,
                    color: AppColors.accent,
                  ),
                  title: Text(obj.title),
                  subtitle: Text(obj.type.toUpperCase()),
                  onTap: () => Navigator.of(context).pop({
                    'id': obj.id,
                    'title': obj.title,
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

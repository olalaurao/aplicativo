import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../models/dashboard_block.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../providers/settings_provider.dart';
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
    return StandardSheet(
      radius: SheetRadius.large,
      showHandle: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Configure ${widget.block.title}', style: Theme.of(context).textTheme.titleMedium!),
                TextButton(
                  onPressed: _save,
                  child: const Text('Save'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildConfigForm(),
            ),
          ),
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

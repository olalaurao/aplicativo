// lib/ui/widgets/widget_config_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_provider.dart';
import '../../providers/vault_provider.dart';
import '../../models/shared_types.dart';
import '../../models/content_object.dart';
import '../../models/goal_model.dart';
import '../../models/organizer_model.dart';
import '../../models/dashboard_block.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/widget_sync_provider.dart';
import '../../services/widget_service.dart';
import '../theme.dart';
import 'app_chip.dart';
import 'app_switch_tile.dart';

class WidgetConfigSheet extends ConsumerStatefulWidget {
  const WidgetConfigSheet({super.key});

  @override
  ConsumerState<WidgetConfigSheet> createState() => _WidgetConfigSheetState();
}

class _WidgetConfigSheetState extends ConsumerState<WidgetConfigSheet> {
  final Map<String, bool> _expanded = {
    'quick': false,
    'calendar': false,
    'habit': false,
    'note': false,
    'filter': false,
  };

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final organizers = ref.watch(organizerListProvider);
    final dashboardBlocks = ref.watch(dashboardProvider).valueOrNull ?? [];
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: 24 + bottomInset,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Widgets Nativos',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Configure os atalhos e dados na tela inicial',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textMutedColor(context),
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  // --- QUICK-ADD WIDGET ---
                  _buildWidgetHeader(
                    key: 'quick',
                    title: 'Quick-Add (2x1)',
                    desc: 'Configurable quick entry shortcuts.',
                    icon: Icons.add_box_rounded,
                  ),
                  if (_expanded['quick'] == true) ...[
                    _buildQuickAddConfig(settings),
                    const SizedBox(height: 12),
                  ],

                  // --- CALENDAR WIDGET ---
                  _buildWidgetHeader(
                    key: 'calendar',
                    title: 'Calendar (4x2)',
                    desc:
                        'Weekly/monthly view integrated with tasks and habits.',
                    icon: Icons.calendar_today_rounded,
                  ),
                  if (_expanded['calendar'] == true) ...[
                    _buildCalendarConfig(settings),
                    const SizedBox(height: 12),
                  ],

                  // --- HABIT SUMMARY WIDGET ---
                  _buildWidgetHeader(
                    key: 'habit',
                    title: 'Habit Summary (2x2)',
                    desc: 'Your completion rate and active habits by area.',
                    icon: Icons.loop_rounded,
                  ),
                  if (_expanded['habit'] == true) ...[
                    _buildHabitConfig(settings, organizers),
                    const SizedBox(height: 12),
                  ],

                  // --- FILTER WIDGET ---
                  _buildWidgetHeader(
                    key: 'filter',
                    title: 'Filter (4x2)',
                    desc:
                        'Filter tasks, habits and others by organizer.',
                    icon: Icons.filter_alt_rounded,
                  ),
                  if (_expanded['filter'] == true) ...[
                    _buildFilterConfig(dashboardBlocks),
                    const SizedBox(height: 12),
                  ],

                  // --- OBSIDIAN NOTE WIDGET ---
                  _buildWidgetHeader(
                    key: 'note',
                    title: 'Pinned Note (2x2)',
                    desc:
                        'Pin a specific Obsidian note to the home screen.',
                    icon: Icons.sticky_note_2_rounded,
                  ),
                  if (_expanded['note'] == true) ...[
                    _buildNoteConfig(settings),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _saveAndSyncWidgets(dashboardBlocks),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentColor(context),
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppBorderRadius.xl),
              ),
              elevation: 0,
            ),
            child: const Text(
              'SALVAR E SINCRONIZAR',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAndSyncWidgets(List<DashboardBlock> dashboardBlocks) async {
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      final block = dashboardBlocks
          .where((item) => item.id == 'home-area')
          .firstOrNull;
      final metadata = block?.metadata ?? const <String, dynamic>{};
      final rawTypes = metadata['filterObjectTypes'] ?? metadata['objectTypes'];
      final objectTypes = rawTypes is List
          ? rawTypes.map((item) => item.toString()).toSet().toList()
          : const ['task', 'habit'];
      final organizer = metadata['organizerSlug']?.toString() ?? '';
      await ref
          .read(settingsProvider.notifier)
          .updateUniversalWidgetSettings(
            type: 'filter',
            organizer: organizer,
            objectTypes: objectTypes,
          );
      final widgetIds = await WidgetService.universalWidgetIds();
      for (final widgetId in widgetIds) {
        await WidgetService.saveUniversalWidgetConfig(
          widgetId: widgetId,
          type: 'filter',
          title: 'Filter',
          size: 'medium',
          organizer: organizer,
          objectTypes: objectTypes,
        );
      }
      await forceWidgetSync(container);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Widget settings synchronized.'),
          backgroundColor: AppTheme.accentColor(context),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to sync widgets: $e')),
      );
    }
  }

  Widget _buildWidgetHeader({
    required String key,
    required String title,
    required String desc,
    required IconData icon,
  }) {
    final isExpanded = _expanded[key] == true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        onTap: () {
          if (mounted) setState(() {
            _expanded[key] = !isExpanded;
          });
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariantColor(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isExpanded
                  ? AppTheme.accentColor(context).withValues(alpha: 0.3)
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: isExpanded
                      ? AppTheme.accentColor(context).withValues(alpha: 0.1)
                      : AppTheme.surfaceColor(context),
                  borderRadius: BorderRadius.circular(AppBorderRadius.md),
                ),
                child: Icon(
                  icon,
                  color: isExpanded
                      ? AppTheme.accentColor(context)
                      : AppTheme.textMutedColor(context),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      desc,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textMutedColor(context),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                isExpanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: AppTheme.textMutedColor(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAddConfig(AppSettings settings) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariantColor(context).withValues(alpha: 0.5),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppBorderRadius.xl)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Button 1 (Left)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Label',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  controller:
                      TextEditingController(
                          text: settings.quickAddWidgetButton1Label,
                        )
                        ..selection = TextSelection.collapsed(
                          offset: settings.quickAddWidgetButton1Label.length,
                        ),
                  onChanged: (val) {
                    ref
                        .read(settingsProvider.notifier)
                        .updateWidgetQuickAddSettings(btn1Label: val);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Action',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  initialValue: settings.quickAddWidgetButton1Target,
                  items: const [
                    DropdownMenuItem(value: 'journal', child: Text('Journal')),
                    DropdownMenuItem(value: 'task', child: Text('Task')),
                    DropdownMenuItem(value: 'habit', child: Text('Habit')),
                    DropdownMenuItem(value: 'note', child: Text('Note')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      ref
                          .read(settingsProvider.notifier)
                          .updateWidgetQuickAddSettings(btn1Target: val);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Button 2 (Right)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Label',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  controller:
                      TextEditingController(
                          text: settings.quickAddWidgetButton2Label,
                        )
                        ..selection = TextSelection.collapsed(
                          offset: settings.quickAddWidgetButton2Label.length,
                        ),
                  onChanged: (val) {
                    ref
                        .read(settingsProvider.notifier)
                        .updateWidgetQuickAddSettings(btn2Label: val);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Action',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  initialValue: settings.quickAddWidgetButton2Target,
                  items: const [
                    DropdownMenuItem(value: 'journal', child: Text('Journal')),
                    DropdownMenuItem(value: 'task', child: Text('Task')),
                    DropdownMenuItem(value: 'habit', child: Text('Habit')),
                    DropdownMenuItem(value: 'note', child: Text('Note')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      ref
                          .read(settingsProvider.notifier)
                          .updateWidgetQuickAddSettings(btn2Target: val);
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarConfig(AppSettings settings) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariantColor(context).withValues(alpha: 0.5),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppBorderRadius.xl)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'View Type',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
            initialValue: settings.calendarWidgetType,
            items: const [
              DropdownMenuItem(value: 'day', child: Text('Day')),
              DropdownMenuItem(value: 'week', child: Text('Week')),
              DropdownMenuItem(value: 'month', child: Text('Month')),
            ],
            onChanged: (val) {
              if (val != null) {
                ref
                    .read(settingsProvider.notifier)
                    .updateWidgetCalendarSettings(type: val);
              }
            },
          ),
          const SizedBox(height: 16),
          const Text(
            'Show in Calendar',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 8),
          AppSwitchTile(
            title: 'Tarefas agendadas',
            value: settings.calendarWidgetShowTasks,
            onChanged: (val) {
              ref
                  .read(settingsProvider.notifier)
                  .updateWidgetCalendarSettings(showTasks: val);
            },
            contentPadding: EdgeInsets.zero,
          ),
          AppSwitchTile(
            title: 'Frequent habits',
            value: settings.calendarWidgetShowHabits,
            onChanged: (val) {
              ref
                  .read(settingsProvider.notifier)
                  .updateWidgetCalendarSettings(showHabits: val);
            },
            contentPadding: EdgeInsets.zero,
          ),
          AppSwitchTile(
            title: 'Foco do Dia e Pomodoros',
            value: settings.calendarWidgetShowSessions,
            onChanged: (val) {
              ref
                  .read(settingsProvider.notifier)
                  .updateWidgetCalendarSettings(showSessions: val);
            },
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildHabitConfig(
    AppSettings settings,
    List<OrganizerReference> organizers,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariantColor(context).withValues(alpha: 0.5),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppBorderRadius.xl)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filter Habits',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
            initialValue: settings.habitWidgetFilterType,
            items: const [
              DropdownMenuItem(
                value: 'all',
                child: Text('All active habits'),
              ),
              DropdownMenuItem(
                value: 'organizer',
                child: Text('By Organizer (Area/Project)'),
              ),
            ],
            onChanged: (val) {
              if (val != null) {
                ref
                    .read(settingsProvider.notifier)
                    .updateWidgetHabitSettings(filterType: val);
              }
            },
          ),
          if (settings.habitWidgetFilterType == 'organizer') ...[
            const SizedBox(height: 16),
            const Text(
              'Select Organizer',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
              initialValue: settings.habitWidgetOrganizer.isEmpty
                  ? null
                  : settings.habitWidgetOrganizer,
              hint: const Text('Select an area/project'),
              items: organizers.map((o) {
                return DropdownMenuItem(
                  value: o.slug,
                  child: Text('${o.title} (${o.type.toUpperCase()})'),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  ref
                      .read(settingsProvider.notifier)
                      .updateWidgetHabitSettings(organizer: val);
                }
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoteConfig(AppSettings settings) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariantColor(context).withValues(alpha: 0.5),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppBorderRadius.xl)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Note Display Mode',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
            initialValue: settings.universalWidgetType == 'note'
                ? 'fixed'
                : 'latest',
            items: const [
              DropdownMenuItem(
                value: 'latest',
                child: Text('Last modified note'),
              ),
              DropdownMenuItem(
                value: 'fixed',
                child: Text('Specific pinned note'),
              ),
            ],
            onChanged: (val) {
              if (val != null) {
                final type = val == 'fixed' ? 'note' : 'daily';
                ref
                    .read(settingsProvider.notifier)
                    .updateUniversalWidgetSettings(type: type);
              }
            },
          ),
          if (settings.universalWidgetType == 'note') ...[
            const SizedBox(height: 12),
            const Text(
              'Acesse a nota diretamente no app e toque em "Fixar na tela inicial" para sincronizar este widget.',
              style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterConfig(List<DashboardBlock> blocks) {
    final settings = ref.watch(settingsProvider);
    final block = blocks.where((b) => b.id == 'home-area').firstOrNull;

    final allObjects = ref.watch(allObjectsProvider).valueOrNull ?? [];
    final organizers = [
      ...allObjects.whereType<Organizer>().cast<ContentObject>(),
      ...allObjects.whereType<Goal>().cast<ContentObject>(),
    ]..sort((a, b) => a.title.compareTo(b.title));

    final metadata = block?.metadata ?? const <String, dynamic>{};
    var organizerSlug =
        (settings.universalWidgetOrganizer.isNotEmpty
            ? settings.universalWidgetOrganizer
            : null) ??
        metadata['organizerSlug'] as String? ??
        (organizers.isNotEmpty ? organizers.first.slug : null);

    final rawTypes = settings.universalWidgetObjectTypes.isNotEmpty
        ? settings.universalWidgetObjectTypes
        : metadata['filterObjectTypes'] ?? metadata['objectTypes'];
    final selectedObjectTypes = rawTypes is List
        ? rawTypes.map((item) => item.toString()).toSet()
        : {'task', 'habit'};

    const filterObjectTypes = <String, String>{
      'task': 'Tasks',
      'habit': 'Habits',
      'pomodoro': 'Pomodoros',
      'goal': 'Goals',
      'note': 'Notes',
      'entry': 'Journal',
      'resource': 'Resources',
      'person': 'People',
    };

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariantColor(context).withValues(alpha: 0.5),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppBorderRadius.xl)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Organizer',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
            initialValue: organizers.any((o) => o.slug == organizerSlug)
                ? organizerSlug
                : null,
            hint: const Text('Select an area/project/goal'),
            items: organizers.map((o) {
              return DropdownMenuItem(
                value: o.slug,
                child: Text(
                  o is Goal ? 'Goal · ${o.title}' : o.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                final updatedMetadata = Map<String, dynamic>.from(
                  block?.metadata ?? const <String, dynamic>{},
                );
                updatedMetadata['organizerSlug'] = val;
                ref
                    .read(settingsProvider.notifier)
                    .updateUniversalWidgetSettings(
                      type: 'filter',
                      organizer: val,
                    );
                if (block != null) {
                  ref
                      .read(dashboardProvider.notifier)
                      .updateBlock(block.copyWith(metadata: updatedMetadata));
                }
              }
            },
          ),
          const SizedBox(height: 16),
          const Text(
            'Tipos de Objeto',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: filterObjectTypes.entries.map((entry) {
              final selected = selectedObjectTypes.contains(entry.key);
              return AppChip(
                label: entry.value,
                selected: selected,
                onTap: () {
                  final next = Set<String>.from(selectedObjectTypes);
                  final isSelected = !selected;
                  isSelected ? next.add(entry.key) : next.remove(entry.key);
                  final updatedMetadata = Map<String, dynamic>.from(
                    block?.metadata ?? const <String, dynamic>{},
                  );
                  updatedMetadata['filterObjectTypes'] = next.toList();
                  updatedMetadata['objectTypes'] = next.toList();
                  ref
                      .read(settingsProvider.notifier)
                      .updateUniversalWidgetSettings(
                        type: 'filter',
                        objectTypes: next.toList(),
                      );
                  if (block != null) {
                    ref
                        .read(dashboardProvider.notifier)
                        .updateBlock(block.copyWith(metadata: updatedMetadata));
                  }
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

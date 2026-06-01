import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/organizer_model.dart';
import '../../models/task_model.dart';
import '../../models/habit_model.dart';
import '../../models/goal_model.dart';
import '../../models/shared_types.dart';
import '../../models/content_object.dart';
import '../../providers/vault_provider.dart';
import '../../providers/settings_provider.dart';
import '../forms/create_habit_form.dart';
import '../forms/create_task_form.dart';
import '../theme.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';

class OrganizerTasksWidget extends ConsumerStatefulWidget {
  final String? initialOrganizerSlug;
  final Set<String> objectTypes;
  final VoidCallback? onConfigure;

  const OrganizerTasksWidget({
    super.key,
    this.initialOrganizerSlug,
    this.objectTypes = const {'task', 'habit'},
    this.onConfigure,
  });

  @override
  ConsumerState<OrganizerTasksWidget> createState() => _OrganizerTasksWidgetState();
}

class _OrganizerTasksWidgetState extends ConsumerState<OrganizerTasksWidget> {
  String? _selectedSlug;

  @override
  void initState() {
    super.initState();
    _selectedSlug = widget.initialOrganizerSlug;
  }

  @override
  Widget build(BuildContext context) {
    final allObjects = ref.watch(allObjectsProvider).valueOrNull ?? [];
    final organizerObjects = allObjects
        .whereType<Organizer>()
        .cast<ContentObject>()
        .toList();
    final goalOrganizers = allObjects
        .whereType<Goal>()
        .cast<ContentObject>()
        .toList();
    final validOrganizers = [...organizerObjects, ...goalOrganizers];
    
    if (_selectedSlug == null && validOrganizers.isNotEmpty) {
      _selectedSlug = validOrganizers.first.slug;
    }

    final selectedOrganizer = validOrganizers
        .where((o) => o.slug == _selectedSlug || o.id == _selectedSlug)
        .firstOrNull;
    final organizerColor = selectedOrganizer is Organizer
        ? _parseHexColor(selectedOrganizer.color)
        : AppColors.accent;

    final selectedSlug = _selectedSlug;
    bool belongsToSelected(List<OrganizerReference> organizers) {
      if (selectedSlug == null) return false;
      if (selectedOrganizer != null) {
        return organizers.any(
          (org) => org.matches(
            selectedOrganizer.id,
            selectedOrganizer.slug,
            selectedOrganizer.title,
          ),
        );
      }
      return organizers.any((org) => org.slug == selectedSlug);
    }

    final tasks = allObjects
        .whereType<Task>()
        .where((task) => belongsToSelected(task.organizers))
        .toList();
    final habits = allObjects
        .whereType<Habit>()
        .where((habit) => belongsToSelected(habit.organizers))
        .toList();
    final pomodoroTasks = tasks
        .where((task) => (task.pomodoroCount ?? 0) > 0)
        .toList();

    final List<dynamic> displayItems = [];
    if (widget.objectTypes.contains('task')) {
      displayItems.addAll(tasks.where((t) => t.stage != TaskStage.finalized));
    }
    if (widget.objectTypes.contains('habit')) {
      displayItems.addAll(habits);
    }
    if (widget.objectTypes.contains('pomodoro')) {
      final existingTaskIds = displayItems.whereType<Task>().map((task) => task.id).toSet();
      displayItems.addAll(pomodoroTasks.where((task) => !existingTaskIds.contains(task.id)));
    }
    final existingIds = displayItems.whereType<ContentObject>().map((item) => item.id).toSet();
    displayItems.addAll(
      allObjects.where((object) {
        if (existingIds.contains(object.id)) return false;
        if (!widget.objectTypes.contains(object.type)) return false;
        return belongsToSelected(object.organizers);
      }),
    );

    final incompleteTasks = displayItems.whereType<Task>().where((task) => task.stage != TaskStage.finalized).toList();
    final visibleTasks = displayItems.whereType<Task>().toList();
    final visibleHabits = displayItems.whereType<Habit>().toList();
    final completedTasksCount = visibleTasks.length - incompleteTasks.length;
    final today = DateTime.now();
    final completedHabitsCount = visibleHabits.where((habit) => _isHabitCompletedToday(habit, today)).length;
    final visibleDone = completedTasksCount + completedHabitsCount;
    final visibleTotal = visibleTasks.length + visibleHabits.length;
    final visibleProgress = visibleTotal == 0 ? 0.0 : visibleDone / visibleTotal;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(_iconForFilter(widget.objectTypes), color: AppColors.accent, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Filtro',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.more_vert_rounded, color: AppColors.textMuted),
                onPressed: widget.onConfigure,
                tooltip: 'Editar filtro',
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Organizer Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: validOrganizers.map((org) {
                final isSelected = org.slug == _selectedSlug || org.id == _selectedSlug;
                final color = org is Organizer ? _parseHexColor(org.color) : AppColors.accent;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(
                      org.title,
                      style: TextStyle(
                        color: isSelected ? AppTheme.textPrimaryColor(context) : AppTheme.textSecondaryColor(context),
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                            _selectedSlug = org.slug;
                      });
                      // Update global settings so native widgets stay in sync
                      ref.read(settingsProvider.notifier).updateUniversalWidgetSettings(
                        organizer: org.slug,
                      );
                    },
                    backgroundColor: AppTheme.surfaceVariantColor(context),
                    selectedColor: AppTheme.surfaceVariantColor(context),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: isSelected 
                        ? BorderSide(color: color.withValues(alpha: 0.3), width: 1.5)
                        : BorderSide(color: AppTheme.dividerColor(context).withValues(alpha: 0.2)),
                    ),
                    showCheckmark: false,
                    avatar: isSelected
                        ? _buildOrganizerIcon(org, color)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),

          if (selectedOrganizer != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: organizerColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Progresso',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textPrimaryColor(context),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '$visibleDone/$visibleTotal',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textPrimaryColor(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: visibleProgress,
                      backgroundColor: AppTheme.textPrimaryColor(context).withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(organizerColor),
                      minHeight: 6,
                    ),
                  ),
                  if (visibleHabits.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Hábitos hoje: $completedHabitsCount/${visibleHabits.length}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondaryColor(context),
                              fontSize: 11,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          _buildFilterSummary(visibleTasks.length, visibleHabits.length, pomodoroTasks.length),
          const SizedBox(height: 16),

          // Content List
          ...displayItems.map((item) => _buildContentItem(item, organizerColor)),
          
          if (displayItems.isEmpty) 
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Center(
                child: Text(
                  'No items found.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ),
            ),
          
          const SizedBox(height: 16),
          
          // Add Button
          InkWell(
            onTap: () => _openCreateForm(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.dividerColor(context), style: BorderStyle.solid),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, size: 18, color: AppTheme.textSecondaryColor(context)),
                  const SizedBox(width: 8),
                  Text(
                    widget.objectTypes.length == 1 && widget.objectTypes.contains('habit')
                        ? 'Adicionar hábito'
                        : 'Adicionar tarefa',
                    style: TextStyle(
                      color: AppTheme.textSecondaryColor(context),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSummary(int tasks, int habits, int pomodoros) {
    final chips = <Widget>[];
    if (widget.objectTypes.contains('task')) {
      chips.add(_summaryPill('Tarefas', tasks));
    }
    if (widget.objectTypes.contains('habit')) {
      chips.add(_summaryPill('Hábitos', habits));
    }
    if (widget.objectTypes.contains('pomodoro')) {
      chips.add(_summaryPill('Pomodoros', pomodoros));
    }
    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }

  Widget _summaryPill(String label, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariantColor(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$label · $count',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondaryColor(context),
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }

  Widget _buildContentItem(dynamic item, Color organizerColor) {
    if (item is Task) {
      final allObjects = ref.watch(allObjectsProvider).value ?? [];
      final isBlocked = item.isBlocked(allObjects);

      return Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: Row(
          children: [
            Transform.scale(
              scale: 1.1,
              child: isBlocked 
                ? IconButton(
                    icon: const Icon(Icons.lock_rounded, size: 20, color: AppColors.error),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Esta tarefa está bloqueada por dependências incompletas.')));
                    },
                  )
                : Checkbox(
                    value: item.stage == TaskStage.finalized,
                    shape: const CircleBorder(),
                    side: const BorderSide(color: AppColors.divider, width: 1.5),
                    activeColor: organizerColor,
                    onChanged: (bool? newValue) {
                      if (newValue != null) {
                        ref.read(tasksProvider.notifier).updateTask(
                              item.copyWith(
                                stage: newValue ? TaskStage.finalized : TaskStage.todo,
                              ),
                            );
                      }
                    },
                  ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: InkWell(
                onTap: () => context.push('/detail/${item.id}'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.displayTitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                        decoration: item.stage == TaskStage.finalized ? TextDecoration.lineThrough : null,
                        color: item.stage == TaskStage.finalized ? AppTheme.textMutedColor(context) : AppTheme.textPrimaryColor(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (item.scheduledTime != null) ...[
                          Text(
                            '${item.scheduledTime}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (item.priority != TaskPriority.none) ...[
                          Icon(
                            PhosphorIcons.fire(PhosphorIconsStyle.fill),
                            color: AppTheme.priorityColor(item.priority),
                            size: 12,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            item.priority.index.toString(),
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    } else if (item is Habit) {
      final completed = _isHabitCompletedToday(item, DateTime.now());
      return Padding(
        padding: const EdgeInsets.only(bottom: 12.0, left: 12.0),
        child: Row(
          children: [
            Checkbox(
              value: completed,
              shape: const CircleBorder(),
              side: BorderSide(color: AppTheme.dividerColor(context), width: 1.5),
              activeColor: organizerColor,
              onChanged: (_) {
                ref.read(habitsProvider.notifier).toggleHabit(item, DateTime.now());
              },
            ),
            const SizedBox(width: 4),
            Expanded(
              child: InkWell(
                onTap: () => context.push('/detail/${item.id}'),
                child: Text(
                  item.displayTitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                    decoration: completed ? TextDecoration.lineThrough : null,
                    color: completed
                        ? AppTheme.textMutedColor(context)
                        : AppTheme.textPrimaryColor(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      );
    } else if (item is ContentObject) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12.0, left: 12.0),
        child: InkWell(
          onTap: () => context.push('/detail/${item.id}'),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(_iconForObject(item), color: organizerColor, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.displayTitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                          color: AppTheme.textPrimaryColor(context),
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  bool _isHabitCompletedToday(Habit habit, DateTime date) {
    return habit.completionHistory.any((record) {
      return record.date.year == date.year &&
          record.date.month == date.month &&
          record.date.day == date.day &&
          record.successful;
    });
  }

  void _openCreateForm(BuildContext context) {
    final form = widget.objectTypes.length == 1 && widget.objectTypes.contains('habit')
        ? const CreateHabitForm()
        : const CreateTaskForm();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => form,
    );
  }

  Widget _buildOrganizerIcon(ContentObject org, Color color) {
    if (org is Goal) {
      return Icon(Icons.flag_rounded, color: color, size: 14);
    }
    final iconStr = org is Organizer ? org.icon : null;
    if (iconStr != null && iconStr.startsWith('ph-')) {
      return Icon(PhosphorIcons.folder(), color: color, size: 14);
    } else if (iconStr != null && iconStr.endsWith('.svg')) {
      return SvgPicture.asset(
        'assets/icons/$iconStr',
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        width: 14,
        height: 14,
      );
    }
    return Icon(Icons.folder_open, color: color, size: 14);
  }

  IconData _iconForFilter(Set<String> types) {
    if (types.length == 1 && types.contains('pomodoro')) return Icons.timer_rounded;
    if (types.length == 1 && types.contains('habit')) return Icons.loop_rounded;
    if (types.length == 1 && types.contains('task')) return Icons.check_circle_outline_rounded;
    return Icons.filter_alt_rounded;
  }

  IconData _iconForObject(ContentObject item) {
    return switch (item.type) {
      'goal' => Icons.flag_rounded,
      'note' => Icons.sticky_note_2_rounded,
      'journal_entry' => Icons.auto_stories_rounded,
      'resource' => Icons.book_rounded,
      'person' => Icons.person_rounded,
      _ => Icons.circle_rounded,
    };
  }

  Color _parseHexColor(String? hex) {
    if (hex == null || hex.isEmpty) return AppColors.accent;
    final cleaned = hex.replaceFirst('#', '').replaceFirst('0x', '');
    final withAlpha = cleaned.length == 6 ? 'FF$cleaned' : cleaned;
    return Color(int.tryParse(withAlpha, radix: 16) ?? AppColors.accent.toARGB32());
  }
}



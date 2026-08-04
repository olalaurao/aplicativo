import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/task_model.dart';
import '../../models/content_object.dart';
import '../../providers/vault_provider.dart';
import '../../providers/daily_schedule_provider.dart';
import '../../services/daily_schedule_service.dart';
import '../../services/week_tag_service.dart';
import '../navigation/object_navigation.dart';
import '../theme.dart';

class WeeklyPlanningScreen extends ConsumerStatefulWidget {
  const WeeklyPlanningScreen({super.key});

  @override
  ConsumerState<WeeklyPlanningScreen> createState() =>
      _WeeklyPlanningScreenState();
}

class _WeeklyPlanningScreenState
    extends ConsumerState<WeeklyPlanningScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Step 4 — week focus pins
  final Set<String> _selectedPinIds = {};

  static const _steps = [
    'Inbox',
    'Fixed Commitments',
    'Distribute',
    'Focus Picks',
  ];

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _finish() async {
    final vault = ref.read(vaultProvider.notifier);
    final allObjects = ref.read(allObjectsProvider).valueOrNull ?? [];
    final weekTag = WeekTagService.currentWeekTag;

    // Pin up to 3 selected tasks
    for (final id in _selectedPinIds.take(3)) {
      final obj = allObjects.cast<ContentObject?>().firstWhere(
        (o) => o?.id == id,
        orElse: () => null,
      );
      if (obj == null) continue;
      if (obj is Task) {
        final updatedTags = [...obj.tags];
        if (!updatedTags.contains(weekTag)) updatedTags.add(weekTag);
        final updated = obj.copyWith(tags: updatedTags);
        await vault.updateObject(updated);
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Weekly plan saved!')),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_steps[_currentStep]),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          _buildProgressBar(),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (i) => setState(() => _currentStep = i),
              children: [
                _Step1Inbox(),
                _Step2FixedCommitments(),
                _Step3Distribute(),
                _Step4FocusPicker(
                  selectedIds: _selectedPinIds,
                  onToggle: (id) {
                    setState(() {
                      if (_selectedPinIds.contains(id)) {
                        _selectedPinIds.remove(id);
                      } else if (_selectedPinIds.length < 3) {
                        _selectedPinIds.add(id);
                      }
                    });
                  },
                ),
              ],
            ),
          ),
          _buildNav(),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: List.generate(_steps.length, (i) {
          final active = i <= _currentStep;
          return Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: i < _steps.length - 1 ? 6 : 0),
              decoration: BoxDecoration(
                color: active ? AppTheme.accentColor(context) : AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildNav() {
    final isLast = _currentStep == _steps.length - 1;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            if (_currentStep > 0)
              TextButton(
                onPressed: _previousStep,
                child: const Text('Back'),
              )
            else
              const SizedBox.shrink(),
            const Spacer(),
            FilledButton(
              onPressed: _nextStep,
              child: Text(isLast ? 'Finish' : 'Next  →'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Step 1: Inbox triage ─────────────────────────────────────────────────────

class _Step1Inbox extends ConsumerStatefulWidget {
  @override
  ConsumerState<_Step1Inbox> createState() => _Step1InboxState();
}

class _Step1InboxState extends ConsumerState<_Step1Inbox> {
  final _captureCtrl = TextEditingController();

  @override
  void dispose() {
    _captureCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final queue = ref.watch(unifiedInboxQueueProvider);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Clear your Inbox',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          'Quickly capture anything new, then triage each item.',
          style: TextStyle(color: AppTheme.textMutedColor(context)),
        ),
        const SizedBox(height: 20),
        // Quick-capture field
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _captureCtrl,
                decoration: InputDecoration(
                  hintText: 'Quick capture…',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onSubmitted: (_) => _capture(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _capture,
              child: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (queue.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.inbox_outlined,
                      size: 48, color: AppTheme.textMutedColor(context)),
                  const SizedBox(height: 12),
                  Text(
                    'Inbox is empty — great start!',
                    style: TextStyle(color: AppTheme.textMutedColor(context)),
                  ),
                ],
              ),
            ),
          )
        else ...[
          Text('${queue.length} items in queue',
              style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textMutedColor(context),
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          ...queue.map((item) => _InboxQueueTile(item: item)),
        ],
      ],
    );
  }

  Future<void> _capture() async {
    final text = _captureCtrl.text.trim();
    if (text.isEmpty) return;
    await ref.read(inboxProvider.notifier).addItem(text);
    _captureCtrl.clear();
  }
}

class _InboxQueueTile extends ConsumerWidget {
  final InboxQueueItem item;
  const _InboxQueueTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTask = item.kind == InboxQueueKind.task && item.source is Task;
    final task = isTask ? item.source as Task : null;
    final isDone = task?.stage == TaskStage.finalized;

    return InkWell(
      onTap: () => navigateToObject(context, item.source),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            if (isTask)
              GestureDetector(
                onTap: () async {
                  final newStage = isDone ? TaskStage.todo : TaskStage.finalized;
                  await ref
                      .read(vaultProvider.notifier)
                      .updateObject(task!.copyWith(stage: newStage));
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 22,
                  height: 22,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone
                        ? AppTheme.accentColor(context)
                        : Colors.transparent,
                    border: Border.all(
                      color: isDone
                          ? AppTheme.accentColor(context)
                          : AppColors.divider,
                      width: 2,
                    ),
                  ),
                  child: isDone
                      ? const Icon(Icons.check_rounded,
                          size: 14, color: Colors.white)
                      : null,
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Icon(
                  _kindIcon(item.kind),
                  size: 18,
                  color: AppTheme.accentColor(context),
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      decoration:
                          isDone ? TextDecoration.lineThrough : null,
                      color: isDone
                          ? AppTheme.textMutedColor(context)
                          : null,
                    ),
                  ),
                  if (item.subtitle.isNotEmpty)
                    Text(
                      item.subtitle,
                      style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMutedColor(context)),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: AppTheme.textMutedColor(context)),
          ],
        ),
      ),
    );
  }

  IconData _kindIcon(InboxQueueKind kind) {
    return switch (kind) {
      InboxQueueKind.inbox => Icons.inbox_rounded,
      InboxQueueKind.task => Icons.check_box_outline_blank_rounded,
      InboxQueueKind.idea => Icons.lightbulb_outline_rounded,
      InboxQueueKind.project => Icons.folder_outlined,
      InboxQueueKind.goal => Icons.flag_outlined,
    };
  }
}

// ── Step 2: Fixed Commitments ────────────────────────────────────────────────

/// Groups recurring schedule items by (title, startMinutes) so daily
/// habits / time-blocks appear as ONE chip showing days + time.
class _CommitmentGroup {
  final String title;
  final int? startMinutes;
  final Color color;
  final IconData iconData;
  final List<int> weekdays; // 1=Mon … 7=Sun

  const _CommitmentGroup({
    required this.title,
    required this.startMinutes,
    required this.color,
    required this.iconData,
    required this.weekdays,
  });
}

List<_CommitmentGroup> _groupCommitments(List<DailyScheduleItem> items) {
  final map = <String, _CommitmentGroup>{};
  for (final item in items) {
    final key = '${item.title}__${item.startMinutes}';
    if (map.containsKey(key)) {
      final existing = map[key]!;
      if (!existing.weekdays.contains(item.date.weekday)) {
        map[key] = _CommitmentGroup(
          title: existing.title,
          startMinutes: existing.startMinutes,
          color: existing.color,
          iconData: existing.iconData,
          weekdays: [...existing.weekdays, item.date.weekday]..sort(),
        );
      }
    } else {
      map[key] = _CommitmentGroup(
        title: item.title,
        startMinutes: item.startMinutes,
        color: item.color,
        iconData: item.iconData,
        weekdays: [item.date.weekday],
      );
    }
  }
  // Sort by time then title
  final groups = map.values.toList()
    ..sort((a, b) {
      final t = (a.startMinutes ?? 9999).compareTo(b.startMinutes ?? 9999);
      return t != 0 ? t : a.title.compareTo(b.title);
    });
  return groups;
}

String _formatDays(List<int> weekdays) {
  const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  if (weekdays.length == 7) return 'Every day';
  if (weekdays.length == 5 &&
      !weekdays.contains(6) &&
      !weekdays.contains(7)) return 'Weekdays';
  if (weekdays.length == 2 &&
      weekdays.contains(6) &&
      weekdays.contains(7)) return 'Weekend';
  return weekdays.map((d) => names[d - 1]).join(' · ');
}

String _formatMinutes(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

class _Step2FixedCommitments extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateTime.now();
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final allItems = <DailyScheduleItem>[];
    for (int d = 0; d < 7; d++) {
      final date = monday.add(Duration(days: d));
      final snap = ref.watch(dailyScheduleProvider(date));
      allItems.addAll(snap.timedItems);
    }

    final groups = _groupCommitments(allItems);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Fixed Commitments',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          'Recurring time-blocked items this week — already locked in.',
          style: TextStyle(color: AppTheme.textMutedColor(context)),
        ),
        const SizedBox(height: 20),
        if (groups.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.event_available_outlined,
                      size: 48, color: AppTheme.textMutedColor(context)),
                  const SizedBox(height: 12),
                  Text(
                    'No fixed commitments this week.',
                    style:
                        TextStyle(color: AppTheme.textMutedColor(context)),
                  ),
                ],
              ),
            ),
          )
        else
          ...groups.map((g) => _CommitmentGroupTile(group: g)),
      ],
    );
  }
}

class _CommitmentGroupTile extends StatelessWidget {
  final _CommitmentGroup group;
  const _CommitmentGroupTile({required this.group});

  @override
  Widget build(BuildContext context) {
    final isRecurring = group.weekdays.length > 1;
    final timeLabel = group.startMinutes != null
        ? _formatMinutes(group.startMinutes!)
        : null;
    final daysLabel = _formatDays(group.weekdays);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: group.color, width: 3)),
      ),
      child: Row(
        children: [
          Icon(group.iconData, size: 16, color: group.color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(group.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (isRecurring) ...
                      [
                        Icon(Icons.repeat_rounded,
                            size: 11,
                            color: AppTheme.textMutedColor(context)),
                        const SizedBox(width: 3),
                      ],
                    Text(
                      daysLabel,
                      style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textMutedColor(context)),
                    ),
                    if (timeLabel != null) ...
                      [
                        Text(
                          '  ·  $timeLabel',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textMutedColor(context)),
                        ),
                      ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step 3: Distribute tasks across the week ─────────────────────────────────

class _Step3Distribute extends ConsumerStatefulWidget {
  @override
  ConsumerState<_Step3Distribute> createState() => _Step3DistributeState();
}

class _Step3DistributeState extends ConsumerState<_Step3Distribute> {
  @override
  Widget build(BuildContext context) {
    final allObjects = ref.watch(allObjectsProvider).valueOrNull ?? [];
    final unscheduledTasks = allObjects
        .whereType<Task>()
        .where((t) =>
            !t.archived &&
            t.startDate == null &&
            (t.stage == TaskStage.todo || t.stage == TaskStage.inProgress))
        .toList();

    final today = DateTime.now();
    // Start from Monday of the current week
    final monday = today.subtract(Duration(days: today.weekday - 1));

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Distribute Tasks',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          'Drag tasks to a day to assign a start date.',
          style: TextStyle(color: AppTheme.textMutedColor(context)),
        ),
        const SizedBox(height: 20),
        // Unscheduled pool
        if (unscheduledTasks.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No unscheduled tasks to distribute.',
                style: TextStyle(color: AppTheme.textMutedColor(context)),
              ),
            ),
          )
        else ...[
          Text('${unscheduledTasks.length} unscheduled',
              style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: unscheduledTasks.map((t) => _DraggableTaskChip(task: t)).toList(),
          ),
          const SizedBox(height: 24),
        ],
        // Day drop targets
        ...List.generate(7, (i) {
          final day = monday.add(Duration(days: i));
          final snap = ref.watch(dailyScheduleProvider(day));
          final count = snap.timedItems.length;
          final isFull = count >= 5;
          return DragTarget<Task>(
            onWillAcceptWithDetails: (_) => true,
            onAcceptWithDetails: (details) async {
              final task = details.data;
              final updated = task.copyWith(startDate: day);
              await ref.read(vaultProvider.notifier).updateObject(updated);
            },
            builder: (context, candidates, _) {
              final isHovered = candidates.isNotEmpty;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isHovered
                      ? AppTheme.accentColor(context).withOpacity(0.1)
                      : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isHovered
                        ? AppTheme.accentColor(context)
                        : isFull
                            ? AppColors.error.withOpacity(0.5)
                            : AppColors.divider,
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 60,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _dayName(day.weekday),
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          Text(
                            '${day.day}/${day.month}',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textMutedColor(context)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isHovered
                            ? 'Drop here'
                            : count == 0
                                ? 'No fixed items'
                                : '$count fixed item${count == 1 ? '' : 's'}${isFull ? ' — full' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isFull && !isHovered
                              ? AppColors.error
                              : AppTheme.textMutedColor(context),
                        ),
                      ),
                    ),
                    Icon(
                      isFull ? Icons.warning_amber_rounded : Icons.add_rounded,
                      size: 16,
                      color: isFull
                          ? AppColors.error
                          : AppTheme.textMutedColor(context),
                    ),
                  ],
                ),
              );
            },
          );
        }),
      ],
    );
  }

  String _dayName(int weekday) {
    return const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][weekday - 1];
  }
}

class _DraggableTaskChip extends StatelessWidget {
  final Task task;
  const _DraggableTaskChip({required this.task});

  @override
  Widget build(BuildContext context) {
    return Draggable<Task>(
      data: task,
      feedback: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(20),
        child: Chip(
          label: Text(task.title,
              style: TextStyle(color: AppTheme.accentColor(context))),
          backgroundColor: AppColors.surfaceVariant,
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _chip(context),
      ),
      child: _chip(context),
    );
  }

  Widget _chip(BuildContext context) {
    return Chip(
      label: Text(
        task.title,
        style: const TextStyle(fontSize: 12),
        overflow: TextOverflow.ellipsis,
      ),
      backgroundColor: AppColors.surfaceVariant,
    );
  }
}

// ── Step 4: Focus picker ──────────────────────────────────────────────────────

class _Step4FocusPicker extends ConsumerWidget {
  final Set<String> selectedIds;
  final void Function(String id) onToggle;

  const _Step4FocusPicker({
    required this.selectedIds,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allObjects = ref.watch(allObjectsProvider).valueOrNull ?? [];
    final tasks = allObjects
        .whereType<Task>()
        .where((t) => !t.archived && t.stage != TaskStage.finalized)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          "This week's focus",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          'Pin up to 3 tasks as your weekly focus. They will appear in the Focus card on your dashboard.',
          style: TextStyle(color: AppTheme.textMutedColor(context)),
        ),
        const SizedBox(height: 6),
        Text(
          '${selectedIds.length}/3 selected',
          style: TextStyle(
            color: selectedIds.length == 3
                ? AppTheme.accentColor(context)
                : AppTheme.textMutedColor(context),
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 16),
        if (tasks.isEmpty)
          Center(
            child: Text(
              'No tasks available.',
              style: TextStyle(color: AppTheme.textMutedColor(context)),
            ),
          )
        else
          ...tasks.map((t) {
            final isSelected = selectedIds.contains(t.id);
            final atMax = selectedIds.length >= 3 && !isSelected;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.accentColor(context).withOpacity(0.1)
                    : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.accentColor(context)
                      : AppColors.divider,
                ),
              ),
              child: InkWell(
                onTap: atMax ? null : () => onToggle(t.id),
                child: Row(
                  children: [
                    Icon(
                      isSelected
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      size: 20,
                      color: isSelected
                          ? AppTheme.accentColor(context)
                          : AppTheme.textMutedColor(context),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        t.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: atMax ? AppTheme.textMutedColor(context) : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

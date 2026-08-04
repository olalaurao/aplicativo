import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../models/task_model.dart';
import '../../../providers/vault_provider.dart';
import '../../../services/week_tag_service.dart';
import '../../theme.dart';

/// Dashboard card that displays up to 3 tasks pinned for the current week.
/// Tasks are pinned by adding the tag "week:YYYY-Www" via WeeklyPlanningScreen.
class WeeklyFocusComponent extends ConsumerWidget {
  const WeeklyFocusComponent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allObjects = ref.watch(allObjectsProvider).valueOrNull ?? [];
    final weekTag = WeekTagService.currentWeekTag;

    final pinned = allObjects
        .whereType<Task>()
        .where((t) => !t.archived && t.tags.contains(weekTag))
        .take(3)
        .toList();

    return Container(
      decoration: AppTheme.cardDecoration(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.star_rounded,
                  size: 18, color: AppTheme.accentColor(context)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  "This week's focus",
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
                onPressed: () => context.push('/planning/weekly'),
                child: Text(
                  'Edit',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.accentColor(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (pinned.isEmpty)
            GestureDetector(
              onTap: () => context.push('/planning/weekly'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                alignment: Alignment.center,
                child: Column(
                  children: [
                    Icon(Icons.add_circle_outline_rounded,
                        size: 32, color: AppTheme.textMutedColor(context)),
                    const SizedBox(height: 8),
                    Text(
                      'No focus tasks pinned.\nTap to run Weekly Planning.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppTheme.textMutedColor(context),
                          fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else
            ...pinned.map((task) => _FocusTaskRow(task: task)),
        ],
      ),
    );
  }
}

class _FocusTaskRow extends ConsumerWidget {
  final Task task;
  const _FocusTaskRow({required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCompleted = task.stage == TaskStage.finalized;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _toggleDone(ref),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted
                    ? AppTheme.accentColor(context)
                    : Colors.transparent,
                border: Border.all(
                  color: isCompleted
                      ? AppTheme.accentColor(context)
                      : AppColors.divider,
                  width: 2,
                ),
              ),
              child: isCompleted
                  ? const Icon(Icons.check_rounded,
                      size: 14, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              task.title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                decoration: isCompleted ? TextDecoration.lineThrough : null,
                color: isCompleted ? AppTheme.textMutedColor(context) : null,
              ),
            ),
          ),
          Icon(Icons.star_rounded,
              size: 14, color: AppTheme.accentColor(context).withOpacity(0.5)),
        ],
      ),
    );
  }

  Future<void> _toggleDone(WidgetRef ref) async {
    final newStage = task.stage == TaskStage.finalized
        ? TaskStage.todo
        : TaskStage.finalized;
    final updated = task.copyWith(stage: newStage);
    await ref.read(vaultProvider.notifier).updateObject(updated);
  }
}

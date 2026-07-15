import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/dashboard_block.dart';
import '../../../models/task_model.dart';
import '../../../models/habit_model.dart';
import '../../../providers/today_provider.dart';
import '../../../providers/vault_provider.dart';
import '../../../providers/pomodoro_provider.dart';
import '../../../services/today_aggregator_service.dart';
import '../../theme.dart';
import '../../navigation/object_navigation.dart';

class TodayCompletablesComponent extends ConsumerWidget {
  final DashboardBlock block;

  const TodayCompletablesComponent({super.key, required this.block});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final items = ref.watch(todayItemsProvider(today));

    final completables = items.where((i) => i.isCompletable).toList();
    
    final maxItems = block.metadata['maxItems'] as int? ?? 8;
    // includeEvents flag is a no-op for now as events are not completable yet per spec
    // final includeEvents = block.metadata['includeEvents'] as bool? ?? false;

    final completedCount = completables.where((i) => i.isCompleted).length;
    final totalCount = completables.length;
    final progress = totalCount == 0 ? 0.0 : completedCount / totalCount;

    final visibleItems = completables.take(maxItems).toList();

    return Container(
      decoration: AppTheme.cardDecoration(context),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.checklist_rounded, color: AppColors.textMuted, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        block.title.isNotEmpty ? block.title : 'Hoje',
                        style: Theme.of(context).textTheme.titleMedium!.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Text(
                  '$completedCount/$totalCount',
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(color: AppColors.textMuted, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          if (totalCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: AppColors.surfaceVariant,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.success),
                ),
              ),
            ),
          if (completables.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.celebration_rounded, size: 48, color: AppColors.success.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text('All clear for today 🎉', style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: AppColors.textMuted)),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: visibleItems.length,
              padding: EdgeInsets.zero,
              itemBuilder: (context, index) {
                final item = visibleItems[index];

                return InkWell(
                  onTap: () => navigateToObject(context, item.source),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Icon(item.iconData, size: 18, color: item.color),
                        const SizedBox(width: 8),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: item.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item.title,
                            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                              decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                              color: item.isCompleted ? AppColors.textMuted : AppColors.textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (item.isPlayable)
                          IconButton(
                            icon: const Icon(Icons.play_arrow_rounded, color: AppColors.accent, size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            onPressed: () {
                              ref.read(pomodoroProvider.notifier).setCurrentItem(item.id, item.title);
                              ref.read(pomodoroProvider.notifier).start();
                            },
                            tooltip: 'Start Pomodoro',
                          ),
                        Checkbox(
                          value: item.isCompleted,
                          onChanged: (checked) {
                            if (checked == null) return;
                            if (item.kind == TodayItemKind.task) {
                              HapticFeedback.mediumImpact();
                              final task = item.source as Task;
                              ref.read(vaultProvider.notifier).updateObject(
                                task.copyWith(stage: checked ? TaskStage.finalized : TaskStage.todo),
                              );
                            } else if (item.kind == TodayItemKind.habitSlot) {
                              HapticFeedback.lightImpact();
                              final habit = item.source as Habit;
                              final history = List<CompletionRecord>.from(habit.completionHistory);
                              if (checked) {
                                history.add(CompletionRecord(
                                  date: today,
                                  completions: 1,
                                  successful: true,
                                  completedAt: DateTime.now(),
                                ));
                              } else {
                                history.removeWhere((c) => c.date.year == today.year && c.date.month == today.month && c.date.day == today.day);
                              }
                              ref.read(vaultProvider.notifier).updateObject(
                                habit.copyWith(completionHistory: history),
                              );
                            }
                          },
                          activeColor: AppColors.success,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/routine_model.dart';
import '../../models/habit_model.dart';
import '../../models/task_model.dart';
import '../../models/content_object.dart';
import '../../services/routine_execution_service.dart';
import '../../providers/vault_provider.dart';
import '../theme.dart';

class RoutineExecutionSheet extends ConsumerStatefulWidget {
  final Routine routine;
  const RoutineExecutionSheet({super.key, required this.routine});

  @override
  ConsumerState<RoutineExecutionSheet> createState() => _RoutineExecutionSheetState();
}

class _RoutineExecutionSheetState extends ConsumerState<RoutineExecutionSheet> {
  late RoutineExecution _execution;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _execution = RoutineExecutionService.startExecution(widget.routine);
  }

  @override
  Widget build(BuildContext context) {
    final allObjects = ref.watch(allObjectsProvider).value ?? [];

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textMuted.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.routine.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Routine Execution',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Items list
          Flexible(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: widget.routine.items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = widget.routine.items[index];
                return _buildItemCard(item, allObjects);
              },
            ),
          ),

          // Footer actions
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              border: Border(
                top: BorderSide(
                  color: AppColors.textMuted.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: AppColors.textMuted.withValues(alpha: 0.3)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _completeRoutine,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentColor(context),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Complete Routine'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(RoutineItem item, List<ContentObject> allObjects) {
    final referencedObject = RoutineExecutionService.getReferencedObject(
      item.referencedObjectId,
      allObjects,
    );
    final isCompleted = _execution.itemCompletions[item.id] == true;
    final isHabit = RoutineExecutionService.isHabitItem(item, allObjects);

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        dense: true,
        leading: Checkbox(
          value: isCompleted,
          onChanged: (value) => _toggleItem(item, allObjects),
        ),
        title: Text(
          referencedObject?.title ?? item.referencedObjectId,
          style: TextStyle(
            decoration: isCompleted ? TextDecoration.lineThrough : null,
            color: isCompleted ? AppColors.textMuted : null,
          ),
        ),
        subtitle: Row(
          children: [
            Text(
              referencedObject?.type ?? 'Unknown',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            if (item.required) ...[
              const SizedBox(width: 8),
              const Icon(
                Icons.star,
                size: 12,
                color: AppColors.warning,
              ),
            ],
          ],
        ),
        trailing: isHabit
            ? IconButton(
                icon: Icon(
                  isCompleted ? Icons.check_circle : Icons.circle_outlined,
                  color: isCompleted ? AppColors.success : AppColors.textMuted,
                ),
                onPressed: () => _toggleHabit(item, allObjects),
              )
            : referencedObject != null
                ? IconButton(
                    icon: const Icon(Icons.open_in_new, size: 18),
                    onPressed: () {
                      // Navigate to object detail
                      Navigator.pop(context);
                      // TODO: Implement navigation to referenced object
                    },
                  )
                : null,
        onTap: () => _toggleItem(item, allObjects),
        onLongPress: referencedObject != null
            ? () {
                Navigator.pop(context);
                // TODO: Implement navigation to referenced object
              }
            : null,
      ),
    );
  }

  void _toggleItem(RoutineItem item, List<ContentObject> allObjects) {
    setState(() {
      _execution = _execution.copyWith(
        itemCompletions: {
          ..._execution.itemCompletions,
          item.id: !(_execution.itemCompletions[item.id] ?? false),
        },
      );
    });
  }

  Future<void> _toggleHabit(RoutineItem item, List<ContentObject> allObjects) async {
    final habit = RoutineExecutionService.getReferencedObject(
      item.referencedObjectId,
      allObjects,
    );
    if (habit is! Habit) return;

    setState(() => _isLoading = true);

    try {
      await RoutineExecutionService.toggleHabitInExecution(
        _execution,
        habit,
        ref,
      );

      // Update execution state to reflect habit completion
      final isCompleted = RoutineExecutionService.isHabitCompletedToday(habit);
      setState(() {
        _execution = _execution.copyWith(
          itemCompletions: {
            ..._execution.itemCompletions,
            item.id: isCompleted,
          },
        );
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error toggling habit: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _completeRoutine() async {
    setState(() => _isLoading = true);

    try {
      final success = await RoutineExecutionService.completeExecution(
        widget.routine,
        _execution,
        ref,
        context,
      );

      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Routine "${widget.routine.title}" completed!'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error completing routine: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}

/// Show routine execution sheet
Future<void> showRoutineExecutionSheet(
  BuildContext context,
  Routine routine,
) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: RoutineExecutionSheet(routine: routine),
    ),
  );
}

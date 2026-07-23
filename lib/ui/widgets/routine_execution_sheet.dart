import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/routine_model.dart';
import '../../models/checklist_step.dart';
import '../../services/checklist_item_status.dart';
import '../../providers/vault_provider.dart';
import '../widgets/actionable_checklist_tile.dart';
import '../theme.dart';

class RoutineExecutionSheet extends ConsumerStatefulWidget {
  final Routine routine;
  const RoutineExecutionSheet({super.key, required this.routine});

  @override
  ConsumerState<RoutineExecutionSheet> createState() => _RoutineExecutionSheetState();
}

class _RoutineExecutionSheetState extends ConsumerState<RoutineExecutionSheet> {
  late DateTime _runStart;
  final Set<String> _plainStepsDone = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _runStart = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    // The value of the local variable 'allObjects' isn't used right now, but it's safe to remove or keep. I'll remove it.

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
              itemCount: widget.routine.steps.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final step = widget.routine.steps[index];
                return ActionableChecklistTile(
                  itemId: step.id,
                  title: step.title,
                  kind: step.kind,
                  linkedObjectSlug: step.linkedObjectSlug,
                  trackerFieldId: step.trackerFieldId,
                  attachedCollectionSlug: step.attachedCollectionSlug,
                  date: _runStart,
                  parentObjectId: widget.routine.id,
                  plainValue: _plainStepsDone.contains(step.id),
                  onPlainToggle: (done) {
                    setState(() {
                      if (done) {
                        _plainStepsDone.add(step.id);
                      } else {
                        _plainStepsDone.remove(step.id);
                      }
                    });
                  },
                  onTaskCreated: (taskSlug) async {
                    // Update the routine step with the new linked task
                    final updatedSteps = List<ChecklistStep>.from(widget.routine.steps);
                    final stepIndex = updatedSteps.indexWhere((s) => s.id == step.id);
                    if (stepIndex != -1) {
                      updatedSteps[stepIndex] = step.copyWith(linkedObjectSlug: taskSlug);
                      final updated = widget.routine.copyWith(steps: updatedSteps);
                      await ref.read(vaultProvider.notifier).updateObject(updated);
                    }
                  },
                );
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

  Future<void> _completeRoutine() async {
    setState(() => _isLoading = true);

    try {
      final stepCompletions = <String, bool>{};
      for (final step in widget.routine.steps) {
        if (step.kind == 'plain') {
          stepCompletions[step.id] = _plainStepsDone.contains(step.id);
        } else if (step.linkedObjectSlug != null) {
          final isDone = computeChecklistStepDone(
            kind: step.kind,
            linkedObjectSlug: step.linkedObjectSlug,
            trackerFieldId: step.trackerFieldId,
            date: _runStart,
            ref: ref,
            parentObjectId: widget.routine.id,
            itemId: step.id,
          );
          stepCompletions[step.id] = isDone;
        }
      }

      final execution = RoutineExecution(
        executedAt: _runStart,
        stepCompletions: stepCompletions,
      );

      final updatedRoutine = widget.routine.copyWith(
        executionHistory: [...widget.routine.executionHistory, execution],
      );

      await ref.read(vaultProvider.notifier).updateObject(updatedRoutine);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Routine "${widget.routine.title}" completed!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error completing routine: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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

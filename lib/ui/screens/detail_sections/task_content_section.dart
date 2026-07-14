// lib/ui/screens/detail_sections/task_content_section.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/task_model.dart';
import '../../../models/shared_types.dart';
import '../../widgets/wiki_link_picker.dart';
import '../../widgets/wiki_text_view.dart';
import '../../theme.dart';

/// Task-specific content section for universal detail view
List<Widget> buildTaskContentSection(
  BuildContext context,
  WidgetRef ref,
  Task task,
  VoidCallback onApplySystem,
  Widget Function(BuildContext, WidgetRef, List<String>) buildDependsOnList,
  Widget Function(BuildContext, WidgetRef, List<Subtask>) buildSubtaskList,
  Widget Function(BuildContext, Task) buildTimeEstimateCard,
) {
  return [
    SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task.notes.isNotEmpty) ...[
              const Text(
                'Notes',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: AppTheme.cardDecoration(context),
                child: WikiTextView(
                  text: task.notes.join('\n'),
                  style: const TextStyle(fontSize: 15, height: 1.5),
                ),
              ),
              const SizedBox(height: 24),
            ],
            if (task.dependsOn.isNotEmpty) ...[
              const Text(
                'Depende de (Bloqueantes)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              buildDependsOnList(context, ref, task.dependsOn),
              const SizedBox(height: 24),
            ],
            if (task.subtasks.isNotEmpty) ...[
              const Text(
                'Subtasks',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              buildSubtaskList(context, ref, task.subtasks),
            ] else ...[
              OutlinedButton.icon(
                icon: const Icon(Icons.account_tree_rounded, size: 16),
                label: const Text('Aplicar System (Via B)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.accentColor(context),
                  side: BorderSide(
                    color: AppTheme.accentColor(context).withValues(alpha: 0.4),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => onApplySystem(),
              ),
            ],
            // ── V2.8.3 Time Estimates vs Actuals ──
            if (task.estimatedMinutes != null ||
                task.actualMinutes > 0 ||
                (task.pomodoroCount != null &&
                    task.pomodoroCount! > 0)) ...[
              const SizedBox(height: 24),
              const Text(
                'Tempo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              buildTimeEstimateCard(context, task),
            ],
          ],
        ),
      ),
    ),
  ];
}

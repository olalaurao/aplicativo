// lib/ui/screens/detail_views/task_detail_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/task_model.dart';
import '../../models/system_model.dart';
import '../../providers/vault_provider.dart';
import '../forms/create_system_form.dart';
import '../widgets/property_grid.dart';
import '../widgets/subtask_list_view.dart';
import '../theme.dart';

/// Task-specific detail view methods extracted from universal_detail_view.dart
class TaskDetailView {
  /// Build property cards specific to Task objects
  static List<PropertyCard> buildPropertyCards(
    BuildContext context,
    WidgetRef ref,
    Task task,
    Function(BuildContext, WidgetRef, String, String) onPropertyTap,
    Widget Function(Task) buildPriorityBadge,
    List<PropertyCard> Function(BuildContext, Task) buildLinkedGoogleEventCards,
  ) {
    final cards = <PropertyCard>[];
    
    cards.add(PropertyCard(
      icon: Icons.calendar_today_outlined,
      label: 'Criado',
      value: DateFormat('d MMM yyyy').format(task.createdAt),
    ));
    
    cards.add(PropertyCard(
      icon: Icons.event,
      label: 'Prazo',
      value: task.endDate != null ? DateFormat('d MMM yyyy').format(task.endDate!) : 'Não definida',
      state: task.endDate == null ? PropertyCardState.empty : (_isOverdue(task) ? PropertyCardState.overdue : PropertyCardState.normal),
      onTap: () => _showTaskDueDatePicker(context, ref, task),
    ));
    
    cards.add(PropertyCard(
      icon: Icons.play_circle_outline,
      label: 'Início',
      value: task.startDate != null ? DateFormat('d MMM yyyy').format(task.startDate!) : 'Não definida',
      state: task.startDate == null ? PropertyCardState.empty : PropertyCardState.normal,
    ));
    
    cards.add(PropertyCard(
      icon: Icons.priority_high,
      label: 'Prioridade',
      value: '',
      customChild: buildPriorityBadge(task),
    ));
    
    cards.add(PropertyCard(
      icon: Icons.linear_scale,
      label: 'Stage',
      value: _getStatusLabel(task),
      onTap: () => _showEnumPropertyPicker<TaskStage>(
        context: context,
        title: 'Status',
        values: TaskStage.values,
        initialValue: task.stage,
        labelBuilder: (s) => s.name.toUpperCase(),
        onSave: (val) {
          final updated = task.copyWith(stage: val);
          ref.read(vaultProvider.notifier).updateObject(updated);
        },
      ),
    ));
    
    cards.add(PropertyCard(
      icon: Icons.hourglass_empty,
      label: 'Tempo estimado',
      value: task.estimatedMinutes != null ? '${task.estimatedMinutes} min' : 'Não definido',
      state: task.estimatedMinutes == null ? PropertyCardState.empty : PropertyCardState.normal,
    ));
    
    cards.add(PropertyCard(
      icon: Icons.hourglass_full,
      label: 'Tempo real',
      value: task.actualMinutes > 0 ? '${task.actualMinutes} min' : 'Não definido',
      state: task.actualMinutes == 0 ? PropertyCardState.empty : PropertyCardState.normal,
    ));
    
    cards.add(PropertyCard(
      icon: Icons.timer,
      label: 'Pomodoros',
      value: task.pomodoroCount != null && task.pomodoroCount! > 0 ? '${task.pomodoroCount}' : 'Não definido',
      state: task.pomodoroCount == null || task.pomodoroCount == 0 ? PropertyCardState.empty : PropertyCardState.normal,
    ));
    
    cards.addAll(buildLinkedGoogleEventCards(context, task));
    
    return cards;
  }

  /// Build content slivers specific to Task objects
  static List<Widget> buildContentSlivers(
    BuildContext context,
    WidgetRef ref,
    Task task,
    ContentObject object,
    Widget Function(BuildContext, WidgetRef, List<String>) buildDependsOnList,
    Widget Function(BuildContext, WidgetRef, List<Subtask>, ContentObject) buildSubtaskList,
    Widget Function(BuildContext, Task) buildTimeEstimateCard,
    Function(BuildContext, WidgetRef, Task) showApplySystemSheet,
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
                buildSubtaskList(context, ref, task.subtasks, object),
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
                  onPressed: () => showApplySystemSheet(context, ref, task),
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

  /// Handle property tap for Task objects
  static void onPropertyTap(
    BuildContext context,
    WidgetRef ref,
    String key,
    Task task,
  ) {
    if (key == 'Status' || key == 'Estado') {
      _showTaskStatePicker(context, ref, task);
    } else if (key == 'Priority' || key == 'Prioridade') {
      _showTaskPriorityPicker(context, ref, task);
    }
  }

  /// Save Task as System
  static void saveAsSystem(
    BuildContext context,
    Task task,
  ) {
    // Convert Task subtasks to SystemSteps
    final steps = task.subtasks.map((st) => SystemStep(
      title: st.title,
      substeps: [],
    )).toList();

    // Create a new SystemDefinition with pre-filled data
    final system = SystemDefinition(
      title: task.title,
      trigger: '',
      estimatedMinutes: (task.estimatedMinutes ?? 0) > 0 ? task.estimatedMinutes! : 0,
      steps: steps,
      description: task.notes.join('\n'),
    );

    // Open CreateSystemForm with the pre-filled system
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateSystemForm(existingSystem: system),
      ),
    );
  }

  /// Build time estimate card for Task
  static Widget buildTimeEstimateCard(BuildContext context, Task task) {
    final estimated = task.estimatedMinutes ?? 0;
    final actual = task.actualMinutes;

    double progress = 0;
    if (estimated > 0) {
      progress = (actual / estimated).clamp(0.0, 1.0);
    }

    final isOvertime = actual > estimated && estimated > 0;

    String formatTime(int minutes) {
      if (minutes <= 0) return '--';
      if (minutes < 60) return '$minutes min';
      final h = minutes ~/ 60;
      final m = minutes % 60;
      return m > 0 ? '${h}h ${m}min' : '${h}h';
    }

    return Container(
      decoration: AppTheme.cardDecoration(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Estimado',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  Text(
                    formatTime(estimated),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Real',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  Text(
                    formatTime(actual),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isOvertime
                          ? AppColors.warning
                          : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (estimated > 0) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: AppColors.surfaceVariant,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isOvertime ? AppColors.warning : AppTheme.accentColor(context),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Private helper methods

  static bool _isOverdue(Task task) {
    if (task.endDate == null) return false;
    return DateTime.now().isAfter(task.endDate!) && task.stage != TaskStage.finalized;
  }

  static String _getStatusLabel(Task task) {
    return task.stage.name.toUpperCase();
  }

  static void _showEnumPropertyPicker<T>({
    required BuildContext context,
    required String title,
    required List<T> values,
    required T initialValue,
    required String Function(T) labelBuilder,
    required Function(T) onSave,
  }) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ),
          ...values.map((value) => ListTile(
            title: Text(labelBuilder(value)),
            trailing: initialValue == value ? const Icon(Icons.check) : null,
            onTap: () {
              onSave(value);
              Navigator.pop(ctx);
            },
          )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  static void _showTaskStatePicker(BuildContext context, WidgetRef ref, Task task) {
    _showEnumPropertyPicker<TaskStage>(
      context: context,
      title: 'Estado da Tarefa',
      values: TaskStage.values,
      initialValue: task.stage,
      labelBuilder: (value) => _translateStage(value),
      onSave: (value) {
        task.stage = value;
        ref.read(vaultProvider.notifier).updateObject(task);
      },
    );
  }

  static String _translateStage(TaskStage stage) {
    switch (stage) {
      case TaskStage.idea:
        return 'Ideia';
      case TaskStage.backlog:
        return 'Backlog';
      case TaskStage.todo:
        return 'A Fazer';
      case TaskStage.inProgress:
        return 'Em Progresso';
      case TaskStage.pending:
        return 'Pendente';
      case TaskStage.finalized:
        return 'Finalizado';
    }
  }

  static void _showTaskPriorityPicker(BuildContext context, WidgetRef ref, Task task) {
    _showEnumPropertyPicker<TaskPriority>(
      context: context,
      title: 'Task Priority',
      values: TaskPriority.values,
      initialValue: task.priority,
      labelBuilder: (value) => value.name,
      onSave: (value) {
        task.priority = value;
        ref.read(vaultProvider.notifier).updateObject(task);
      },
    );
  }

  static Future<void> _showTaskDueDatePicker(
    BuildContext context,
    WidgetRef ref,
    Task task,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: task.endDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    task.endDate = picked;
    await ref.read(vaultProvider.notifier).updateObject(task);
  }
}

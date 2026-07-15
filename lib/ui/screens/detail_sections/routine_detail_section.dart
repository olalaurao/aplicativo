import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/routine_model.dart';
import '../../../models/scheduler.dart';
import '../../../models/content_object.dart';
import '../../../providers/vault_provider.dart';
import '../../theme.dart';
import '../../widgets/property_grid.dart';
import '../../widgets/routine_execution_sheet.dart';
import 'package:intl/intl.dart';

List<PropertyCard> buildRoutinePropertyCards(
  Routine routine,
  WidgetRef ref,
  BuildContext context,
) {
  final cards = <PropertyCard>[];

  // Scheduler info
  if (routine.scheduler != null) {
    final scheduler = routine.scheduler!;
    final nextOccurrence = _getNextOccurrenceText(scheduler);
    cards.add(PropertyCard(
      icon: Icons.repeat_rounded,
      label: 'Scheduler',
      value: nextOccurrence,
      onTap: null,
    ));
  }

  // Show in planner
  cards.add(PropertyCard(
    icon: routine.showInPlanner ? Icons.event_available : Icons.event_busy,
    label: 'Show in Planner',
    value: routine.showInPlanner ? 'Yes' : 'No',
    onTap: null,
  ));

  // Mood trigger
  if (routine.moodTrigger != null) {
    cards.add(PropertyCard(
      icon: Icons.emoji_emotions_outlined,
      label: 'Mood Trigger',
      value: routine.moodTrigger![0].toUpperCase() + routine.moodTrigger!.substring(1),
      onTap: null,
    ));
  }

  // Item count
  cards.add(PropertyCard(
    icon: Icons.list_alt,
    label: 'Items',
    value: '${routine.items.length}',
    onTap: null,
  ));

  // Execution count
  cards.add(PropertyCard(
    icon: Icons.history,
    label: 'Executions',
    value: '${routine.executionHistory.length}',
    onTap: null,
  ));

  // Last execution
  if (routine.executionHistory.isNotEmpty) {
    final lastExecution = routine.executionHistory.last;
    final dateStr = DateFormat('MMM dd, yyyy').format(lastExecution.executedAt);
    final timeStr = DateFormat('HH:mm').format(lastExecution.executedAt);
    cards.add(PropertyCard(
      icon: Icons.access_time,
      label: 'Last Execution',
      value: '$dateStr at $timeStr',
      onTap: null,
    ));
  }

  return cards;
}

String _getNextOccurrenceText(Scheduler scheduler) {
  if (scheduler.rules.isEmpty) return 'No rules';
  
  final rule = scheduler.rules.first;
  switch (rule.repeatType) {
    case RepeatType.numberOfDays:
      return 'Every ${rule.interval ?? 1} day(s)';
    case RepeatType.daysOfWeek:
      final days = rule.daysOfWeek ?? [];
      return 'On ${days.join(', ')}';
    case RepeatType.numberOfWeeks:
      return 'Every ${rule.interval ?? 1} week(s)';
    case RepeatType.numberOfMonths:
      return 'Every ${rule.interval ?? 1} month(s)';
    case RepeatType.numberOfHours:
      return 'Every ${rule.interval ?? 1} hour(s)';
    default:
      return 'Custom schedule';
  }
}

Widget buildRoutineContentSection(
  Routine routine,
  WidgetRef ref,
  BuildContext context,
) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Execute button
      ElevatedButton.icon(
        onPressed: () => showRoutineExecutionSheet(context, routine),
        icon: const Icon(Icons.play_arrow_rounded),
        label: const Text('Execute Routine'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.accentColor(context),
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      const SizedBox(height: 24),

      if (routine.items.isNotEmpty) ...[
        const Text(
          'Routine Items',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        ...routine.items.map((item) => _buildRoutineItemCard(item, routine, ref, context)),
        const SizedBox(height: 24),
      ],
      
      if (routine.executionHistory.isNotEmpty) ...[
        const Text(
          'Execution History',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        ...routine.executionHistory.reversed.take(5).map((execution) => 
          _buildExecutionCard(execution, context),
        ),
      ],
    ],
  );
}

Widget _buildRoutineItemCard(
  RoutineItem item,
  Routine routine,
  WidgetRef ref,
  BuildContext context,
) {
  final allObjects = ref.watch(allObjectsProvider).value ?? [];
  final wikiLink = item.referencedObjectId;
  
  // Extract ID from WikiLink [[id]]
  final idMatch = RegExp(r'\[\[([^\]|]+)\]\]').firstMatch(wikiLink);
  final objectId = idMatch?.group(1) ?? wikiLink;
  
  final referencedObject = allObjects.where((obj) => obj.id == objectId).firstOrNull;

  return Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      dense: true,
      leading: Icon(
        _getIconForType(referencedObject?.type),
        size: 20,
        color: AppColors.textSecondary,
      ),
      title: Text(
        referencedObject?.title ?? wikiLink,
        style: const TextStyle(fontSize: 14),
      ),
      subtitle: Text(
        referencedObject?.type ?? 'Unknown',
        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.required)
            const Icon(Icons.star, size: 16, color: AppColors.warning),
          if (referencedObject != null)
            IconButton(
              icon: const Icon(Icons.open_in_new, size: 16),
              onPressed: () {
                // Navigate to object detail
                // TODO: Implement navigation to referenced object
              },
            ),
        ],
      ),
    ),
  );
}

Widget _buildExecutionCard(RoutineExecution execution, BuildContext context) {
  final dateStr = DateFormat('MMM dd, yyyy').format(execution.executedAt);
  final timeStr = DateFormat('HH:mm').format(execution.executedAt);
  final completedCount = execution.itemCompletions.values.where((v) => v).length;
  final totalCount = execution.itemCompletions.length;
  final percentage = totalCount > 0 ? (completedCount / totalCount * 100).toInt() : 0;

  return Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      dense: true,
      leading: const Icon(Icons.check_circle_outline, size: 20),
      title: Text(
        '$dateStr at $timeStr',
        style: const TextStyle(fontSize: 14),
      ),
      subtitle: Text(
        'Completed: $completedCount/$totalCount ($percentage%)',
        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
      ),
      trailing: execution.notes != null
        ? const Icon(Icons.note, size: 16, color: AppColors.info)
        : null,
    ),
  );
}

IconData _getIconForType(String? type) {
  switch (type) {
    case 'task':
      return Icons.check_circle_outline;
    case 'habit':
      return Icons.repeat;
    case 'goal':
      return Icons.flag;
    case 'project':
      return Icons.folder;
    case 'note':
      return Icons.description;
    case 'event':
      return Icons.event;
    case 'reminder':
      return Icons.alarm;
    default:
      return Icons.circle_outlined;
  }
}

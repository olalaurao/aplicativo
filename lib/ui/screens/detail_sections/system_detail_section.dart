// lib/ui/screens/detail_sections/system_detail_section.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/system_model.dart';
import '../../widgets/property_grid.dart';

/// System-specific property cards for universal detail view
List<PropertyCard> buildSystemPropertyCards(SystemDefinition system) {
  final cards = <PropertyCard>[];
  
  cards.add(PropertyCard(
    icon: Icons.play_circle_outline,
    label: 'Total Runs',
    value: '${system.runCount}',
    state: system.runCount > 0 ? PropertyCardState.normal : PropertyCardState.empty,
  ));
  
  if (system.lastRun != null) {
    final dateStr = DateFormat('MMM d, yyyy').format(system.lastRun!);
    final timeStr = DateFormat('HH:mm').format(system.lastRun!);
    cards.add(PropertyCard(
      icon: Icons.access_time,
      label: 'Last Run',
      value: '$dateStr $timeStr',
      state: PropertyCardState.normal,
    ));
  }
  
  if (system.averageMinutes > 0) {
    cards.add(PropertyCard(
      icon: Icons.timer,
      label: 'Avg Duration',
      value: '${system.averageMinutes} min',
      state: PropertyCardState.normal,
    ));
  }

  // Execution History card - shows all execution records
  if (system.executionHistory.isNotEmpty) {
    // Sort reverse-chronological
    final sortedHistory = List<SystemExecution>.from(system.executionHistory)
      ..sort((a, b) => b.executedAt.compareTo(a.executedAt));
    
    cards.add(PropertyCard(
      icon: Icons.history,
      label: 'Execution History',
      state: PropertyCardState.normal,
      customChild: _SystemExecutionList(
        executions: sortedHistory,
        steps: system.steps,
      ),
    ));
  }
  
  return cards;
}

class _SystemExecutionList extends StatelessWidget {
  final List<SystemExecution> executions;
  final List<SystemStep> steps;
  
  const _SystemExecutionList({
    required this.executions,
    required this.steps,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: executions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final execution = executions[index];
        final dateStr = DateFormat('MMM d, yyyy').format(execution.executedAt);
        final timeStr = DateFormat('HH:mm').format(execution.executedAt);
        
        // Count completed steps
        final completedCount = execution.stepCompletions.values.where((v) => v).length;
        final totalCount = execution.stepCompletions.length;
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.play_arrow_rounded,
                    size: 12,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$dateStr $timeStr',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$completedCount/$totalCount steps',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
              if (execution.stepCompletions.isNotEmpty) ...[
                const SizedBox(height: 4),
                ...steps.where((s) => execution.stepCompletions.containsKey(s.id)).map((step) {
                  final isDone = execution.stepCompletions[step.id] ?? false;
                  return Padding(
                    padding: const EdgeInsets.only(left: 18, top: 2),
                    child: Row(
                      children: [
                        Icon(
                          isDone ? Icons.check_circle : Icons.circle_outlined,
                          size: 10,
                          color: isDone 
                              ? Colors.green 
                              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            step.title,
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                              decoration: isDone ? null : TextDecoration.lineThrough,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        );
      },
    );
  }
}

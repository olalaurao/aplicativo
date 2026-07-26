// lib/ui/widgets/nlp_chips.dart
//
// Shared NLP chip rendering — used by both CreateTaskForm and QuickCaptureBar.
// Pure display: no state, no providers.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/task_model.dart';
import '../../models/scheduler.dart';
import '../../services/nlp_task_parser.dart';
import '../theme.dart';

// ─── Label helpers ──────────────────────────────────────────────────────────

String priorityChipLabel(TaskPriority priority) {
  switch (priority) {
    case TaskPriority.high:
      return 'High';
    case TaskPriority.medium:
      return 'Medium';
    case TaskPriority.low:
      return 'Low';
    case TaskPriority.none:
      return 'None';
  }
}

Color priorityChipColor(TaskPriority priority, BuildContext context) {
  switch (priority) {
    case TaskPriority.high:
      return AppColors.priorityHigh;
    case TaskPriority.medium:
      return AppColors.priorityMedium;
    case TaskPriority.low:
      return AppColors.priorityLow;
    default:
      return AppColors.textMuted;
  }
}

String schedulerChipLabel(Scheduler scheduler) {
  if (scheduler.rules.isEmpty) return 'Non-recurring';
  final rule = scheduler.rules.first;
  switch (rule.repeatType) {
    case RepeatType.numberOfDays:
      if (rule.interval == 1) return 'Daily';
      return 'Every ${rule.interval} days';
    case RepeatType.daysOfWeek:
      if (rule.daysOfWeek != null && rule.daysOfWeek!.isNotEmpty) {
        final days = rule.daysOfWeek!
            .map((d) {
              switch (d) {
                case 'Mon':
                  return 'Mon';
                case 'Tue':
                  return 'Tue';
                case 'Wed':
                  return 'Wed';
                case 'Thu':
                  return 'Thu';
                case 'Fri':
                  return 'Fri';
                case 'Sat':
                  return 'Sat';
                case 'Sun':
                  return 'Sun';
                case '1':
                  return 'Seg';
                case '2':
                  return 'Ter';
                case '3':
                  return 'Qua';
                case '4':
                  return 'Qui';
                case '5':
                  return 'Sex';
                case '6':
                  return 'Sab';
                case '7':
                  return 'Dom';
                default:
                  return d;
              }
            })
            .join(', ');
        return 'Weekly ($days)';
      }
      return 'Weekly';
    case RepeatType.numberOfWeeks:
      return 'Every ${rule.interval ?? 1} weeks';
    case RepeatType.numberOfMonths:
      return 'Every ${rule.interval ?? 1} months';
    default:
      return 'Recurring';
  }
}

// ─── Single chip ─────────────────────────────────────────────────────────────

Widget buildNlpChip({
  required BuildContext context,
  required IconData icon,
  required String label,
  required Color color,
  VoidCallback? onRemove,
}) {
  return Container(
    padding: EdgeInsets.only(
      left: 8,
      top: 4,
      bottom: 4,
      right: onRemove != null ? 4 : 8,
    ),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        if (onRemove != null) ...[
          const SizedBox(width: 2),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(Icons.close_rounded, size: 12, color: color),
            ),
          ),
        ],
      ],
    ),
  );
}

// ─── NlpChipsRow ─────────────────────────────────────────────────────────────

/// Displays a row of chips for each NLP-detected field in [parsed].
///
/// [onRemoveDate] / [onRemoveTime] / [onRemovePriority] / [onRemoveScheduler]
/// are optional — if provided, each chip shows an X to discard just that
/// detection. Pass null to render read-only chips (as in CreateTaskForm).
class NlpChipsRow extends StatelessWidget {
  final ParsedNlpTask parsed;
  final VoidCallback? onRemoveDate;
  final VoidCallback? onRemoveTime;
  final VoidCallback? onRemovePriority;
  final VoidCallback? onRemoveScheduler;

  const NlpChipsRow({
    super.key,
    required this.parsed,
    this.onRemoveDate,
    this.onRemoveTime,
    this.onRemovePriority,
    this.onRemoveScheduler,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accentColor(context);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (parsed.startDate != null)
          buildNlpChip(
            context: context,
            icon: Icons.calendar_today_rounded,
            label: DateFormat('dd/MM/yyyy').format(parsed.startDate!),
            color: accent,
            onRemove: onRemoveDate,
          ),
        if (parsed.scheduledTime != null)
          buildNlpChip(
            context: context,
            icon: Icons.access_time_rounded,
            label: parsed.scheduledTime!.format(context),
            color: accent,
            onRemove: onRemoveTime,
          ),
        if (parsed.priority != null)
          buildNlpChip(
            context: context,
            icon: Icons.flag_rounded,
            label: priorityChipLabel(parsed.priority!),
            color: priorityChipColor(parsed.priority!, context),
            onRemove: onRemovePriority,
          ),
        if (parsed.scheduler != null)
          buildNlpChip(
            context: context,
            icon: Icons.repeat_rounded,
            label: schedulerChipLabel(parsed.scheduler!),
            color: accent,
            onRemove: onRemoveScheduler,
          ),
      ],
    );
  }
}

// lib/ui/widgets/activity_detail_sheet.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/day_dial_model.dart';
import '../theme.dart';

/// Bottom sheet showing details for a dial activity with edit controls
class ActivityDetailSheet extends StatelessWidget {
  final DialActivity activity;

  const ActivityDetailSheet({
    super.key,
    required this.activity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: 16),
          _buildTimeRow(context, 'Start', activity.startTime),
          _buildTimeRow(context, 'End', activity.endTime),
          _buildDurationRow(context),
          const SizedBox(height: 16),
          _buildActionButtons(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        if (activity.emoji != null)
          Text(
            activity.emoji!,
            style: const TextStyle(fontSize: 32),
          ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                activity.title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor(context),
                ),
              ),
              Text(
                _getActivityTypeLabel(),
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondaryColor(context),
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: activity.color,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeRow(BuildContext context, String label, DateTime time) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondaryColor(context),
              ),
            ),
          ),
          Text(
            DateFormat('HH:mm').format(time),
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.textPrimaryColor(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationRow(BuildContext context) {
    final duration = activity.endTime.difference(activity.startTime);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    String durationText;
    if (hours > 0) {
      durationText = '${hours}h ${minutes}m';
    } else {
      durationText = '${minutes}m';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              'Duration',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondaryColor(context),
              ),
            ),
          ),
          Text(
            durationText,
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.textPrimaryColor(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _adjustTime(context, -15),
            icon: const Icon(Icons.remove, size: 18),
            label: const Text('-15 min'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _adjustTime(context, 15),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('+15 min'),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () => _deleteActivity(context),
          icon: const Icon(Icons.delete),
          color: AppColors.error,
        ),
      ],
    );
  }

  String _getActivityTypeLabel() {
    switch (activity.type) {
      case DialActivityType.habit:
        return 'Habit';
      case DialActivityType.mood:
        return 'Mood';
      case DialActivityType.pomodoroCompleted:
        return 'Completed Pomodoro';
      case DialActivityType.pomodoroPlanned:
        return 'Planned Pomodoro';
      case DialActivityType.event:
        return 'Event';
      case DialActivityType.timeBlock:
        return 'Time Block';
      case DialActivityType.reminder:
        return 'Reminder';
      case DialActivityType.task:
        return 'Task';
    }
  }

  void _adjustTime(BuildContext context, int minutes) {
    // This would need to be handled by the parent widget
    // For now, just show a snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Time adjustment not yet implemented'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _deleteActivity(BuildContext context) {
    // This would need to be handled by the parent widget
    // For now, just show a snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Delete not yet implemented'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

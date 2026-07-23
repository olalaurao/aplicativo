import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/content_object.dart';
import '../../models/shared_types.dart';
import '../theme.dart';

class ObjectEventLogSheet extends StatelessWidget {
  final ContentObject object;

  const ObjectEventLogSheet({super.key, required this.object});

  static void show(BuildContext context, ContentObject object) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ObjectEventLogSheet(object: object),
    );
  }

  @override
  Widget build(BuildContext context) {
    final logs = List<EventLogEntry>.from(object.eventLog)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp)); // Newest first

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context),
          Expanded(
            child: logs.isEmpty
                ? const Center(
                    child: Text(
                      'No events recorded yet.',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      return _buildLogEntryTile(context, logs[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppTheme.dividerColor(context),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Event History',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildLogEntryTile(BuildContext context, EventLogEntry entry) {
    IconData icon;
    Color iconColor;

    switch (entry.action) {
      case 'created':
        icon = Icons.add_circle_outline;
        iconColor = AppColors.success;
        break;
      case 'stage_change':
        icon = Icons.linear_scale;
        iconColor = AppColors.info;
        break;
      case 'priority_change':
        icon = Icons.priority_high;
        iconColor = AppColors.warning;
        break;
      case 'habit_toggled':
      case 'checklist_toggled':
        icon = Icons.check_circle_outline;
        iconColor = AppColors.habitOrange;
        break;
      case 'rescheduled':
        icon = Icons.edit_calendar;
        iconColor = AppColors.habitPurple;
        break;
      default:
        icon = Icons.history;
        iconColor = AppColors.textMuted;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.description,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('dd MMM yyyy, HH:mm').format(entry.timestamp),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

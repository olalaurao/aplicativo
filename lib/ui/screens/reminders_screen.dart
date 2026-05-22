import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/reminder_model.dart';
import '../../providers/vault_provider.dart';
import '../forms/create_reminder_form.dart';
import '../theme.dart';
import 'universal_detail_view.dart';

class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminders = [...ref.watch(aggregatedRemindersProvider)]
      ..sort((a, b) => a.time.compareTo(b.time));
    final now = DateTime.now();
    final active = reminders
        .where((r) => !r.isCompleted && !r.time.isBefore(now))
        .toList();
    final expired =
        reminders.where((r) => r.isCompleted || r.time.isBefore(now)).toList()
          ..sort((a, b) => b.time.compareTo(a.time));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('Reminders'),
          centerTitle: true,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Active'),
              Tab(text: 'Expired'),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'New reminder',
              icon: const Icon(Icons.add_rounded),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateReminderForm()),
              ),
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _ReminderList(reminders: active, emptyText: 'No active reminders'),
            _ReminderList(
              reminders: expired,
              emptyText: 'No expired reminders',
            ),
          ],
        ),
      ),
    );
  }
}

class _ReminderList extends ConsumerWidget {
  final List<Reminder> reminders;
  final String emptyText;

  const _ReminderList({required this.reminders, required this.emptyText});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (reminders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            emptyText,
            style: const TextStyle(color: AppColors.textMuted),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: reminders.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final reminder = reminders[index];
        final overdue =
            reminder.time.isBefore(DateTime.now()) && !reminder.isCompleted;
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UniversalDetailView(object: reminder),
            ),
          ),
          child: Container(
            decoration: AppTheme.cardDecoration(context),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                IconButton(
                  tooltip: reminder.isCompleted
                      ? 'Restore reminder'
                      : 'Mark as done',
                  icon: Icon(
                    reminder.isCompleted
                        ? Icons.radio_button_unchecked_rounded
                        : Icons.check_circle_outline_rounded,
                    color: reminder.isCompleted
                        ? AppColors.textMuted
                        : AppColors.primary,
                  ),
                  onPressed: () {
                    reminder.isCompleted = !reminder.isCompleted;
                    reminder.updatedAt = DateTime.now();
                    ref
                        .read(remindersProvider.notifier)
                        .updateReminder(reminder);
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reminder.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          decoration: reminder.isCompleted
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('MMM d, yyyy HH:mm').format(reminder.time),
                        style: TextStyle(
                          color: overdue
                              ? AppColors.priorityHigh
                              : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: overdue
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (reminder.scheduler != null)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(
                      Icons.repeat_rounded,
                      size: 18,
                      color: AppColors.textMuted,
                    ),
                  ),
                if (reminder.timeBlockId != null)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(
                      Icons.view_timeline_outlined,
                      size: 18,
                      color: AppColors.textMuted,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

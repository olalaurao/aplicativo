import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/habit_model.dart';
import '../../models/journal_entry.dart';
import '../../models/task_model.dart';
import '../../providers/pomodoro_provider.dart';
import '../../providers/vault_provider.dart';
import '../../services/notification_service.dart';
import '../../services/pomodoro_bg_service.dart';
import '../../services/sync_manager.dart';
import '../forms/create_entry_form.dart';
import '../forms/create_habit_form.dart';
import '../forms/create_task_form.dart';
import '../theme.dart';
import '../widgets/create_menu_sheet.dart';
import '../widgets/steering_sheet.dart';

final _quickAddSubmittingProvider = StateProvider<bool>((ref) => false);
final _quickTaskSubmittingProvider = StateProvider<bool>((ref) => false);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  final TextEditingController _quickEntryController = TextEditingController();
  final TextEditingController _quickTaskController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkIncomingAction();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _quickEntryController.dispose();
    _quickTaskController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkIncomingAction();
    }
  }

  Future<void> _checkIncomingAction() async {
    if (!mounted) return;

    try {
      final uri = GoRouterState.of(context).uri;
      final actionParam = uri.queryParameters['action'];
      if (actionParam != null) {
        _handleAction(actionParam);
      }
    } catch (e) {
      debugPrint('HomeScreen: GoRouter state not ready: $e');
    }

    await ref.read(vaultProvider.notifier).processPendingNotificationActions();

    final pomoState = ref.read(pomodoroProvider);
    if (!pomoState.isRunning) {
      PomodoroBackgroundService.stop();
    }

    final pending = await NotificationService().takePendingActions();
    for (final item in pending) {
      final action = item['action']?.toString();
      final payload = item['payload']?.toString();
      if (action != null) {
        _handleAction(action, payload: payload);
      }
    }

    _checkExpiredPacts();
  }

  void _checkExpiredPacts() {
    final habits = ref.read(habitsProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiredPacts = habits
        .where(
          (habit) =>
              habit.habitMode == HabitMode.pact &&
              habit.status == HabitStatus.active &&
              habit.endsAt != null &&
              habit.endsAt!.isBefore(today) &&
              habit.pactOutcome == null,
        )
        .toList();

    if (expiredPacts.isNotEmpty) {
      final pactToReview = expiredPacts.first;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showSteeringSheet(context, pactToReview);
        }
      });
    }
  }

  void _handleAction(String action, {String? payload}) {
    if (action == 'new_entry') {
      _showForm(const CreateEntryForm());
    } else if (action == 'new_task') {
      _showForm(const CreateTaskForm());
    } else if (action == 'new_habit') {
      _showForm(const CreateHabitForm());
    } else if (action == 'quick_entry_text' && payload != null) {
      _submitQuickEntry(payload);
    } else if (action == 'quick_task_text' && payload != null) {
      _submitQuickTask(payload);
    } else if (action == 'open' &&
        payload != null &&
        payload.startsWith('steering_sheet?id=')) {
      final id = payload.replaceFirst('steering_sheet?id=', '');
      final pact = ref
          .read(habitsProvider)
          .where((h) => h.id == id)
          .firstOrNull;
      if (pact != null) {
        showSteeringSheet(context, pact);
      }
    }
  }

  void _showForm(Widget form) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => form,
    );
  }

  Future<void> _submitQuickEntry([String? forcedText]) async {
    final text = (forcedText ?? _quickEntryController.text).trim();
    if (text.isEmpty) return;

    final submitting = ref.read(_quickAddSubmittingProvider);
    if (submitting) return;

    ref.read(_quickAddSubmittingProvider.notifier).state = true;
    try {
      final now = DateTime.now();
      final entry = JournalEntry(
        title: 'Quick entry',
        body: text,
        date: DateTime(now.year, now.month, now.day),
        timeOfDay:
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
      );
      await ref.read(todayJournalProvider.notifier).addEntry(entry);
      _quickEntryController.clear();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Entry saved.')));
      }
    } catch (e) {
      debugPrint('Quick entry failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not save entry.')));
      }
    } finally {
      ref.read(_quickAddSubmittingProvider.notifier).state = false;
    }
  }

  Future<void> _submitQuickTask([String? forcedText]) async {
    final text = (forcedText ?? _quickTaskController.text).trim();
    if (text.isEmpty) return;

    final submitting = ref.read(_quickTaskSubmittingProvider);
    if (submitting) return;

    ref.read(_quickTaskSubmittingProvider.notifier).state = true;
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final task = Task(title: text, stage: TaskStage.todo, endDate: today);
      await ref.read(tasksProvider.notifier).addTask(task);
      _quickTaskController.clear();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Task saved for today.')));
      }
    } catch (e) {
      debugPrint('Quick task failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not save task.')));
      }
    } finally {
      ref.read(_quickTaskSubmittingProvider.notifier).state = false;
    }
  }

  Future<void> _refresh() async {
    await ref.read(syncManagerProvider).performSync();
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(tasksProvider);
    final habits = ref.watch(habitsProvider);
    final inboxCount = ref.watch(inboxCountProvider);
    final pendingTasks = tasks
        .where((task) => task.stage != TaskStage.finalized && !task.archived)
        .length;
    final activeHabits = habits
        .where((habit) => habit.status == HabitStatus.active && !habit.archived && !habit.isNegative)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            onPressed: () => showCreateMenu(context),
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Create',
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _QuickCaptureCard(
                title: 'Quick entry',
                hintText: 'What is on your mind?',
                controller: _quickEntryController,
                isSubmitting: ref.watch(_quickAddSubmittingProvider),
                icon: Icons.edit_note_rounded,
                onSubmit: () => _submitQuickEntry(),
              ),
              const SizedBox(height: 12),
              _QuickCaptureCard(
                title: 'Quick task',
                hintText: 'What needs to happen today?',
                controller: _quickTaskController,
                isSubmitting: ref.watch(_quickTaskSubmittingProvider),
                icon: Icons.check_box_outlined,
                onSubmit: () => _submitQuickTask(),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _SummaryTile(
                      label: 'Tasks',
                      value: '$pendingTasks',
                      icon: Icons.check_circle_outline_rounded,
                      onTap: () => context.push('/planner'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SummaryTile(
                      label: 'Habits',
                      value: '$activeHabits',
                      icon: Icons.repeat_rounded,
                      onTap: () => context.push('/habits'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SummaryTile(
                      label: 'Inbox',
                      value: '$inboxCount',
                      icon: Icons.inbox_rounded,
                      onTap: () => context.push('/inbox'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _ActionList(
                actions: [
                  _HomeAction(
                    label: 'Planner',
                    icon: Icons.view_day_rounded,
                    onTap: () => context.push('/planner'),
                  ),
                  _HomeAction(
                    label: 'Journal',
                    icon: Icons.auto_stories_rounded,
                    onTap: () => context.push('/timeline'),
                  ),
                  _HomeAction(
                    label: 'Organizers',
                    icon: Icons.account_tree_rounded,
                    onTap: () => context.push('/organize'),
                  ),
                  _HomeAction(
                    label: 'More',
                    icon: Icons.more_horiz_rounded,
                    onTap: () => context.push('/more'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickCaptureCard extends StatelessWidget {
  final String title;
  final String hintText;
  final TextEditingController controller;
  final bool isSubmitting;
  final IconData icon;
  final VoidCallback onSubmit;

  const _QuickCaptureCard({
    required this.title,
    required this.hintText,
    required this.controller,
    required this.isSubmitting,
    required this.icon,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecoration(context),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.accentColor(context)),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 3,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => onSubmit(),
              decoration: InputDecoration(
                labelText: title,
                hintText: hintText,
                border: InputBorder.none,
              ),
            ),
          ),
          IconButton(
            onPressed: isSubmitting
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    onSubmit();
                  },
            icon: isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded),
            color: AppTheme.accentColor(context),
            tooltip: 'Save',
          ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const _SummaryTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.cardFillColor(context),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Icon(icon, color: AppTheme.accentColor(context), size: 20),
              const SizedBox(height: 8),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimaryColor(context),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeAction {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _HomeAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });
}

class _ActionList extends StatelessWidget {
  final List<_HomeAction> actions;

  const _ActionList({required this.actions});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecoration(context),
      child: Column(
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            ListTile(
              leading: Icon(actions[i].icon, color: AppTheme.accentColor(context)),
              title: Text(
                actions[i].label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: actions[i].onTap,
            ),
            if (i != actions.length - 1)
              Divider(
                height: 1,
                indent: 56,
                color: AppTheme.dividerColor(context),
              ),
          ],
        ],
      ),
    );
  }
}

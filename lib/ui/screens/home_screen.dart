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
import '../../providers/sync_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../services/sync_manager.dart';
import '../../models/dashboard_block.dart';
import '../forms/create_entry_form.dart';
import '../forms/create_habit_form.dart';
import '../forms/create_task_form.dart';
import '../theme.dart';
import '../widgets/create_menu_sheet.dart';
import '../widgets/steering_sheet.dart';
import '../widgets/dashboard/today_timeline_component.dart';
import '../widgets/dashboard/today_completables_component.dart';
import '../widgets/dashboard/day_dial_component.dart';
import '../widgets/dashboard/shopping_quick_add_component.dart';
import '../widgets/dashboard/week_overview_component.dart';
import '../widgets/dashboard/month_overview_component.dart';
import '../widgets/dashboard/goals_projects_overview_component.dart';
import '../widgets/dashboard/dashboard_component_config_sheet.dart';
import '../widgets/dashboard/pinned_object_component.dart';
import '../widgets/dashboard/tracker_analysis_component.dart';
import '../forms/create_habit_form.dart';
import '../forms/create_task_form.dart';
import '../theme.dart';
import '../widgets/create_menu_sheet.dart';
import '../widgets/steering_sheet.dart';
import '../../features/overdue/widgets/overdue_section.dart';

final _quickAddSubmittingProvider = StateProvider<bool>((ref) => false);
final _quickTaskSubmittingProvider = StateProvider<bool>((ref) => false);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  final TextEditingController _quickEntryController = TextEditingController();
  final TextEditingController _quickTaskController = TextEditingController();
  bool _editMode = false;

  @override
  bool get wantKeepAlive => true;

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
      await ref.read(vaultProvider.notifier).createObject(task);
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
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final blocksState = ref.watch(dashboardProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: _buildSyncIcon(),
        actions: [
          IconButton(
            icon: Icon(_editMode ? Icons.done_rounded : Icons.tune_rounded),
            tooltip: _editMode ? 'Done editing' : 'Edit dashboard',
            onPressed: () => setState(() => _editMode = !_editMode),
          ),
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
          child: blocksState.when(
            data: (blocks) {
              if (blocks.isEmpty) {
                // Seed default
                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  await ref.read(dashboardProvider.notifier).addBlock(BlockType.todayTimeline, 'Timeline');
                  await ref.read(dashboardProvider.notifier).addBlock(BlockType.todayDial, 'Day Dial');
                  await ref.read(dashboardProvider.notifier).addBlock(BlockType.todayCompletables, 'Today\'s Completables');
                });
                return const Center(child: CircularProgressIndicator());
              }

              final visibleBlocks = _editMode ? blocks : blocks.where((b) => b.visible).toList();

              if (_editMode) {
                // Edit mode: use ReorderableListView for drag-to-reorder
                return ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                  itemCount: visibleBlocks.length + 1,
                  onReorder: (oldIndex, newIndex) {
                    if (oldIndex < visibleBlocks.length && newIndex <= visibleBlocks.length) {
                      ref.read(dashboardProvider.notifier).reorderBlocks(oldIndex, newIndex);
                    }
                  },
                  itemBuilder: (context, index) {
                    if (index == visibleBlocks.length) {
                      return Padding(
                        key: const ValueKey('add_component_button'),
                        padding: const EdgeInsets.only(top: 16),
                        child: InkWell(
                          onTap: () => AddComponentSheet.show(context),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.textMuted.withValues(alpha: 0.3)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_rounded, color: AppTheme.accentColor(context)),
                                const SizedBox(width: 8),
                                Text('Add component', style: TextStyle(color: AppTheme.accentColor(context), fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    final block = visibleBlocks[index];
                    return Container(
                      key: ValueKey(block.id),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.accent, width: 2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Stack(
                        children: [
                          Opacity(opacity: block.visible ? 1.0 : 0.5, child: _buildComponent(block)),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(block.visible ? Icons.visibility_rounded : Icons.visibility_off_rounded, color: AppColors.textPrimary),
                                  style: IconButton.styleFrom(backgroundColor: AppColors.surface),
                                  onPressed: () => ref.read(dashboardProvider.notifier).toggleVisibility(block.id),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(Icons.settings_rounded, color: AppColors.textPrimary),
                                  style: IconButton.styleFrom(backgroundColor: AppColors.surface),
                                  onPressed: () => DashboardComponentConfigSheet.show(context, block),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(Icons.delete_rounded, color: AppColors.error),
                                  style: IconButton.styleFrom(backgroundColor: AppColors.surface),
                                  onPressed: () => ref.read(dashboardProvider.notifier).removeBlock(block.id),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              } else {
                // Normal mode: use simple CustomScrollView — NO ReorderableListView semantics overhead
                return CustomScrollView(
                  slivers: [
                    // Overdue section at the top
                    const SliverToBoxAdapter(
                      child: OverdueSection(),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final block = visibleBlocks[index];
                            return Padding(
                              key: ValueKey(block.id),
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildComponent(block),
                            );
                          },
                          childCount: visibleBlocks.length,
                        ),
                      ),
                    ),
                  ],
                );
              }
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err')),
          ),
        ),
      ),
    );
  }

  Widget _buildSyncIcon() {
    return Consumer(
      builder: (context, ref, _) {
        final status = ref.watch(syncStatusProvider);
        final progress = ref.watch(syncProgressProvider);
        final (icon, color, tooltip) = switch (status) {
          SyncStatus.synced   => (Icons.cloud_done_rounded,   AppColors.success, 'Synced'),
          SyncStatus.syncing  => (Icons.cloud_sync_rounded,   AppTheme.accentColor(context), 'Syncing…'),
          SyncStatus.offline  => (Icons.cloud_off_rounded,    AppColors.textMuted, 'Offline — will sync when back online'),
          SyncStatus.error    => (Icons.cloud_off_rounded,    AppColors.error, 'Sync error — tap for details'),
          SyncStatus.conflict => (Icons.warning_amber_rounded, AppColors.warning, 'Sync conflict — tap to resolve'),
        };

        String progressTooltip = tooltip;
        if (status == SyncStatus.syncing && progress.total > 0) {
          final percentage = (progress.percentage * 100).toInt();
          progressTooltip = '${progress.message} $percentage% (${progress.current}/${progress.total})';
        }

        return IconButton(
          icon: status == SyncStatus.syncing
              ? Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: AppIconSize.md,
                      height: AppIconSize.md,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        value: progress.total > 0 ? progress.percentage : null,
                      ),
                    ),
                    if (progress.total > 0)
                      Text(
                        '${(progress.percentage * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.accentColor(context),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                )
              : Icon(icon, color: color),
          tooltip: progressTooltip,
          onPressed: status == SyncStatus.conflict || status == SyncStatus.error
              ? () => context.push('/sync-conflicts')
              : null,
        );
      },
    );
  }

  Widget _buildComponent(DashboardBlock block) {
    switch (block.type) {
      case BlockType.todayTimeline: return TodayTimelineComponent(block: block);
      case BlockType.todayDial: return DayDialComponent(block: block);
      case BlockType.shoppingQuickAdd: return ShoppingQuickAddComponent(block: block);
      case BlockType.weekOverview: return WeekOverviewComponent(block: block);
      case BlockType.monthOverview: return MonthOverviewComponent(block: block);
      case BlockType.goalsProjectsOverview: return GoalsProjectsOverviewComponent(block: block);
      case BlockType.todayCompletables: return TodayCompletablesComponent(block: block);
      case BlockType.todayHabits: return TodayCompletablesComponent(block: block);
      case BlockType.pinnedObject: return PinnedObjectComponent(block: block);
      case BlockType.trackerAnalysis: return TrackerAnalysisComponent(block: block);
      default: return Container(
        height: 100,
        decoration: AppTheme.cardDecoration(context),
        alignment: Alignment.center,
        child: Text('Unknown component: ${block.type.name}'),
      );
    }
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

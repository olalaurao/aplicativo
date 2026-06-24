import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/vault_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../models/habit_model.dart';
import '../../models/task_model.dart';
import '../../models/goal_model.dart';
import '../../models/journal_entry.dart';
import '../../models/content_object.dart';
import '../../models/note_model.dart';
import '../../models/dashboard_block.dart';
import '../../models/organizer_model.dart';
import '../theme.dart';
import '../widgets/create_menu_sheet.dart';
import '../widgets/object_action_wrapper.dart';
import '../widgets/timeline_card.dart';
import 'universal_detail_view.dart';
import '../widgets/citrine_chart.dart';
import '../widgets/journal_body_view.dart';
import '../widgets/habit_detail_sheet.dart';
import '../widgets/calendar_widget.dart';
import '../../models/mood_model.dart';
import '../../models/navigation_item.dart';
import '../widgets/navigation_shortcut_picker.dart';
import '../widgets/command_center_overlay.dart';

import 'planner_screen.dart';
import 'habits_screen.dart';
import 'people_screen.dart';
import 'resources_screen.dart';
import 'trackers_screen.dart';
import 'notes_screen.dart';
import 'pomodoro_screen.dart';
import 'journal_screen.dart';
import 'goals_screen.dart';
import '../../models/tracker_model.dart';
import '../../models/resource_model.dart';
import '../../providers/pomodoro_provider.dart';
import '../../models/pomodoro_session.dart';
import '../widgets/tracker_metric_card.dart';
import '../../providers/sync_provider.dart';
import '../../services/sync_manager.dart';
import '../../providers/google_calendar_provider.dart';
import '../../services/notification_service.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/empty_state_view.dart';
import '../../services/pomodoro_bg_service.dart';
import '../../services/scheduler_service.dart';
import '../forms/create_entry_form.dart';
import '../forms/create_task_form.dart';
import '../forms/create_habit_form.dart';
import '../widgets/pomodoro_week_overview.dart';
import '../widgets/organizer_tasks_widget.dart';
import '../widgets/dashboard/shopping_list_block.dart';
import '../widgets/universal_search_picker.dart';
import '../widgets/energy_map.dart';
import '../../models/day_theme_model.dart';
import '../../models/system_model.dart';
import '../../providers/systems_provider.dart';
import 'system_detail_screen.dart';
import '../widgets/steering_sheet.dart';
import '../../services/markdown_parser.dart';
import '../../providers/settings_provider.dart';


class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

final _quickAddSubmittingProvider = StateProvider<bool>((ref) => false);
final _quickTaskSubmittingProvider = StateProvider<bool>((ref) => false);

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  bool _isEditMode = false;
  bool _commandCenterOpenedThisScroll = false;
  final TextEditingController _quickAddController = TextEditingController();
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
    _quickAddController.dispose();
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

    // 1. Check URI (QuickActions/DeepLinks)
    try {
      final uri = GoRouterState.of(context).uri;
      final actionParam = uri.queryParameters['action'];
      if (actionParam != null) {
        _handleAction(actionParam);
      }
    } catch (e) {
      // GoRouter state might not be ready yet in some contexts
      debugPrint('HomeScreen: GoRouter state not ready: $e');
    }

    // 2. Check and Process via VaultNotifier (Handles background actions like quick add)
    await ref.read(vaultProvider.notifier).processPendingNotificationActions();

    // Safety: ensure pomodoro background service is stopped if not running
    final pomoState = ref.read(pomodoroProvider);
    if (!pomoState.isRunning) {
      PomodoroBackgroundService.stop();
    }

    // 3. Check Pending Navigation Actions
    final pending = await NotificationService().takePendingActions();
    for (final item in pending) {
      final action = item['action']?.toString();
      final payload = item['payload']?.toString();
      if (action != null) {
        _handleAction(action, payload: payload);
      }
    }

    // 4. Check for expired pacts
    _checkExpiredPacts();
  }

  void _checkExpiredPacts() {
    final habits = ref.read(habitsProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiredPacts = habits.where((h) =>
        h.habitMode == HabitMode.pact &&
        h.status == HabitStatus.active &&
        h.endsAt != null &&
        h.endsAt!.isBefore(today) &&
        h.pactOutcome == null).toList();

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
      _showForm(context, const CreateEntryForm());
    } else if (action == 'new_task') {
      _showForm(context, const CreateTaskForm());
    } else if (action == 'new_habit') {
      _showForm(context, const CreateHabitForm());
    } else if (action == 'quick_entry_text' && payload != null) {
      _submitQuickAdd(payload);
    } else if (action == 'quick_task_text' && payload != null) {
      _submitQuickTask(payload);
    } else if (action == 'open' && payload != null && payload.startsWith('steering_sheet?id=')) {
      final id = payload.replaceFirst('steering_sheet?id=', '');
      final habits = ref.read(habitsProvider);
      final pact = habits.where((h) => h.id == id).firstOrNull;
      if (pact != null) {
        showSteeringSheet(context, pact);
      }
    }
  }

  void _showForm(BuildContext context, Widget form) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => form,
    );
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(dashboardProvider);

    return dashboardAsync.when(
      data: (allBlocks) {
        final dashboardBlocks = allBlocks
            .where((b) => b.visible || _isEditMode)
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order));

        if (dashboardBlocks.isEmpty) {
          return const Center(
            child: Text(
              'O Dashboard está vazio.\nAdicione blocos pelas Configurações.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted),
            ),
          );
        }

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: const Text('Dashboard'),
            centerTitle: true,
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor: Colors.transparent,
          ),
          body: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.pixels >= 0) _commandCenterOpenedThisScroll = false;
              if (notification.metrics.pixels < -140 &&
                  notification is ScrollUpdateNotification && notification.dragDetails != null &&
                  !_commandCenterOpenedThisScroll &&
                  ModalRoute.of(context)?.isCurrent == true) {
                _commandCenterOpenedThisScroll = true;
                showCommandCenter(context);
              }
              return false;
            },
            child: RefreshIndicator(
              onRefresh: () async {
                await ref.read(syncManagerProvider).performSync();
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                // ─── Header ───
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(child: _buildGreeting(context, ref)),
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            _buildSyncIndicator(ref),
                            if (_isEditMode) IconButton(icon: const Icon(Icons.add_box_rounded, color: AppColors.primary), tooltip: 'Add widget', onPressed: () => _showAddWidgetSheet(context)),
                            IconButton(icon: Icon(_isEditMode ? Icons.check_rounded : Icons.tune_rounded, color: _isEditMode ? AppColors.primary : AppColors.textMuted), onPressed: () => setState(() => _isEditMode = !_isEditMode)),
                          ]),
                        ]),
                        if (_isEditMode)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Drag to reorder or tap ⋯ to configure',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.primary.withValues(alpha: 0.8),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // ─── Blocks ───
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  sliver: _isEditMode
                      ? SliverReorderableList(
                          itemCount: dashboardBlocks.length,
                          itemBuilder: (context, index) {
                            final block = dashboardBlocks[index];
                            return ReorderableDelayedDragStartListener(
                              key: ValueKey(block.id),
                              index: index,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Stack(
                                  children: [
                                    _buildBlock(block),
                                    Positioned(
                                      top: 0,
                                      right: 0,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _editModeButton(
                                            icon: block.visible
                                                ? Icons.visibility_rounded
                                                : Icons.visibility_off_rounded,
                                            color: block.visible
                                                ? AppColors.primary
                                                : AppColors.textMuted,
                                            onTap: () => ref
                                                .read(
                                                  dashboardProvider.notifier,
                                                )
                                                .toggleVisibility(block.id),
                                          ),
                                          const SizedBox(width: 4),
                                          _editModeButton(
                                            icon: Icons.close_rounded,
                                            color: AppColors.error,
                                            onTap: () => ref
                                                .read(
                                                  dashboardProvider.notifier,
                                                )
                                                .removeBlock(block.id),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          onReorder: (oldIndex, newIndex) {
                            ref
                                .read(dashboardProvider.notifier)
                                .reorderBlocks(oldIndex, newIndex);
                          },
                        )
                      : MediaQuery.of(context).size.width > 600
                      ? SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 450,
                                mainAxisSpacing: 16,
                                crossAxisSpacing: 16,
                                mainAxisExtent: 260,
                              ),
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            return _buildBlock(dashboardBlocks[index]);
                          }, childCount: dashboardBlocks.length),
                        )
                      : SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _buildBlock(dashboardBlocks[index]),
                            );
                          }, childCount: dashboardBlocks.length),
                        ),
                ),
              ],
            ),
            ), // Close RefreshIndicator
          ),
        );
      },
      loading: () => _buildDashboardSkeleton(),
      error: (e, s) =>
          Scaffold(body: Center(child: Text('Error loading dashboard: $e'))),
    );
  }

  Widget _buildGreeting(BuildContext context, WidgetRef ref) {
    final hour     = DateTime.now().hour;
    final greeting = hour < 12 ? 'Bom dia' : hour < 18 ? 'Boa tarde' : 'Boa noite';
    final name     = ref.watch(settingsProvider).userName ?? '';
    final dateStr  = DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(DateTime.now());

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('$greeting${name.isNotEmpty ? ", $name" : ""}',
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
          color: AppTheme.textPrimaryColor(context))),
      const SizedBox(height: 2),
      Text(dateStr, style: TextStyle(fontSize: 13,
        color: AppTheme.textMutedColor(context), fontWeight: FontWeight.w500)),
    ]);
  }

  Widget _buildDashboardSkeleton() {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Dashboard'),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: ListView.separated(
        key: const PageStorageKey('dashboard-loading-skeleton'),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: 4,
        separatorBuilder: (_, _) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final heights = [132.0, 116.0, 156.0, 116.0];
          return Container(
            constraints: BoxConstraints(minHeight: heights[index]),
            decoration: AppTheme.cardDecoration(context),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _skeletonLine(width: 140, height: 14),
                const SizedBox(height: 16),
                _skeletonLine(width: double.infinity, height: 12),
                const SizedBox(height: 10),
                _skeletonLine(width: 220, height: 12),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _skeletonLine({required double width, required double height}) {
    return SkeletonLoader(width: width, height: height, borderRadius: 6);
  }

  Widget _editModeButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }

  void _showAddWidgetSheet(BuildContext context) {
    final categories = <String, List<Map<String, dynamic>>>{
      'Productivity': [
        {
          'type': BlockType.tasks,
          'title': 'Tasks',
          'icon': Icons.check_circle_outline_rounded,
        },
        {
          'type': BlockType.habits,
          'title': 'Habits',
          'icon': Icons.loop_rounded,
        },
        {
          'type': BlockType.goals,
          'title': 'Goals',
          'icon': Icons.track_changes_rounded,
        },
        {
          'type': BlockType.timer,
          'title': 'Focus Now',
          'icon': Icons.timer_rounded,
        },
        {
          'type': BlockType.pomodoroSummary,
          'title': 'Pomodoro Summary',
          'icon': Icons.bar_chart_rounded,
        },
        {
          'type': BlockType.dailyGoal,
          'title': 'Daily Goal',
          'icon': Icons.auto_awesome_rounded,
        },
      ],
      'Planning': [
        {
          'type': BlockType.plannerDay,
          'title': 'Day Planner',
          'icon': Icons.today_rounded,
        },
        {
          'type': BlockType.plannerWeek,
          'title': 'Week',
          'icon': Icons.date_range_rounded,
        },
        {
          'type': BlockType.plannerMonth,
          'title': 'Month',
          'icon': Icons.calendar_month_rounded,
        },
        {
          'type': BlockType.calendar,
          'title': 'Schedule',
          'icon': Icons.calendar_today_rounded,
        },
        {
          'type': BlockType.googleCalendar,
          'title': 'Google Calendar',
          'icon': Icons.event_rounded,
        },
        {
          'type': BlockType.timeBlocking,
          'title': 'Time Blocks',
          'icon': Icons.view_timeline_rounded,
        },
      ],
      'Analytics': [
        {
          'type': BlockType.kpi,
          'title': 'KPIs',
          'icon': Icons.analytics_rounded,
        },
        {
          'type': BlockType.analysisTrend,
          'title': 'Insights',
          'icon': Icons.auto_graph_rounded,
        },
        {
          'type': BlockType.habitTrend,
          'title': 'Habit Activity',
          'icon': Icons.grid_on_rounded,
        },
        {
          'type': BlockType.trackerField,
          'title': 'Last Metric',
          'icon': Icons.show_chart_rounded,
        },
        {
          'type': BlockType.energyMap,
          'title': 'Energy Map',
          'icon': Icons.bolt_rounded,
        },
      ],
      'Content': [
        {
          'type': BlockType.timeline,
          'title': 'Timeline',
          'icon': Icons.timeline_rounded,
        },
        {
          'type': BlockType.notes,
          'title': 'Notes',
          'icon': Icons.sticky_note_2_rounded,
        },
        {
          'type': BlockType.journalQuickAdd,
          'title': 'Quick Record',
          'icon': Icons.edit_note_rounded,
        },
        {'type': BlockType.mood, 'title': 'Mood', 'icon': Icons.face_rounded},
        {
          'type': BlockType.quotes,
          'title': 'Quote',
          'icon': Icons.format_quote_rounded,
        },
        {
          'type': BlockType.photos,
          'title': 'Photos',
          'icon': Icons.photo_library_rounded,
        },
        {
          'type': BlockType.customMarkdown,
          'title': 'Markdown',
          'icon': Icons.code_rounded,
        },
      ],
      'Organization': [
        {
          'type': BlockType.shortcuts,
          'title': 'Shortcuts',
          'icon': Icons.bolt_rounded,
        },
        {
          'type': BlockType.people,
          'title': 'People',
          'icon': Icons.people_alt_rounded,
        },
        {
          'type': BlockType.resources,
          'title': 'Resources',
          'icon': Icons.book_rounded,
        },
        {
          'type': BlockType.organizerSummary,
          'title': 'Organizer',
          'icon': Icons.account_tree_rounded,
        },
        {
          'type': BlockType.universal,
          'title': 'Universal Widget',
          'icon': Icons.dashboard_customize_rounded,
        },
      ],
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(
                        Icons.widgets_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Add Widget',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Tap to add',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textMutedColor(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: categories.entries.map((category) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 16, 0, 10),
                        child: Text(
                          category.key.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textMuted,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: category.value.map((item) {
                          return InkWell(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              final blockType = item['type'] as BlockType;
                              final title = item['title'] as String;
                              Map<String, dynamic> metadata = {};
                              if (blockType == BlockType.universal) {
                                metadata = {
                                  'sourceBlockType': 'plannerDay',
                                  'size': 'medium',
                                  'objectTypes': ['task', 'goal'],
                                };
                              }
                              if (blockType == BlockType.organizerSummary) {
                                Navigator.pop(ctx);
                                _showOrganizerFilterConfigSheet(
                                  title: title,
                                  createNew: true,
                                );
                                return;
                              }
                              ref
                                  .read(dashboardProvider.notifier)
                                  .addBlock(
                                    blockType,
                                    title,
                                    metadata: metadata,
                                  );
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Widget "$title" added!'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              width:
                                  (MediaQuery.of(context).size.width - 52) / 3,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceVariantColor(context),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppColors.divider.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    item['icon'] as IconData,
                                    color: AppColors.primary,
                                    size: 24,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    item['title'] as String,
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlock(DashboardBlock block) {
    switch (block.type) {
      case BlockType.universal:
        return _buildUniversalDashboardBlock(block);
      case BlockType.shortcuts:
        return _buildShortcutsBlock();
      case BlockType.habits:
        return _buildHabitsBlock();
      case BlockType.tasks:
        return _buildTasksBlock();
      case BlockType.goals:
        return _buildProjectsBlock();
      case BlockType.timeline:
        return _buildTimelineBlock();
      case BlockType.quotes:
        return _buildQuoteBlock(block);
      case BlockType.photos:
        return _buildPhotosBlock();
      case BlockType.kpi:
        return _buildKPIBlock();
      case BlockType.shoppingList:
        return ShoppingListBlockWidget(block: block);
      case BlockType.mood:
        return _buildMoodBlock();
      case BlockType.dailyGoal:
        return _buildDailyGoalBlock();
      case BlockType.calendar:
        return const CalendarWidget();
      case BlockType.notes:
        return _buildNotesBlock(block);
      case BlockType.timer:
        return _buildTimerBlock();
      case BlockType.trackerField:
        return _buildTrackerFieldBlock();
      case BlockType.people:
        return _buildPeopleBlock();
      case BlockType.resources:
        return _buildResourcesBlock();
      case BlockType.analysisTrend:
        return _buildAnalysisBlock();
      case BlockType.habitTrend:
        return _buildHabitHeatmapBlock();
      case BlockType.journalQuickAdd:
        return _buildJournalQuickAddBlock();
      case BlockType.timeBlocking:
        return _buildTimeBlockingBlock();
      case BlockType.customMarkdown:
        return _buildCustomMarkdownBlock();
      case BlockType.googleCalendar:
        return _buildGoogleCalendarBlock(block);
      case BlockType.plannerDay:
        return _buildPlannerDayBlock();
      case BlockType.plannerWeek:
        return _buildPlannerWeekBlock();
      case BlockType.plannerMonth:
        return _buildPlannerMonthBlock();
      case BlockType.pomodoroSummary:
        return const PomodoroWeekOverview();
      case BlockType.organizerSummary:
        final organizerId =
            block.metadata['organizerSlug'] as String? ??
            block.metadata['organizerId'] as String?;
        return OrganizerTasksWidget(
          initialOrganizerSlug: organizerId,
          objectTypes: _selectedFilterObjectTypes(block),
          onConfigure: () => _showOrganizerFilterConfigSheet(block: block),
        );
      case BlockType.pinnedObject:
        return _buildPinnedObjectBlock(block);
      case BlockType.systemQuickRun:
        return _buildSystemQuickRunBlock();
      case BlockType.energyMap:
        return const EnergyMap(compact: true);
      case BlockType.pactToday:
        return _buildPactTodayBlock();
    }
  }

  Widget _buildTimelineBlock() {
    return _buildCard(
      title: "Today's Timeline",
      icon: Icons.timeline_rounded,
      onAdd: () => showCreateMenu(context),
      child: _buildTimelineList(),
    );
  }

  Widget _buildSystemQuickRunBlock() {
    final systems = ref.watch(systemsProvider);
    return _buildCard(
      title: 'Systems',
      icon: Icons.account_tree_rounded,
      onAdd: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SystemDetailScreen(system: SystemDefinition(title: 'Novo System'))),
      ),
      child: systems.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Nenhum System criado ainda.',
                style: TextStyle(color: AppTheme.textMutedColor(context), fontSize: 13),
              ),
            )
          : Column(
              children: systems.take(5).map((system) {
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.account_tree_rounded, color: AppColors.primary, size: 16),
                  ),
                  title: Text(
                    system.title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${system.steps.length} steps · ${system.estimatedMinutes > 0 ? '${system.estimatedMinutes}min' : ''}${system.runCount > 0 ? ' · ${system.runCount}x executado' : ''}',
                    style: const TextStyle(fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.play_arrow_rounded, color: AppColors.primary, size: 20),
                    tooltip: 'Executar',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => SystemDetailScreen(system: system)),
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => SystemDetailScreen(system: system)),
                  ),
                );
              }).toList(),
            ),
    );
  }


  Widget _buildDailyGoalBlock() {
    final tasks = ref.watch(tasksProvider);
    final totalTasks = tasks.where((t) => !t.archived).length;
    final completedTasks = tasks
        .where((t) => t.stage == TaskStage.finalized)
        .length;
    final progress = totalTasks == 0 ? 0.0 : completedTasks / totalTasks;

    return _buildCard(
      title: 'Daily Goal',
      icon: Icons.auto_awesome_rounded,
      child: Row(
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 8,
                  backgroundColor: AppTheme.surfaceVariantColor(context),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.primary,
                  ),
                ),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  completedTasks == totalTasks && totalTasks > 0
                      ? 'Amazing! Everything done.'
                      : '${totalTasks - completedTasks} tasks left today.',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "You've already completed $completedTasks items.",
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMutedColor(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKPIBlock() {
    final tasks = ref.watch(tasksProvider);
    final habits = ref.watch(habitsProvider);
    final timerState = ref.watch(pomodoroProvider);

    final pendingTasks = tasks
        .where((t) => t.stage != TaskStage.finalized)
        .length;

    final habitSuccess = habits.isEmpty
        ? 0
        : (habits.where((h) => h.daysSinceLastCompletion == 0).length /
                  habits.length *
                  100)
              .toInt();

    final totalFocusMinutes = timerState.history.fold<int>(
      0,
      (sum, s) => sum + s.minutesWorked,
    );
    final focusHours = (totalFocusMinutes / 60).toStringAsFixed(1);

    return _buildCard(
      title: 'KPI Snapshot',
      icon: Icons.analytics_rounded,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _kpiMetric('$habitSuccess%', 'Habits', AppColors.habitGreen),
          _kpiMetric('$pendingTasks', 'Tasks', AppColors.info),
          _kpiMetric('${focusHours}h', 'Focus', AppColors.habitPurple),
        ],
      ),
    );
  }

  Widget _kpiMetric(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.textMutedColor(context),
          ),
        ),
      ],
    );
  }

  Widget _buildMoodBlock() {
    final moods = ref.watch(moodsProvider);
    return _buildCard(
      title: 'How are you?',
      icon: Icons.face_rounded,
      child: Column(
        children: [
          const Text(
            'Record your mood now',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: moods
                  .map(
                    (m) => Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: GestureDetector(
                        onTap: () => _registerMood(m),
                        child: Column(
                          children: [
                            Text(m.emoji, style: const TextStyle(fontSize: 28)),
                            const SizedBox(height: 4),
                            Text(
                              m.title,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  void _registerMood(MoodDefinition mood) {
    ref
        .read(todayJournalProvider.notifier)
        .addEntry(
          JournalEntry(
            body: 'Mood recorded from Home: ${mood.emoji} ${mood.title}',
            date: DateTime.now(),
            title: 'Mood Record',
            moodSlug: mood.id,
          ),
        );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Mood recorded: ${mood.emoji} ${mood.title}')),
    );
  }

  // ignore: unused_element
  Widget _buildCalendarBlock() {
    final tasks = ref
        .watch(tasksProvider)
        .where((t) => t.endDate != null && t.stage != TaskStage.finalized)
        .toList();

    final today = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(today);

    // Combine items for today/upcoming
    final List<dynamic> upcomingItems = [
      ...tasks.where(
        (t) => DateFormat('yyyy-MM-dd').format(t.endDate!) == todayStr,
      ),
    ];

    upcomingItems.sort((a, b) {
      final aTime = (a as Task).scheduledTime ?? '00:00';
      final bTime = (b as Task).scheduledTime ?? '00:00';
      return aTime.compareTo(bTime);
    });

    return _buildCard(
      title: 'Upcoming Appointments',
      icon: Icons.calendar_today_rounded,
      child: upcomingItems.isEmpty
          ? const Text(
              'No appointments for today',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            )
          : Column(
              children: upcomingItems.take(3).map((item) {
                final isTask = item is Task;
                final title = isTask
                    ? item.title
                    : (item as ContentObject).title;
                final time = isTask
                    ? (item.scheduledTime ?? 'All day')
                    : DateFormat(
                        'HH:mm',
                      ).format((item as ContentObject).createdAt);
                final color = isTask
                    ? AppColors.primary
                    : AppColors.habitPurple;

                return InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          UniversalDetailView(object: item as ContentObject),
                    ),
                  ),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(
                            child: Text(
                              time,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: color,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                isTask ? 'Task' : 'Session',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.textMutedColor(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isTask && item.priority != TaskPriority.none)
                          Icon(
                            Icons.flag_rounded,
                            size: 14,
                            color: _priorityColor(item.priority),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildQuoteBlock(DashboardBlock block) {
    final resources = ref.watch(resourcesProvider);
    final allHighlights = <({String text, String source})>[];
    for (final r in resources) {
      final hls = MarkdownParser.extractHighlights(r.synopsis ?? '');
      allHighlights.addAll(hls.map((h) => (text: h.text, source: r.title)));
    }

    final customQuotes = (block.metadata['quotes'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        <String>[];

    final today = DateTime.now();
    final dayIndex = today.day + today.month * 31;

    final quote = customQuotes.isNotEmpty
        ? (text: customQuotes[dayIndex % customQuotes.length], source: 'Personalizado')
        : (allHighlights.isEmpty
            ? (text: 'The best way to predict the future is to create it.', source: 'Peter Drucker')
            : allHighlights[dayIndex % allHighlights.length]);

    return _buildCard(
      title: block.title.isNotEmpty ? block.title : 'Destaque do dia',
      icon: Icons.format_quote_rounded,
      onConfigure: () => _showQuotePoolEditor(block, customQuotes),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '"${quote.text}"',
            style: const TextStyle(
              fontSize: 15,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '— ${quote.source}',
            style: TextStyle(fontSize: 12, color: AppTheme.textMutedColor(context)),
          ),
        ],
      ),
    );
  }

  void _showQuotePoolEditor(DashboardBlock? block, List<String> quotes) {
    final localQuotes = List<String>.from(quotes);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          decoration: AppTheme.sheetDecoration(context),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textMuted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Expanded(
                    child: Text('Pool de Citações',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      final ctrl = TextEditingController();
                      showDialog<void>(
                        context: ctx,
                        builder: (dialogCtx) => AlertDialog(
                          title: const Text('Nova citação'),
                          content: TextField(
                            controller: ctrl,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              hintText: '"Frase" — Autor',
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogCtx),
                              child: const Text('Cancelar'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                if (ctrl.text.trim().isNotEmpty) {
                                  setModalState(() => localQuotes.add(ctrl.text.trim()));
                                }
                                Navigator.pop(dialogCtx);
                              },
                              child: const Text('Adicionar'),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Adicionar'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 260,
                child: ListView.builder(
                  itemCount: localQuotes.length,
                  itemBuilder: (_, i) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      localQuotes[i],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                      onPressed: () => setModalState(() => localQuotes.removeAt(i)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: AppTheme.primaryButtonStyle,
                  onPressed: () {
                    if (block != null) {
                      final updated = block.copyWith(
                        metadata: {...block.metadata, 'quotes': localQuotes},
                      );
                      ref.read(dashboardProvider.notifier).updateBlock(updated);
                    }
                    Navigator.pop(ctx);
                  },
                  child: const Text('Salvar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShortcutsBlock() {
    return Container(
      decoration: AppTheme.cardDecoration(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.bolt_rounded,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              const Text(
                'Shortcuts',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              if (!_isEditMode)
                const Icon(
                  Icons.more_horiz,
                  size: 18,
                  color: AppColors.textMuted,
                ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.start,
              children: [
                _shortcutItem(
                  context,
                  Icons.calendar_today_rounded,
                  'Planner',
                  const PlannerScreen(),
                  route: '/planner',
                ),
                _shortcutItem(
                  context,
                  Icons.loop_rounded,
                  'Habits',
                  const HabitsScreen(),
                  route: '/habits',
                ),
                _shortcutItem(
                  context,
                  Icons.flag_circle_rounded,
                  'Goals',
                  const GoalsScreen(),
                  route: '/goals',
                ),
                _shortcutItem(
                  context,
                  Icons.timer_rounded,
                  'Focus',
                  const PomodoroScreen(),
                  route: '/pomodoro',
                ),
                _shortcutItem(
                  context,
                  Icons.analytics_rounded,
                  'Trackers',
                  const TrackersScreen(),
                  route: '/trackers',
                ),
                _shortcutItem(
                  context,
                  Icons.description_outlined,
                  'Notes',
                  const NotesScreen(),
                  route: '/notes',
                ),
                _shortcutItem(
                  context,
                  Icons.people_rounded,
                  'People',
                  const PeopleScreen(),
                  route: '/people',
                ),
                _shortcutItem(
                  context,
                  Icons.folder_outlined,
                  'Resources',
                  const ResourcesScreen(),
                  route: '/resources',
                ),
                _shortcutItem(
                  context,
                  Icons.auto_stories_rounded,
                  'Journal',
                  const JournalScreen(),
                  route: '/journal',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _shortcutItem(
    BuildContext context,
    IconData icon,
    String label,
    Widget screen, {
    String? route,
  }) {
    return InkWell(
      onTap: () {
        if (route != null) {
          final currentRoute = GoRouterState.of(context).uri.toString();
          if (currentRoute != route) {
            context.push(route);
          }
        } else {
          Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariantColor(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 24),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 50,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondaryColor(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHabitsBlock() {
    final today = DateTime.now();
    final habits = ref
        .watch(habitsProvider)
        .where(
          (habit) =>
              habit.status == HabitStatus.active &&
              (habit.scheduler == null ||
                  SchedulerService.shouldFire(habit.scheduler!, today)),
        )
        .toList();
    if (habits.isEmpty) {
      return _buildCard(
        title: 'Hábitos de hoje',
        icon: Icons.loop_rounded,
        child: const Text(
          'Nenhum hábito para hoje',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      );
    }

    return _buildCard(
      title: 'Hábitos de hoje',
      icon: Icons.loop_rounded,
      onAdd: () => showCreateMenu(context),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: habits.map((h) => _buildHabitIcon(h)).toList()),
      ),
    );
  }

  Widget _buildPactTodayBlock() {
    final today = DateTime.now();
    final pacts = ref
        .watch(habitsProvider)
        .where(
          (habit) =>
              habit.status == HabitStatus.active &&
              habit.habitMode == HabitMode.pact,
        )
        .toList();

    if (pacts.isEmpty) {
      return _buildCard(
        title: 'Pactos de hoje',
        icon: Icons.handshake_rounded,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Nenhum pacto ativo para hoje',
            style: TextStyle(color: AppTheme.textMutedColor(context), fontSize: 13),
          ),
        ),
      );
    }

    return _buildCard(
      title: 'Pactos de hoje',
      icon: Icons.handshake_rounded,
      onAdd: () => showCreateMenu(context),
      child: Column(
        children: pacts.map((habit) {
          final color = _parseHexColor(habit.color, fallback: AppColors.accent);
          final todayRecord = habit.completionHistory.where((r) {
            return r.date.year == today.year &&
                r.date.month == today.month &&
                r.date.day == today.day;
          });
          final completedToday = todayRecord.isNotEmpty
              ? todayRecord.first.completions
              : 0;
          final isCompleted = completedToday >= habit.dailyGoal;

          int remainingDays = 0;
          int dayCount = 0;
          if (habit.startedAt != null) {
            final todayDate = DateTime(today.year, today.month, today.day);
            final startedAtDate = DateTime(habit.startedAt!.year, habit.startedAt!.month, habit.startedAt!.day);
            dayCount = todayDate.difference(startedAtDate).inDays + 1;
            if (habit.endsAt != null) {
              final endsAtDate = DateTime(habit.endsAt!.year, habit.endsAt!.month, habit.endsAt!.day);
              remainingDays = endsAtDate.difference(todayDate).inDays;
            }
          }

          return InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => UniversalDetailView(object: habit)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Checkbox(
                    value: isCompleted,
                    activeColor: color,
                    onChanged: (val) {
                      HapticFeedback.lightImpact();
                      ref.read(habitsProvider.notifier).toggleHabit(habit, today);
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          habit.displayTitle,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isCompleted ? AppTheme.textMutedColor(context) : AppTheme.textPrimaryColor(context),
                            decoration: isCompleted ? TextDecoration.lineThrough : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (dayCount > 0) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Dia $dayCount${habit.endsAt != null ? " · $remainingDays dias restantes" : ""}',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textMutedColor(context),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (habit.endsAt != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        remainingDays >= 0 ? '$remainingDays d' : 'Expirado',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHabitIcon(Habit habit) {
    final isDone = habit.daysSinceLastCompletion == 0;
    final habitColor = _parseHexColor(habit.color, fallback: AppColors.accent);

    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: GestureDetector(
        onLongPress: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => UniversalDetailView(object: habit)),
        ),
        onTap: () {
          HapticFeedback.lightImpact();
          showHabitDetailSheet(context, habit, DateTime.now());
        },
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isDone
                    ? habitColor.withValues(alpha: 0.1)
                    : AppTheme.surfaceVariantColor(context),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDone ? habitColor : AppTheme.dividerColor(context),
                  width: 2,
                ),
              ),
              child: Icon(
                _resolveHabitIcon(habit.icon),
                color: isDone ? habitColor : AppTheme.textMutedColor(context),
                size: 20,
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 50,
              child: Text(
                habit.displayTitle,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isDone
                      ? habitColor
                      : AppTheme.textSecondaryColor(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _parseHexColor(String? hex, {Color fallback = AppColors.primary}) {
    if (hex == null || hex.isEmpty) return fallback;
    final cleaned = hex.replaceFirst('#', '').replaceFirst('0x', '');
    final withAlpha = cleaned.length == 6 ? 'FF$cleaned' : cleaned;
    return Color(int.tryParse(withAlpha, radix: 16) ?? fallback.toARGB32());
  }

  IconData _resolveHabitIcon(String? storedIcon) {
    // `flutter build --release` uses icon tree-shaking; dynamically constructing
    // IconData (e.g. from a persisted codepoint) breaks release builds.
    //
    // We only return icons referenced as `Icons.*` (const) and fall back safely.
    final raw = storedIcon?.trim();
    if (raw == null || raw.isEmpty) return Icons.check_circle_outline_rounded;

    final codePoint = int.tryParse(raw);
    if (codePoint == null) return Icons.check_circle_outline_rounded;

    const candidates = <IconData>[
      Icons.check_circle_outline_rounded,
      Icons.check_rounded,
      Icons.loop_rounded,
      Icons.bolt_rounded,
      Icons.fitness_center_rounded,
      Icons.self_improvement_rounded,
      Icons.local_fire_department_rounded,
      Icons.water_drop_rounded,
      Icons.book_rounded,
      Icons.menu_book_rounded,
      Icons.edit_note_rounded,
      Icons.brush_rounded,
      Icons.music_note_rounded,
      Icons.headphones_rounded,
      Icons.run_circle_rounded,
      Icons.directions_run_rounded,
      Icons.timer_outlined,
      Icons.alarm_rounded,
      Icons.bedtime_rounded,
      Icons.restaurant_rounded,
      Icons.spa_rounded,
      Icons.favorite_rounded,
      Icons.favorite_border_rounded,
      Icons.psychology_rounded,
      Icons.school_rounded,
      Icons.work_rounded,
      Icons.attach_money_rounded,
      Icons.savings_rounded,
      Icons.language_rounded,
      Icons.public_rounded,
      Icons.cleaning_services_rounded,
      Icons.home_rounded,
      Icons.pets_rounded,
      Icons.camera_alt_rounded,
      Icons.photo_camera_rounded,
      Icons.code_rounded,
      Icons.terminal_rounded,
    ];

    for (final icon in candidates) {
      if (icon.codePoint == codePoint) return icon;
    }
    return Icons.check_circle_outline_rounded;
  }

  Widget _buildTasksBlock() {
    final tasks = ref
        .watch(tasksProvider)
        .where((t) => t.stage != TaskStage.finalized)
        .toList();
    return _buildCard(
      title: 'Upcoming Tasks',
      icon: Icons.check_circle_outline_rounded,
      onAdd: () => showCreateMenu(context),
      child: tasks.isEmpty
          ? const Text(
              'No pending tasks',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            )
          : Column(
              children: tasks
                  .take(3)
                  .map(
                    (t) => InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => UniversalDetailView(object: t),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                ref
                                    .read(tasksProvider.notifier)
                                    .updateTask(
                                      t.copyWith(stage: TaskStage.finalized),
                                    );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  Icons.check_box_outline_blank_rounded,
                                  size: 18,
                                  color: AppTheme.textMutedColor(context),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                t.title,
                                style: const TextStyle(fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (t.priority != TaskPriority.none)
                              Icon(
                                Icons.flag_rounded,
                                size: 14,
                                color: _priorityColor(t.priority),
                              ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildProjectsBlock() {
    final goals = ref.watch(goalsProvider);
    return _buildCard(
      title: 'Goals',
      icon: Icons.track_changes_rounded,
      onAdd: () => showCreateMenu(context),
      child: goals.isEmpty
          ? const Text(
              'No active goals',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            )
          : Column(
              children: goals
                  .take(3)
                  .map(
                    (g) => ObjectActionWrapper(
                      object: g,
                      child: InkWell(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UniversalDetailView(object: g),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      g.title,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${(g.progress * 100).toInt()}%',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: g.progress,
                                  minHeight: 4,
                                  backgroundColor: AppTheme.surfaceVariantColor(
                                    context,
                                  ),
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                        AppColors.primary,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required Widget child,
    VoidCallback? onAdd,
    VoidCallback? onConfigure,
  }) {
    return Semantics(
      label: 'Dashboard block: $title',
      container: true,
      child: Container(
        decoration: AppTheme.cardDecoration(context),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Spacer(),
                if (!_isEditMode)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (onAdd != null)
                        IconButton(
                          onPressed: onAdd,
                          tooltip: 'Add item to block $title',
                          icon: const Icon(
                            Icons.add_circle_outline_rounded,
                            size: 20,
                            color: AppColors.primary,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      IconButton(
                        onPressed: onConfigure,
                        tooltip: onConfigure == null
                            ? 'More options'
                            : 'Configure block $title',
                        icon: Icon(
                          onConfigure == null
                              ? Icons.more_horiz
                              : Icons.settings_rounded,
                          size: onConfigure == null ? 16 : 20,
                          color: onConfigure == null
                              ? AppTheme.textMutedColor(context)
                              : AppColors.primary,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineList() {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final data = ref.watch(dailyNoteDataProvider(todayStr));
    final moods = ref.watch(moodsProvider);

    final entries = (data['entries'] as List?)?.cast<JournalEntry>() ?? [];

    if (entries.isEmpty) {
      return const Center(
        child: Text(
          'No logs today. Add a journal entry or pomodoro!',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    return Column(
      children: entries.map((item) {
        if (item.entryType == JournalEntryType.pmn) {
          return ObjectActionWrapper(
            object: item,
            child: PmnCard(
              title: item.title.isNotEmpty ? item.title : 'PMN',
              week: item.week ?? '',
              plusCount: item.plus.length,
              minusCount: item.minus.length,
              nextCount: item.next.length,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UniversalDetailView(object: item),
                ),
              ),
            ),
          );
        }

        return ObjectActionWrapper(
          object: item,
          child: JournalEntryCard(
            title: item.title,
            body: item.body,
            time: DateFormat('HH:mm').format(item.date),
            moodEmoji: _moodEmojiFor(item.moodSlug, moods),
            moodLabel: _moodLabelFor(item.moodSlug, moods),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => UniversalDetailView(object: item),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String? _moodEmojiFor(String? moodSlug, List<MoodDefinition> moods) {
    if (moodSlug == null || moodSlug.isEmpty) return null;
    final mood = moods
        .where((m) => m.id == moodSlug || m.slug == moodSlug)
        .firstOrNull;
    if (mood != null) return mood.emoji;

    return switch (moodSlug) {
      'terrible' => '😞',
      'bad' => '😢',
      'neutral' => '😐',
      'good' => '🙂',
      'great' => '😄',
      _ => '😐',
    };
  }

  String? _moodLabelFor(String? moodSlug, List<MoodDefinition> moods) {
    if (moodSlug == null || moodSlug.isEmpty) return null;
    final mood = moods
        .where((m) => m.id == moodSlug || m.slug == moodSlug)
        .firstOrNull;
    return mood?.title ?? moodSlug;
  }

  Widget _buildNotesBlock(DashboardBlock block) {
    final notes = ref.watch(notesProvider);
    final noteSlug = block.metadata['noteSlug']?.toString();
    final pinnedNote = noteSlug == null
        ? null
        : notes
              .where(
                (note) =>
                    note.slug == noteSlug ||
                    note.id == noteSlug ||
                    note.obsidianFileName == noteSlug,
              )
              .firstOrNull;
    if (notes.isEmpty) {
      return _buildCard(
        title: 'Notes',
        icon: Icons.sticky_note_2_rounded,
        onConfigure: () => _showPinnedNotePicker(block),
        child: const Text(
          'None note encontrada',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      );
    }

    if (pinnedNote != null) {
      return _buildCard(
        title: pinnedNote.title,
        icon: Icons.sticky_note_2_rounded,
        onConfigure: () => _showPinnedNotePicker(block),
        child: ObjectActionWrapper(
          object: pinnedNote,
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => UniversalDetailView(object: pinnedNote),
              ),
            ),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: JournalBodyView(
                body: pinnedNote.body,
                maxLines: 10,
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondaryColor(context),
                  height: 1.35,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return _buildCard(
      title: 'Recent Notes',
      icon: Icons.sticky_note_2_rounded,
      onAdd: () => showCreateMenu(context),
      onConfigure: () => _showPinnedNotePicker(block),
      child: SizedBox(
        height: 120,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: notes.take(5).length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final note = notes[index];
            return ObjectActionWrapper(
              object: note,
              child: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UniversalDetailView(object: note),
                  ),
                ),
                child: Container(
                  width: 160,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.divider.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        note.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: JournalBodyView(
                          body: note.body,
                          maxLines: 4,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondaryColor(context),
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showPinnedNotePicker(DashboardBlock block) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UniversalSearchPickerSheet(
        title: 'Fixar nota',
        initialFilter: 'note',
        onSelected: (object) {
          Navigator.pop(context);
          if (object is! Note) return;
          ref
              .read(dashboardProvider.notifier)
              .updateBlock(
                block.copyWith(
                  title: object.title,
                  metadata: {...block.metadata, 'noteSlug': object.slug},
                ),
              );
        },
        onClear: () {
          Navigator.pop(context);
          final metadata = Map<String, dynamic>.from(block.metadata)
            ..remove('noteSlug');
          ref
              .read(dashboardProvider.notifier)
              .updateBlock(block.copyWith(title: 'Notes', metadata: metadata));
        },
      ),
    );
  }

  Widget _buildTimerBlock() {
    final timerState = ref.watch(pomodoroProvider);
    final isActive = timerState.isRunning;
    return _buildCard(
      title: 'Focus Agora',
      icon: Icons.timer_rounded,
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value:
                    timerState.remainingSeconds /
                    (timerState.currentType != PomodoroType.work ? 300 : 1500),
                backgroundColor: AppColors.surfaceVariant,
                color: timerState.currentType != PomodoroType.work
                    ? AppColors.habitGreen
                    : AppColors.priorityHigh,
              ),
              Text(
                '${timerState.remainingSeconds ~/ 60}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isActive
                      ? (timerState.currentItemTitle ?? 'Active Session')
                      : 'No active session',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  timerState.currentType != PomodoroType.work
                      ? 'Break'
                      : 'Work',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PomodoroScreen()),
            ),
            icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackerFieldBlock() {
    final records = ref.watch(trackingRecordsProvider).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final trackers = ref.watch(trackersProvider);

    if (records.isEmpty) {
      return _buildCard(
        title: 'Last Metric',
        icon: Icons.show_chart_rounded,
        onAdd: () => showCreateMenu(context),
        child: EmptyStateView(icon: Icons.track_changes_rounded, headline: 'Nenhum entry ainda', isSmall: true),
      );
    }

    final record = records.first;
    final tracker = trackers.where((t) => t.id == record.trackerId).firstOrNull;
    final firstValue = record.fieldValues.entries.firstOrNull;

    return _buildCard(
      title: tracker?.title ?? record.title,
      icon: Icons.show_chart_rounded,
      child: Row(
        children: [
          Expanded(
            child: Text(
              firstValue == null
                  ? 'Entry sem campos'
                  : '${firstValue.key}: ${firstValue.value}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: AppColors.info,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            DateFormat('HH:mm').format(record.date),
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeopleBlock() {
    final people = ref
        .watch(peopleProvider)
        .where((p) => p.isDueForContact)
        .toList();
    return _buildCard(
      title: 'Contatos Pendings',
      icon: Icons.people_alt_rounded,
      child: people.isEmpty
          ? EmptyStateView(icon: Icons.people_outline, headline: 'Nenhum contato pendente', isSmall: true)
          : Column(
              children: people
                  .take(2)
                  .map(
                    (p) => ObjectActionWrapper(
                      object: p,
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => UniversalDetailView(object: p),
                            ),
                          );
                        },
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor: AppColors.surfaceVariant,
                          child: Text(p.title.isNotEmpty ? p.title[0] : '?'),
                        ),
                        title: Text(
                          p.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildResourcesBlock() {
    final resources = ref.watch(resourcesProvider);
    final current =
        resources
            .where((r) => r.status == ResourceStatus.inProgress)
            .cast<ContentObject?>()
            .firstOrNull ??
        resources.cast<ContentObject?>().firstOrNull;

    return _buildCard(
      title: 'Resources',
      icon: Icons.book_rounded,
      onAdd: () => showCreateMenu(context),
      child: current == null
          ? EmptyStateView(icon: Icons.bookmark_border_rounded, headline: 'Nenhum recurso', isSmall: true)
          : ObjectActionWrapper(
              object: current,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UniversalDetailView(object: current),
                    ),
                  );
                },
                leading: Container(
                  width: 40,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.bookmark_outline_rounded,
                    color: AppColors.primary,
                  ),
                ),
                title: Text(
                  current.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  current is Resource ? current.status.name : current.type,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildAnalysisBlock() {
    final habits = ref.watch(habitsProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final activeHabits = habits.where((h) => h.status == HabitStatus.active).toList();

    // Calculate per-habit consistency over last 30 days
    double totalConsistency = 0;
    int totalStreak = 0;
    int bestStreak = 0;
    String? bestHabitTitle;
    int completedToday = 0;

    for (final habit in activeHabits) {
      // Count successful days in last 30 days
      int successDays = 0;
      for (int i = 0; i < 30; i++) {
        final checkDate = today.subtract(Duration(days: i));
        final record = habit.completionHistory.where((r) {
          final rDate = DateTime(r.date.year, r.date.month, r.date.day);
          return rDate == checkDate;
        }).firstOrNull;
        if (record != null && record.successful) successDays++;
      }
      final consistency = successDays / 30.0;
      totalConsistency += consistency;
      totalStreak += habit.streak;
      if (habit.streak > bestStreak) {
        bestStreak = habit.streak;
        bestHabitTitle = habit.title;
      }
      if (habit.isCompletedToday) completedToday++;
    }

    final avgConsistency = activeHabits.isEmpty
        ? 0.0
        : totalConsistency / activeHabits.length;

    String motivationText;
    if (activeHabits.isEmpty) {
      motivationText = 'Add habits to track your consistency!';
    } else if (avgConsistency >= 0.8) {
      motivationText = 'Exceptional consistency! Keep it up 🔥';
    } else if (avgConsistency >= 0.5) {
      motivationText = 'You\'re doing well — push for that 80%+ week!';
    } else if (completedToday == activeHabits.length) {
      motivationText = 'All habits done today! 🏆 Great effort!';
    } else {
      motivationText = 'You\'ve got $completedToday/${activeHabits.length} habits done today.';
    }

    return _buildCard(
      title: 'Consistency Insights',
      icon: Icons.auto_graph_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSimpleStat(
                'Avg rate (30d)',
                '${(avgConsistency * 100).toInt()}%',
                avgConsistency >= 0.7
                    ? AppColors.habitGreen
                    : avgConsistency >= 0.4
                        ? AppColors.primary
                        : AppColors.error,
              ),
              _buildSimpleStat('Total streaks', '$totalStreak', AppColors.warning),
              _buildSimpleStat(
                'Today',
                '$completedToday/${activeHabits.length}',
                AppColors.secondary,
              ),
            ],
          ),
          if (bestHabitTitle != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.emoji_events_rounded,
                      color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '🏅 Best streak: $bestHabitTitle ($bestStreak days)',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            motivationText,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildHabitHeatmapBlock() {
    final habits = ref.watch(habitsProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final activeHabits = habits.where((h) => h.status == HabitStatus.active).toList();
    final habitCount = activeHabits.length;

    // Count successful completions per day for the last 28 days
    final data = List.generate(28, (index) {
      final date = today.subtract(Duration(days: 27 - index));
      final dateKey = DateFormat('yyyy-MM-dd').format(date);
      int successCount = 0;
      for (final habit in activeHabits) {
        final record = habit.completionHistory.where((r) {
          final rDate = DateTime(r.date.year, r.date.month, r.date.day);
          return rDate == date;
        }).firstOrNull;
        if (record != null && record.successful) successCount++;
      }
      final activity = habitCount > 0
          ? (successCount / habitCount).clamp(0.0, 1.0)
          : 0.0;
      return ChartDataPoint(label: dateKey, value: activity);
    });

    // Overall stats
    final totalCompleted = data.where((d) => (d.value ?? 0.0) > 0).length;
    final perfectDays = data.where((d) => (d.value ?? 0.0) >= 1.0).length;
    final activeDays = data.where((d) => (d.value ?? 0.0) > 0).length;
    final avgActivity = activeDays > 0
        ? (data.fold(0.0, (s, d) => s + (d.value ?? 0.0)) / 28 * 100).toInt()
        : 0;

    return _buildCard(
      title: 'Habit Activity',
      icon: Icons.grid_on_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Last 28 days · ${activeHabits.length} active habits',
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: CitrineChart(
              type: ChartType.heatmap,
              data: data,
              color: AppColors.habitGreen,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSimpleStat(
                'Active days',
                '$totalCompleted/28',
                AppColors.habitGreen,
              ),
              _buildSimpleStat(
                'Perfect days',
                '$perfectDays',
                AppColors.primary,
              ),
              _buildSimpleStat(
                'Avg rate',
                '$avgActivity%',
                AppColors.secondary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _priorityColor(TaskPriority p) {
    switch (p) {
      case TaskPriority.high:
        return AppColors.priorityHigh;
      case TaskPriority.medium:
        return AppColors.priorityMedium;
      case TaskPriority.low:
        return AppColors.info;
      case TaskPriority.none:
        return AppColors.textMuted;
    }
  }

  Widget _buildSyncIndicator(WidgetRef ref) {
    final status = ref.watch(syncStatusProvider);
    final conflictCount = ref.watch(syncConflictsProvider).length;
    IconData icon;
    Color color;
    bool animate = false;

    switch (status) {
      case SyncStatus.synced:
        icon = Icons.cloud_done_rounded;
        color = AppColors.habitGreen;
        break;
      case SyncStatus.syncing:
        icon = Icons.sync_rounded;
        color = AppColors.primary;
        animate = true;
        break;
      case SyncStatus.error:
        icon = Icons.cloud_off_rounded;
        color = AppColors.priorityHigh;
        break;
      case SyncStatus.conflict:
        icon = Icons.warning_amber_rounded;
        color = AppColors.warning;
        break;
      case SyncStatus.offline:
        icon = Icons.cloud_off_rounded;
        color = AppColors.textMuted;
        break;
    }

    return IconButton(
      icon: animate
          ? _RotatingIcon(icon: icon, color: color)
          : Icon(icon, color: color, size: 20),
      tooltip: status == SyncStatus.conflict
          ? 'Sync: CONFLICT ($conflictCount)'
          : 'Sync: ${status.name.toUpperCase()}',
      onPressed: () {
        HapticFeedback.lightImpact();
        if (status == SyncStatus.conflict) {
          context.push('/sync-conflicts');
        } else {
          ref.read(syncManagerProvider).performSync();
          _triggerFolderSync();
        }
      },
    );
  }

  Future<void> _triggerFolderSync() async {
    if (!Platform.isAndroid) return;
    final syncUri = Uri.parse('foldersync://sync');
    try {
      if (await canLaunchUrl(syncUri)) {
        await launchUrl(syncUri, mode: LaunchMode.externalApplication);
        return;
      }
      const channel = MethodChannel('com.productivity.citrine/settings');
      await channel.invokeMethod('sendBroadcast', {
        'action': 'com.tacit.foldersync.intent.action.SYNC_ALL',
      });
    } catch (e) {
      debugPrint('FolderSync trigger failed: $e');
      final marketUri = Uri.parse(
        'market://details?id=dk.tacit.android.foldersync.lite',
      );
      if (await canLaunchUrl(marketUri)) {
        await launchUrl(marketUri, mode: LaunchMode.externalApplication);
      }
    }
  }

  Widget _buildJournalQuickAddBlock() {
    final isSubmitting = ref.watch(_quickAddSubmittingProvider);

    return _buildCard(
      title: 'Quick Log',
      icon: Icons.edit_note_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "What's on your mind?",
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _quickAddController,
            builder: (context, value, _) {
              final isEmpty = value.text.trim().isEmpty;
              return Column(
                children: [
                  TextField(
                    controller: _quickAddController,
                    maxLines: 3,
                    enabled: !isSubmitting,
                    textInputAction: TextInputAction.send,
                    decoration: const InputDecoration(
                      hintText: 'Write here...',
                    ),
                    onSubmitted: (text) => _submitQuickAdd(text),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: (isSubmitting || isEmpty)
                          ? null
                          : () => _submitQuickAdd(_quickAddController.text),
                      icon: isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded, size: 18),
                      label: Text(
                        isSubmitting ? 'SAVING...' : 'LOG IN JOURNAL',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _submitQuickAdd(String text) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return;

    ref.read(_quickAddSubmittingProvider.notifier).state = true;

    try {
      await ref.read(vaultProvider.notifier).createQuickJournalEntry(cleanText);

      if (!mounted) return;

      _quickAddController.clear();
      HapticFeedback.mediumImpact();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Note saved!'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      debugPrint('QuickAdd Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        ref.read(_quickAddSubmittingProvider.notifier).state = false;
      }
    }
  }

  Future<void> _submitQuickTask(String text) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return;

    ref.read(_quickTaskSubmittingProvider.notifier).state = true;

    try {
      await ref
          .read(vaultProvider.notifier)
          .createQuickTaskFromNaturalLanguage(cleanText);

      if (!mounted) return;

      _quickTaskController.clear();
      HapticFeedback.mediumImpact();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task added!'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      debugPrint('QuickTask Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        ref.read(_quickTaskSubmittingProvider.notifier).state = false;
      }
    }
  }

  Widget _buildTimeBlockingBlock() {
    final today = DateTime.now();
    const weekDayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final todayDayName = weekDayNames[today.weekday - 1];

    final allThemes = ref.watch(dayThemesProvider);
    final allTimeBlocks = ref.watch(timeBlocksProvider);

    // Find the active DayTheme for today
    final activeTheme = allThemes.cast<DayTheme?>().firstWhere(
      (t) => t != null && t.daysOfWeek.contains(todayDayName),
      orElse: () => null,
    );

    // Get the TimeBlocks belonging to the active theme
    final activeBlocks = activeTheme == null
        ? <TimeBlock>[]
        : allTimeBlocks
            .where((b) => activeTheme.blockIds.contains(b.id))
            .toList()
          ..sort((a, b) {
            final aStart = a.timeRanges.isEmpty ? 0 : a.timeRanges.first.startHour * 60 + a.timeRanges.first.startMinute;
            final bStart = b.timeRanges.isEmpty ? 0 : b.timeRanges.first.startHour * 60 + b.timeRanges.first.startMinute;
            return aStart.compareTo(bStart);
          });

    return _buildCard(
      title: activeTheme != null ? activeTheme.title : "Today's Time Blocks",
      icon: Icons.view_day_rounded,
      onConfigure: () => context.push('/day-themes'),
      child: activeTheme == null
          ? EmptyStateView(icon: Icons.calendar_today_rounded, headline: 'Sem tema hoje', isSmall: true)
          : activeBlocks.isEmpty
              ? const Text(
                  'Tema sem blocos de tempo configurados',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                )
              : Column(
                  children: activeBlocks.map((block) {
                    final blockColor = block.color != null
                        ? Color(int.tryParse('FF${block.color!.replaceAll('#', '')}', radix: 16) ?? 0xFFFFB000)
                        : AppColors.primary;
                    final rangeText = block.timeRanges.isEmpty
                        ? 'Sem horário'
                        : block.timeRanges
                            .map((r) =>
                                '${r.startHour.toString().padLeft(2, '0')}:${r.startMinute.toString().padLeft(2, '0')}–${r.endHour.toString().padLeft(2, '0')}:${r.endMinute.toString().padLeft(2, '0')}')
                            .join(' | ');
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 36,
                            decoration: BoxDecoration(
                              color: blockColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  block.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  rangeText,
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
                        ],
                      ),
                    );
                  }).toList(),
                ),
    );
  }

  Widget _buildPhotosBlock() {
    final photos = ref
        .watch(allEntriesProvider)
        .expand((entry) => entry.photos)
        .where((path) => path.trim().isNotEmpty)
        .toList();

    return _buildCard(
      title: 'Recent Photos',
      icon: Icons.photo_library_rounded,
      onAdd: () => showCreateMenu(context),
      child: photos.isEmpty
          ? const Text(
              'No photos logged yet',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            )
          : SizedBox(
              height: 84,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photos.take(8).length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final path = photos[index];
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(path),
                      width: 84,
                      height: 84,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 84,
                        height: 84,
                        color: AppTheme.surfaceVariantColor(context),
                        child: const Icon(
                          Icons.broken_image_outlined,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildCustomMarkdownBlock() {
    // Find the customMarkdown block from dashboard to read/write metadata
    final blocks = ref.watch(dashboardProvider).valueOrNull ?? [];
    final block = blocks.cast<DashboardBlock?>().firstWhere(
      (b) => b?.type == BlockType.customMarkdown,
      orElse: () => null,
    );
    final content = block?.metadata['content'] as String? ??
        '**Lembretes:**\n- Beber água\n- Alongar a cada hora';

    return _buildCard(
      title: 'Notas Fixas',
      icon: Icons.text_snippet_rounded,
      onConfigure: _isEditMode
          ? () => _showCustomMarkdownEditor(block, content)
          : null,
      child: Text(
        content,
        style: const TextStyle(fontSize: 14, height: 1.5),
        maxLines: 10,
        overflow: TextOverflow.fade,
      ),
    );
  }

  void _showCustomMarkdownEditor(DashboardBlock? block, String currentContent) {
    final controller = TextEditingController(text: currentContent);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: AppTheme.sheetDecoration(context),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textMuted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Editar Notas Fixas',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 8,
                decoration: const InputDecoration(
                  hintText: 'Escreva suas notas ou lembretes aqui...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: AppTheme.primaryButtonStyle,
                  onPressed: () {
                    if (block != null) {
                      final updated = block.copyWith(
                        metadata: {
                          ...block.metadata,
                          'content': controller.text,
                        },
                      );
                      ref.read(dashboardProvider.notifier).updateBlock(updated);
                    }
                    Navigator.pop(ctx);
                    controller.dispose();
                  },
                  child: const Text('Salvar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleCalendarBlock(DashboardBlock block) {
    final daysToShow = block.metadata['daysToShow'] as int? ?? 1;
    final format = block.metadata['format'] as String? ?? 'list';

    final params = GoogleCalendarParams(
      startDate: DateTime.now(),
      days: daysToShow,
    );

    final eventsAsync = ref.watch(googleCalendarRangeEventsProvider(params));

    return _buildCard(
      title: block.title,
      icon: Icons.event_rounded,
      onConfigure: () => _showGoogleCalendarBlockSettings(block),
      child: eventsAsync.when(
        data: (events) {
          if (events.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'Sem compromissos no período',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            );
          }

          if (format == 'timeline') {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: events.map((event) {
                final start = event.start?.dateTime ?? event.start?.date;
                final end = event.end?.dateTime ?? event.end?.date;
                final time = start == null
                    ? 'Dia inteiro'
                    : '${DateFormat('HH:mm').format(start.toLocal())}${end == null ? '' : ' - ${DateFormat('HH:mm').format(end.toLocal())}'}';
                final dateLabel = start == null
                    ? ''
                    : DateFormat('dd/MM').format(start.toLocal());

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: AppColors.info,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Container(
                            width: 2,
                            height: 36,
                            color: AppColors.info.withValues(alpha: 0.2),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.summary ?? 'Compromisso sem título',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$dateLabel  •  $time',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondaryColor(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          } else {
            return Column(
              children: events.take(5).map((event) {
                final start = event.start?.dateTime ?? event.start?.date;
                final end = event.end?.dateTime ?? event.end?.date;
                final time = start == null
                    ? 'Dia inteiro'
                    : '${DateFormat('HH:mm').format(start.toLocal())}${end == null ? '' : ' - ${DateFormat('HH:mm').format(end.toLocal())}'}';
                final dateLabel = start == null
                    ? ''
                    : ' (${DateFormat('dd/MM').format(start.toLocal())})';

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.event_available_rounded,
                      color: AppColors.info,
                      size: 16,
                    ),
                  ),
                  title: Text(
                    event.summary ?? 'Compromisso sem título',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '$time$dateLabel',
                    style: const TextStyle(fontSize: 12),
                  ),
                );
              }).toList(),
            );
          }
        },
        loading: () => const LinearProgressIndicator(minHeight: 2),
        error: (_, _) => const Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            'Não foi possível carregar o Google Agenda',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ),
      ),
    );
  }

  void _showGoogleCalendarBlockSettings(DashboardBlock block) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        int selectedDays = block.metadata['daysToShow'] as int? ?? 1;
        String selectedFormat = block.metadata['format'] as String? ?? 'list';

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: AppTheme.sheetDecoration(context),
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                20 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.textMuted.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Configurar Agenda',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimaryColor(context),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    'Período a Exibir',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [1, 3, 7, 14].map((days) {
                      final isSelected = selectedDays == days;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: ChoiceChip(
                            label: Text(days == 1 ? '1 dia' : '$days dias'),
                            selected: isSelected,
                            onSelected: (val) {
                              if (val) {
                                setModalState(() => selectedDays = days);
                              }
                            },
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    'Formato de Exibição',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Lista Compacta'),
                          selected: selectedFormat == 'list',
                          onSelected: (val) {
                            if (val) {
                              setModalState(() => selectedFormat = 'list');
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Linha do Tempo'),
                          selected: selectedFormat == 'timeline',
                          onSelected: (val) {
                            if (val) {
                              setModalState(() => selectedFormat = 'timeline');
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: AppTheme.primaryButtonStyle,
                      onPressed: () {
                        final updated = block.copyWith(
                          metadata: {
                            ...block.metadata,
                            'daysToShow': selectedDays,
                            'format': selectedFormat,
                          },
                        );
                        ref
                            .read(dashboardProvider.notifier)
                            .updateBlock(updated);
                        Navigator.pop(context);
                      },
                      child: const Text('Salvar Configuração'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _RotatingIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  const _RotatingIcon({required this.icon, required this.color});

  @override
  State<_RotatingIcon> createState() => _RotatingIconState();
}

class _RotatingIconState extends State<_RotatingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: Icon(widget.icon, color: widget.color, size: 20),
    );
  }
}

extension on _HomeScreenState {
  static const _universalObjectTypes = <String, String>{
    'task': 'Tasks',
    'goal': 'Goals',
    'habit': 'Habits',
    'note': 'Notes',
    'entry': 'Journal',
    'resource': 'Resources',
    'person': 'People',
  };

  Widget _buildUniversalDashboardBlock(DashboardBlock block) {
    final selectedType = _blockTypeFromName(
      block.metadata['sourceBlockType'] as String?,
    );
    final size = block.metadata['size'] as String? ?? 'large';
    final maxHeight = switch (size) {
      'compact' => 180.0,
      'medium' => 300.0,
      _ => 460.0,
    };

    return _buildCard(
      title: block.title,
      icon: _iconForBlockType(selectedType),
      onConfigure: () => _showUniversalWidgetConfigSheet(block),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          child: _buildUniversalWidgetContent(block, selectedType),
        ),
      ),
    );
  }

  Widget _buildUniversalWidgetContent(
    DashboardBlock block,
    BlockType selectedType,
  ) {
    switch (selectedType) {
      case BlockType.plannerDay:
        return _buildPlannerListContent(
          title: 'Today',
          start: DateTime.now(),
          end: DateTime.now(),
          emptyText: 'Nada planejado para hoje',
        );
      case BlockType.plannerWeek:
        final now = DateTime.now();
        final start = now.subtract(Duration(days: now.weekday - 1));
        return _buildPlannerListContent(
          title: 'Esta semana',
          start: start,
          end: start.add(const Duration(days: 6)),
          emptyText: 'Nada planejado para esta semana',
          showDate: true,
        );
      case BlockType.plannerMonth:
        return _buildPlannerMonthContent();
      case BlockType.pomodoroSummary:
        return _buildPomodoroStatsContent();
      case BlockType.organizerSummary:
        return _buildOrganizerFilterContent(block);
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _titleForBlockType(selectedType),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.textMutedColor(context),
              ),
            ),
            const SizedBox(height: 12),
            _buildBlock(
              DashboardBlock(
                id: '${block.id}-${selectedType.name}',
                type: selectedType,
                title: _titleForBlockType(selectedType),
                metadata: block.metadata,
              ),
            ),
          ],
        );
    }
  }

  Widget _buildPlannerListContent({
    required String title,
    required DateTime start,
    required DateTime end,
    required String emptyText,
    bool showDate = false,
  }) {
    final tasks = ref.watch(tasksProvider);
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day, 23, 59, 59);

    final items =
        tasks.where((task) {
          final date = task.startDate ?? task.endDate;
          return date != null &&
              !task.isCompleted &&
              !date.isBefore(startDay) &&
              !date.isAfter(endDay);
        }).toList()..sort(
          (a, b) => _dateForPlannerItem(a).compareTo(_dateForPlannerItem(b)),
        );

    if (items.isEmpty) {
      return Text(
        emptyText,
        style: TextStyle(color: AppTheme.textMutedColor(context), fontSize: 13),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppTheme.textMutedColor(context),
          ),
        ),
        const SizedBox(height: 8),
        ...items
            .take(12)
            .map((item) => _buildPlannerItem(item, showDate: showDate)),
      ],
    );
  }

  Widget _buildPlannerMonthContent() {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final firstWeekday = DateTime(now.year, now.month, 1).weekday;
    final tasks = ref.watch(tasksProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          DateFormat('MMMM yyyy').format(now),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: ['S', 'T', 'Q', 'Q', 'S', 'S', 'D']
              .map(
                (day) => Expanded(
                  child: Text(
                    day,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.textMutedColor(context),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemCount: 42,
          itemBuilder: (context, index) {
            final day = index - (firstWeekday - 1) + 1;
            if (day < 1 || day > daysInMonth) return const SizedBox.shrink();
            final date = DateTime(now.year, now.month, day);
            final isToday = _isSameDay(date, now);
            final itemCount = tasks
                .where(
                  (task) => _isSameDay(task.startDate ?? task.endDate, date),
                )
                .length;

            return InkWell(
              onTap: () => context.push('/planner'),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isToday
                      ? AppColors.primary
                      : AppTheme.surfaceVariantColor(context),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      '$day',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                        color: isToday
                            ? Colors.white
                            : AppTheme.textPrimaryColor(context),
                      ),
                    ),
                    if (itemCount > 0 && !isToday)
                      Positioned(
                        bottom: 3,
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPomodoroStatsContent() {
    final timerState = ref.watch(pomodoroProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: now.weekday - 1));
    final workSessions = timerState.history
        .where((session) => session.minutesWorked > 0)
        .toList();
    final todayMinutes = workSessions
        .where((session) => !session.date.isBefore(today))
        .fold<int>(0, (sum, session) => sum + session.minutesWorked);
    final weekMinutes = workSessions
        .where((session) => !session.date.isBefore(weekStart))
        .fold<int>(0, (sum, session) => sum + session.minutesWorked);
    final weekDays = List.generate(7, (i) => weekStart.add(Duration(days: i)));
    final maxMinutes = weekDays
        .map(
          (day) => workSessions
              .where((session) => _isSameDay(session.date, day))
              .fold<int>(0, (sum, session) => sum + session.minutesWorked),
        )
        .fold<int>(0, (max, value) => value > max ? value : max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _focusStat('${todayMinutes}m', 'hoje', AppColors.error),
            const SizedBox(width: 12),
            _focusStat(
              '${(weekMinutes / 60).toStringAsFixed(1)}h',
              'semana',
              AppColors.primary,
            ),
            const SizedBox(width: 12),
            _focusStat('${workSessions.length}', 'sessions', AppColors.info),
          ],
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 86,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: weekDays.map((day) {
              final minutes = workSessions
                  .where((session) => _isSameDay(session.date, day))
                  .fold<int>(
                    0,
                    (sum, session) => sum + session.minutesWorked,
                  );
              final height = maxMinutes == 0
                  ? 6.0
                  : 8.0 + (minutes / maxMinutes) * 52.0;
              return Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 18,
                      height: height,
                      decoration: BoxDecoration(
                        color: minutes == 0
                            ? AppTheme.surfaceVariantColor(context)
                            : AppColors.error.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      DateFormat('E').format(day),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.textMutedColor(context),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _focusStat(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppTheme.textMutedColor(context),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrganizerFilterContent(DashboardBlock block) {
    final allObjects = ref
        .watch(allObjectsProvider)
        .maybeWhen(data: (items) => items, orElse: () => <ContentObject>[]);
    final organizers = allObjects.whereType<Organizer>().toList();
    final organizerSlug = block.metadata['organizerSlug'] as String?;
    final organizer = organizerSlug == null
        ? (organizers.isNotEmpty ? organizers.first : null)
        : organizers.where((item) => item.slug == organizerSlug).firstOrNull;
    final selectedTypes = _selectedObjectTypes(block);

    if (organizer == null) {
      return Text(
        'Choose an organizer in this widget settings.',
        style: TextStyle(color: AppTheme.textMutedColor(context), fontSize: 13),
      );
    }

    final refs =
        allObjects.where((object) {
          if (object.id == organizer.id) return false;
          if (!selectedTypes.contains(object.type)) return false;
          return object.organizers.any(
            (ref) => ref.matches(organizer.id, organizer.slug, organizer.title),
          );
        }).toList()..sort((a, b) {
          final aTime = a.updatedAt;
          final bTime = b.updatedAt;
          return bTime.compareTo(aTime);
        });

    final taskCount = refs.where((item) => item.type == 'task').length;
    final goalCount = refs.where((item) => item.type == 'goal').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          organizer.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _summaryChip('$taskCount', 'tasks', AppColors.info),

            _summaryChip('$goalCount', 'goals', AppColors.warning),
            _summaryChip('${refs.length}', 'itens', AppColors.habitPurple),
          ],
        ),
        const SizedBox(height: 12),
        if (refs.isEmpty)
          Text(
            'Nada encontrado para esses filtros.',
            style: TextStyle(
              color: AppTheme.textMutedColor(context),
              fontSize: 13,
            ),
          )
        else
          ...refs.take(12).map(_buildOrganizerSummaryItem),
      ],
    );
  }

  void _showUniversalWidgetConfigSheet(DashboardBlock block) {
    final allObjects = ref.read(allObjectsProvider).valueOrNull ?? [];
    final organizers = allObjects.whereType<Organizer>().toList();
    var selectedType = _blockTypeFromName(
      block.metadata['sourceBlockType'] as String?,
    );
    var size = block.metadata['size'] as String? ?? 'large';
    var organizerSlug = block.metadata['organizerSlug'] as String?;
    var selectedObjectTypes = _selectedObjectTypes(block);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor(context),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                MediaQuery.of(context).padding.bottom + 20,
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: AppTheme.dividerColor(context),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Configure home widget',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<BlockType>(
                        initialValue: selectedType,
                        decoration: const InputDecoration(labelText: 'View'),
                        items: DashboardNotifier.availableWidgetBlocks
                            .map(
                              (item) => DropdownMenuItem<BlockType>(
                                value: item.type,
                                child: Text(_titleForBlockType(item.type)),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setModalState(() => selectedType = value);
                        },
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Size',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textMutedColor(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          _sizeChip('compact', 'Compact', size, (value) {
                            setModalState(() => size = value);
                          }),
                          _sizeChip('medium', 'Medium', size, (value) {
                            setModalState(() => size = value);
                          }),
                          _sizeChip('large', 'Large', size, (value) {
                            setModalState(() => size = value);
                          }),
                        ],
                      ),
                      if (selectedType == BlockType.organizerSummary) ...[
                        const SizedBox(height: 20),
                        DropdownButtonFormField<String>(
                          initialValue: organizerSlug?.isEmpty == true
                              ? null
                              : organizerSlug,
                          decoration: const InputDecoration(
                            labelText: 'Organizer',
                          ),
                          items: organizers
                              .map(
                                (organizer) => DropdownMenuItem<String>(
                                  value: organizer.slug,
                                  child: Text(
                                    organizer.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setModalState(() => organizerSlug = value);
                          },
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Object Types',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textMutedColor(context),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _universalObjectTypes.entries.map((entry) {
                            final selected = selectedObjectTypes.contains(
                              entry.key,
                            );
                            return FilterChip(
                              label: Text(entry.value),
                              selected: selected,
                              onSelected: (value) {
                                setModalState(() {
                                  final next = Set<String>.from(
                                    selectedObjectTypes,
                                  );
                                  value
                                      ? next.add(entry.key)
                                      : next.remove(entry.key);
                                  selectedObjectTypes = next.isEmpty
                                      ? {'task'}
                                      : next;
                                });
                              },
                              selectedColor: AppColors.primary.withValues(
                                alpha: 0.16,
                              ),
                              checkmarkColor: AppColors.primary,
                            );
                          }).toList(),
                        ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () {
                            final metadata =
                                Map<String, dynamic>.from(block.metadata)
                                  ..['sourceBlockType'] = selectedType.name
                                  ..['size'] = size
                                  ..['organizerSlug'] = organizerSlug
                                  ..['objectTypes'] = selectedObjectTypes
                                      .toList();
                            ref
                                .read(dashboardProvider.notifier)
                                .updateBlock(
                                  block.copyWith(
                                    title: 'Widget Inicial',
                                    metadata: metadata,
                                  ),
                                );
                            Navigator.pop(context);
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text('Save settings'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _sizeChip(
    String value,
    String label,
    String selectedValue,
    ValueChanged<String> onSelected,
  ) {
    final selected = value == selectedValue;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(value),
      selectedColor: AppColors.primary.withValues(alpha: 0.16),
      labelStyle: TextStyle(
        color: selected
            ? AppColors.primary
            : AppTheme.textSecondaryColor(context),
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
    );
  }

  Set<String> _selectedObjectTypes(DashboardBlock block) {
    final raw = block.metadata['objectTypes'];
    if (raw is List) {
      return raw.map((item) => item.toString()).toSet();
    }
    return {'task', 'goal'};
  }

  Set<String> _selectedFilterObjectTypes(DashboardBlock block) {
    final raw =
        block.metadata['filterObjectTypes'] ?? block.metadata['objectTypes'];
    if (raw is List) {
      final values = raw.map((item) => item.toString()).toSet();
      return values.isEmpty ? {'task', 'habit'} : values;
    }
    return {'task', 'habit'};
  }

  static const _filterObjectTypes = <String, String>{
    'task': 'Tarefas',
    'habit': 'Hábitos',
    'pomodoro': 'Pomodoros agendados',
    'goal': 'Goals',
    'note': 'Notas',
    'entry': 'Journal',
    'resource': 'Recursos',
    'person': 'Pessoas',
  };

  void _showOrganizerFilterConfigSheet({
    DashboardBlock? block,
    String title = 'Filtro',
    bool createNew = false,
  }) {
    final allObjects = ref.read(allObjectsProvider).valueOrNull ?? [];
    final organizers = [
      ...allObjects.whereType<Organizer>().cast<ContentObject>(),
      ...allObjects.whereType<Goal>().cast<ContentObject>(),
    ]..sort((a, b) => a.title.compareTo(b.title));
    var organizerSlug =
        block?.metadata['organizerSlug'] as String? ??
        block?.metadata['organizerId'] as String? ??
        (organizers.isNotEmpty ? organizers.first.slug : null);
    if (organizerSlug != null &&
        !organizers.any((organizer) => organizer.slug == organizerSlug)) {
      organizerSlug = organizers
          .where((organizer) => organizer.id == organizerSlug)
          .map((organizer) => organizer.slug)
          .firstOrNull;
    }
    organizerSlug ??= organizers.isNotEmpty ? organizers.first.slug : null;
    var selectedObjectTypes = block == null
        ? {'task', 'habit'}
        : _selectedFilterObjectTypes(block);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor(context),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                MediaQuery.of(context).padding.bottom + 20,
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: AppTheme.dividerColor(context),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Configurar filtro',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        initialValue: organizerSlug,
                        decoration: const InputDecoration(
                          labelText: 'Organizer',
                        ),
                        items: organizers
                            .map(
                              (organizer) => DropdownMenuItem<String>(
                                value: organizer.slug,
                                child: Text(
                                  organizer is Goal
                                      ? 'Goal · ${organizer.title}'
                                      : organizer.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setModalState(() => organizerSlug = value);
                        },
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Tipos de objeto',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textMutedColor(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _filterObjectTypes.entries.map((entry) {
                          final selected = selectedObjectTypes.contains(
                            entry.key,
                          );
                          return FilterChip(
                            label: Text(entry.value),
                            selected: selected,
                            onSelected: (value) {
                              setModalState(() {
                                final next = Set<String>.from(
                                  selectedObjectTypes,
                                );
                                value
                                    ? next.add(entry.key)
                                    : next.remove(entry.key);
                                selectedObjectTypes = next.isEmpty
                                    ? {'task'}
                                    : next;
                              });
                            },
                            selectedColor: AppColors.primary.withValues(
                              alpha: 0.16,
                            ),
                            checkmarkColor: AppColors.primary,
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () {
                            final metadata = <String, dynamic>{
                              'organizerSlug': organizerSlug,
                              'filterObjectTypes': selectedObjectTypes.toList(),
                            };
                            if (createNew || block == null) {
                              ref
                                  .read(dashboardProvider.notifier)
                                  .addBlock(
                                    BlockType.organizerSummary,
                                    title,
                                    metadata: metadata,
                                  );
                            } else {
                              ref
                                  .read(dashboardProvider.notifier)
                                  .updateBlock(
                                    block.copyWith(
                                      title: 'Filtro',
                                      metadata: {
                                        ...block.metadata,
                                        ...metadata,
                                      },
                                    ),
                                  );
                            }
                            Navigator.pop(sheetContext);
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            createNew ? 'Criar widget' : 'Salvar filtro',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  BlockType _blockTypeFromName(String? name) {
    return BlockType.values.firstWhere(
      (type) => type.name == name && type != BlockType.universal,
      orElse: () => BlockType.plannerDay,
    );
  }

  String _titleForBlockType(BlockType type) {
    final match = DashboardNotifier.availableWidgetBlocks
        .where((block) => block.type == type)
        .firstOrNull;
    return match?.title ?? 'Widget';
  }

  IconData _iconForBlockType(BlockType type) {
    switch (type) {
      case BlockType.plannerDay:
        return Icons.today_rounded;
      case BlockType.plannerWeek:
        return Icons.date_range_rounded;
      case BlockType.plannerMonth:
        return Icons.calendar_month_rounded;
      case BlockType.pomodoroSummary:
      case BlockType.timer:
        return Icons.timer_rounded;
      case BlockType.organizerSummary:
        return Icons.account_tree_rounded;
      case BlockType.tasks:
        return Icons.check_circle_outline_rounded;
      case BlockType.goals:
        return Icons.track_changes_rounded;
      case BlockType.habits:
        return Icons.loop_rounded;
      case BlockType.notes:
        return Icons.sticky_note_2_rounded;
      default:
        return Icons.dashboard_customize_rounded;
    }
  }

  DateTime _dateForPlannerItem(ContentObject item) {
    if (item is Task) return item.startDate ?? item.endDate ?? item.updatedAt;
    return item.updatedAt;
  }

  bool _isSameDay(DateTime? a, DateTime b) {
    return a != null &&
        a.year == b.year &&
        a.month == b.month &&
        a.day == b.day;
  }

  Widget _buildPlannerDayBlock() {
    final tasks = ref.watch(tasksProvider);
    final today = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(today);

    final dayItems = tasks
        .where(
          (t) =>
              t.endDate != null &&
              DateFormat('yyyy-MM-dd').format(t.endDate!) == todayStr,
        )
        .toList();

    dayItems.sort((a, b) {
      final aTime = a.scheduledTime ?? '00:00';
      final bTime = b.scheduledTime ?? '00:00';
      return aTime.compareTo(bTime);
    });

    final dailyNoteAsync = ref.watch(dailyNoteDataProvider(todayStr));
    final trackerDefinitions = ref.watch(trackersProvider);

    return _buildCard(
      title: 'Planner do Dia',
      icon: Icons.today_rounded,
      onAdd: () => showCreateMenu(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (dayItems.isEmpty)
            const Text(
              'Nada planejado para hoje',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            )
          else
            ...dayItems.map((item) => _buildPlannerItem(item)),

          const Divider(height: 32),

          Builder(
            builder: (context) {
              final data = dailyNoteAsync;
              final records = data['trackers'] as Map<String, dynamic>? ?? {};
              if (records.isEmpty) return const SizedBox.shrink();

              // Get historical data for sparklines
              final allRecordsAsync = ref.watch(
                objectsByTypeProvider('tracker_record'),
              );
              final allRecords = allRecordsAsync.cast<TrackingRecord>();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Today's Metrics",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 100,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: records.entries.expand((trackerEntry) {
                        final trackerId = trackerEntry.key;
                        final fields =
                            trackerEntry.value as Map<String, dynamic>;

                        final def = trackerDefinitions.firstWhere(
                          (d) => d.id == trackerId,
                          orElse: () => TrackerDefinition(
                            id: trackerId,
                            title: trackerId,
                            sections: [],
                          ),
                        );

                        return fields.entries.map((fieldEntry) {
                          final fieldId = fieldEntry.key;
                          final value = fieldEntry.value;

                          // Extract history for this specific field
                          final history = allRecords
                              .where((r) => r.trackerId == trackerId)
                              .map((r) => r.fieldValues[fieldId])
                              .whereType<num>()
                              .map((n) => n.toDouble())
                              .toList();

                          return TrackerMetricCard(
                            definition: def,
                            fieldId: fieldId,
                            value: value,
                            history: history.length > 1 ? history : null,
                          );
                        });
                      }).toList(),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPlannerWeekBlock() {
    final tasks = ref.watch(tasksProvider);
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));

    final weekItems = [
      ...tasks.where(
        (t) =>
            t.endDate != null &&
            t.endDate!.isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
            t.endDate!.isBefore(endOfWeek.add(const Duration(days: 1))),
      ),
    ];

    return _buildCard(
      title: 'Week',
      icon: Icons.date_range_rounded,
      onAdd: () => showCreateMenu(context),
      child: weekItems.isEmpty
          ? const Text(
              'Nothing planned for this week',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            )
          : Column(
              children: weekItems
                  .take(5)
                  .map((item) => _buildPlannerItem(item, showDate: true))
                  .toList(),
            ),
    );
  }

  Widget _buildPlannerMonthBlock() {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final firstDay = DateTime(now.year, now.month, 1).weekday;

    final tasks = ref.watch(tasksProvider);

    return _buildCard(
      title: 'Month',
      icon: Icons.calendar_month_rounded,
      onAdd: () => showCreateMenu(context),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                .map(
                  (d) => Text(
                    d,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textMuted,
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemCount: 35, // Show 5 weeks
            itemBuilder: (context, index) {
              final dayNum = index - (firstDay - 1) + 1;
              final isCurrentMonth = dayNum > 0 && dayNum <= daysInMonth;
              final isToday = dayNum == now.day;

              if (!isCurrentMonth) return const SizedBox.shrink();

              final date = DateTime(now.year, now.month, dayNum);
              final hasItems = tasks.any(
                (t) =>
                    t.endDate != null &&
                    t.endDate!.year == date.year &&
                    t.endDate!.month == date.month &&
                    t.endDate!.day == date.day,
              );

              return GestureDetector(
                onTap: () {
                  context.push(
                    '/planner',
                    extra: {'initialDate': date, 'showPopup': true},
                  );
                },
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isToday
                        ? AppColors.primary
                        : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        dayNum.toString(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isToday
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isToday ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      if (hasItems && !isToday)
                        Positioned(
                          bottom: 2,
                          child: Container(
                            width: 3,
                            height: 3,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildPomodoroSummaryBlock() {
    final timerState = ref.watch(pomodoroProvider);
    final history = timerState.history;
    final now = DateTime.now();
    final startOfWeek = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));

    final Map<String, int> taskMinutes = {};
    final Map<String, int> dayMinutes = {
      for (var i = 0; i < 7; i++)
        DateFormat('E').format(startOfWeek.add(Duration(days: i))): 0,
    };
    for (final session in history.where(
      (s) => !s.date.isBefore(startOfWeek),
    )) {
      taskMinutes[session.title] =
          (taskMinutes[session.title] ?? 0) + session.minutesWorked;
      final dayKey = DateFormat('E').format(session.date);
      dayMinutes[dayKey] =
          (dayMinutes[dayKey] ?? 0) + session.minutesWorked;
    }

    final sortedTasks = taskMinutes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final totalMinutes = taskMinutes.values.fold(0, (sum, m) => sum + m);
    final maxDayMinutes = dayMinutes.values.fold(
      0,
      (max, m) => m > max ? m : max,
    );

    return _buildCard(
      title: 'Focus Summary',
      icon: Icons.pie_chart_rounded,
      onAdd: () => showCreateMenu(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${history.length} sessions',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                '${(totalMinutes / 60).toStringAsFixed(1)}h total',
                style: TextStyle(
                  color: AppTheme.textMutedColor(context),
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (sortedTasks.isEmpty)
            Text(
              'No sessions logged',
              style: TextStyle(
                color: AppTheme.textMutedColor(context),
                fontSize: 13,
              ),
            )
          else ...[
            SizedBox(
              height: 72,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: dayMinutes.entries.map((entry) {
                  final barHeight = maxDayMinutes == 0
                      ? 4.0
                      : 8.0 + (entry.value / maxDayMinutes) * 44.0;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            height: barHeight,
                            decoration: BoxDecoration(
                              color: entry.value > 0
                                  ? AppColors.error.withValues(alpha: 0.75)
                                  : AppTheme.surfaceVariantColor(context),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            entry.key,
                            style: TextStyle(
                              fontSize: 10,
                              color: AppTheme.textMutedColor(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
            ...sortedTasks
                .take(3)
                .map(
                  (entry) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          size: 14,
                          color: AppColors.error,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            entry.key.isEmpty ? 'Sem task' : entry.key,
                            style: const TextStyle(fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${entry.value}m',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildOrganizerSummaryBlock(DashboardBlock block) {
    final allObjects = ref
        .watch(allObjectsProvider)
        .maybeWhen(data: (items) => items, orElse: () => <ContentObject>[]);
    final organizerId = block.metadata['organizerId'] as String?;
    final organizers = allObjects
        .where(
          (o) =>
              o.type == 'organizer' ||
              o.type == 'project' ||
              o.type == 'person',
        )
        .toList();
    final organizer = organizerId == null
        ? (organizers.isNotEmpty ? organizers.first : null)
        : organizers.where((o) => o.id == organizerId).firstOrNull;

    if (organizer == null) {
      return _buildCard(
        title: 'Organizer',
        icon: Icons.account_tree_rounded,
        child: const Text(
          'Choose an organizer in this block filters.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      );
    }

    final refs = allObjects.where((object) {
      if (object.id == organizer.id) return false;
      return object.organizers.any(
        (ref) => ref.matches(organizer.id, organizer.slug, organizer.title),
      );
    }).toList();
    final tasks = refs.whereType<Task>().toList();
    final entries = refs.whereType<JournalEntry>().toList();
    final pomodoros = ref.watch(pomodoroProvider).history.where((session) {
      final title = session.title.toLowerCase();
      return title.contains(organizer.title.toLowerCase()) ||
          title.contains(organizer.slug.toLowerCase());
    }).toList();

    return _buildCard(
      title: organizer.title,
      icon: Icons.account_tree_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _summaryChip('${tasks.length}', 'tasks', AppColors.info),
              _summaryChip('0', 'eventos', AppColors.primary),
              _summaryChip('${pomodoros.length}', 'pomodoros', AppColors.error),
              _summaryChip('${entries.length}', 'notes', AppColors.habitPurple),
            ],
          ),
          const SizedBox(height: 12),
          ...refs.take(3).map((item) => _buildOrganizerSummaryItem(item)),
          if (refs.isEmpty && pomodoros.isEmpty)
            const Text(
              'Nada associado ainda.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
        ],
      ),
    );
  }

  Widget _summaryChip(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$value $label',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildOrganizerSummaryItem(ContentObject item) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => UniversalDetailView(object: item)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(_iconForObject(item), size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                item.displayTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textPrimaryColor(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForObject(ContentObject item) {
    if (item is Task) return Icons.check_circle_outline_rounded;
    if (item is JournalEntry) return Icons.auto_stories_rounded;
    return Icons.circle_rounded;
  }

  Widget _buildPlannerItem(dynamic item, {bool showDate = false}) {
    final object = item as ContentObject;
    final task = item is Task ? item : null;
    final title = object.displayTitle;
    final time = task != null ? (task.scheduledTime ?? 'All day') : '';
    final date = task?.endDate ?? object.createdAt;

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => UniversalDetailView(object: object)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            if (task != null) ...[
              Checkbox(
                value: task.isCompleted,
                onChanged: (_) {
                  HapticFeedback.mediumImpact();
                  ref
                      .read(tasksProvider.notifier)
                      .updateTask(
                        task.copyWith(
                          stage: task.isCompleted
                              ? TaskStage.todo
                              : TaskStage.finalized,
                        ),
                      );
                },
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                activeColor: AppColors.primary,
              ),
              const SizedBox(width: 8),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color:
                    (task != null ? AppColors.primary : AppColors.habitPurple)
                        .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                time,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: task != null
                      ? AppColors.primary
                      : AppColors.habitPurple,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (showDate)
                    Text(
                      DateFormat('EEE, d MMM').format(date),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPinnedObjectBlock(DashboardBlock block) {
    final objectId = block.metadata['objectId'];
    if (objectId == null) {
      return _buildCard(
        title: 'Objeto Fixado',
        icon: Icons.push_pin_rounded,
        child: InkWell(
          onTap: () => _showObjectPickerForBlock(block),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(
                'Toque para escolher um objeto...',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            ),
          ),
        ),
      );
    }

    final allObjects = ref.watch(allObjectsProvider).valueOrNull ?? [];
    final object = allObjects.where((o) => o.id == objectId).firstOrNull;

    if (object == null) {
      return _buildCard(
        title: 'Object not found',
        icon: Icons.error_outline_rounded,
        child: const Text('The original object may have been deleted.'),
      );
    }

    String? bodyContent;
    if (object is JournalEntry) {
      bodyContent = object.body;
    }

    return _buildCard(
      title: object.title,
      icon: _iconForObject(object),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UniversalDetailView(object: object),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              object.type.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            if (bodyContent != null && bodyContent.isNotEmpty)
              Text(
                bodyContent,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textPrimaryColor(
                    context,
                  ).withValues(alpha: 0.8),
                ),
              ),
            if (object is Task && object.scheduledTime != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    object.scheduledTime!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showObjectPickerForBlock(DashboardBlock block) async {
    final result = await showModalBottomSheet<NavigationItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const NavigationShortcutPicker(),
    );

    if (result != null) {
      final updated = block.copyWith(
        title: result.label,
        metadata: {
          ...block.metadata,
          'objectId': result.id,
          'objectType': result.type,
        },
      );
      ref.read(dashboardProvider.notifier).updateBlock(updated);
    }
  }
}

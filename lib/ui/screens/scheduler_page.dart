// lib/ui/screens/scheduler_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/vault_provider.dart';
import '../../models/task_model.dart';
import '../../models/habit_model.dart';
import '../../models/day_theme_model.dart';
import '../../services/scheduler_service.dart';
import '../theme.dart';

class _ThemeForecast {
  final DayTheme theme;
  final List<DateTime> activeDates;
  final List<Task> tasks;
  final List<Habit> habits;

  _ThemeForecast({
    required this.theme,
    required this.activeDates,
    required this.tasks,
    required this.habits,
  });
}

class SchedulerPage extends ConsumerStatefulWidget {
  const SchedulerPage({super.key});

  @override
  ConsumerState<SchedulerPage> createState() => _SchedulerPageState();
}

class _SchedulerPageState extends ConsumerState<SchedulerPage> {
  String _selectedTab = 'list'; // 'list', 'theme', 'vinculados'
  int _timeframeDays = 30; // 7 or 30

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(tasksProvider);
    final habits = ref.watch(habitsProvider);
    final dayThemes = ref.watch(dayThemesProvider);
    final timeBlocks = ref.watch(timeBlocksProvider);

    final scheduledTasks = tasks.where((t) => t.scheduler != null).toList();
    final scheduledHabits = habits
        .where((h) => h.schedulers.isNotEmpty)
        .toList();

    // Helper functions for theme and block rules
    bool isThemeActive(String themeId, DateTime date) {
      const weekDayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final dayName = weekDayNames[date.weekday - 1];
      return dayThemes.any(
        (theme) => theme.id == themeId && theme.daysOfWeek.contains(dayName),
      );
    }

    bool isBlockActive(String blockId, DateTime date) {
      return timeBlocks.any((block) {
        if (block.id != blockId) return false;
        return dayThemes.any((theme) {
          if (!theme.blockIds.contains(blockId)) return false;
          return isThemeActive(theme.id, date);
        });
      });
    }

    bool isItemScheduled(String linkedItemId, DateTime date) {
      final targetSlug = linkedItemId
          .replaceAll('[[', '')
          .replaceAll(']]', '')
          .trim()
          .toLowerCase();
      final reminders = ref.read(remindersProvider);

      final hasLinkedTask = tasks.any((t) {
        final isScheduled =
            (t.deadline != null &&
                t.deadline!.year == date.year &&
                t.deadline!.month == date.month &&
                t.deadline!.day == date.day) ||
            (t.scheduler != null &&
                SchedulerService.shouldFire(
                  t.scheduler!,
                  date,
                  isThemeActive: isThemeActive,
                  isBlockActive: isBlockActive,
                ));
        if (!isScheduled) return false;
        return t.id == linkedItemId ||
            t.slug == targetSlug ||
            t.organizers.any(
              (o) =>
                  o.slug == targetSlug || o.title.toLowerCase() == targetSlug,
            );
      });
      if (hasLinkedTask) return true;

      final hasLinkedReminder = reminders.any((r) {
        final isScheduled =
            (r.time.year == date.year &&
                r.time.month == date.month &&
                r.time.day == date.day) ||
            (r.scheduler != null &&
                SchedulerService.shouldFire(
                  r.scheduler!,
                  date,
                  isThemeActive: isThemeActive,
                  isBlockActive: isBlockActive,
                ));
        if (!isScheduled) return false;
        return r.id == linkedItemId ||
            r.slug == targetSlug ||
            r.organizers.any(
              (o) =>
                  o.slug == targetSlug || o.title.toLowerCase() == targetSlug,
            );
      });
      return hasLinkedReminder;
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Agendador Global'), elevation: 0),
      body: SafeArea(
        child: Column(
          children: [
            _buildSegmentSelector(),
            if (_selectedTab == 'theme') _buildTimeframeSelector(),
            Expanded(
              child: _selectedTab == 'list'
                  ? _buildListView(scheduledTasks, scheduledHabits)
                  : _buildThemeForecastView(
                      dayThemes,
                      tasks,
                      habits,
                      isThemeActive,
                      isBlockActive,
                      isItemScheduled,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 'list'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedTab == 'list'
                      ? AppColors.surface
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: _selectedTab == 'list'
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  'Todos Agendados',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: _selectedTab == 'list'
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: _selectedTab == 'list'
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 'theme'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedTab == 'theme'
                      ? AppColors.surface
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: _selectedTab == 'theme'
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  'Previsão por Tema',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: _selectedTab == 'theme'
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: _selectedTab == 'theme'
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeframeSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          const Text(
            'Período da Previsão:',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          ChoiceChip(
            label: const Text('7 dias'),
            selected: _timeframeDays == 7,
            onSelected: (selected) {
              if (selected) setState(() => _timeframeDays = 7);
            },
            selectedColor: AppColors.primary.withValues(alpha: 0.15),
            checkmarkColor: AppColors.primary,
            labelStyle: TextStyle(
              color: _timeframeDays == 7
                  ? AppColors.primary
                  : AppColors.textMuted,
              fontWeight: _timeframeDays == 7
                  ? FontWeight.bold
                  : FontWeight.normal,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('30 dias'),
            selected: _timeframeDays == 30,
            onSelected: (selected) {
              if (selected) setState(() => _timeframeDays = 30);
            },
            selectedColor: AppColors.primary.withValues(alpha: 0.15),
            checkmarkColor: AppColors.primary,
            labelStyle: TextStyle(
              color: _timeframeDays == 30
                  ? AppColors.primary
                  : AppColors.textMuted,
              fontWeight: _timeframeDays == 30
                  ? FontWeight.bold
                  : FontWeight.normal,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListView(
    List<Task> scheduledTasks,
    List<Habit> scheduledHabits,
  ) {
    if (scheduledTasks.isEmpty && scheduledHabits.isEmpty) {
      return const Center(
        child: Text(
          'Nenhum item agendado encontrado.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 15),
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        if (scheduledTasks.isNotEmpty) ...[
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 10, 20, 10),
              child: Text(
                'Tarefas Agendadas',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) =>
                    _buildSchedulerItem(context, scheduledTasks[index]),
                childCount: scheduledTasks.length,
              ),
            ),
          ),
        ],
        if (scheduledHabits.isNotEmpty) ...[
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 10),
              child: Text(
                'Hábitos Agendados',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) =>
                    _buildSchedulerItem(context, scheduledHabits[index]),
                childCount: scheduledHabits.length,
              ),
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }

  Widget _buildSchedulerItem(BuildContext context, dynamic item) {
    final scheduler = item is Task
        ? item.scheduler
        : (item as Habit).schedulers.first;
    final nextDate = SchedulerService.nextOccurrence(scheduler!);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(context),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Próxima ocorrência: ${nextDate != null ? DateFormat('dd/MM/yyyy').format(nextDate) : "Nenhuma"}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              scheduler.rules.first.repeatType.name,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeForecastView(
    List<DayTheme> dayThemes,
    List<Task> tasks,
    List<Habit> habits,
    bool Function(String, DateTime) isThemeActive,
    bool Function(String, DateTime) isBlockActive,
    bool Function(String, DateTime) isItemScheduled,
  ) {
    if (dayThemes.isEmpty) {
      return const Center(
        child: Text(
          'Nenhum Tema de Dia cadastrado.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 15),
        ),
      );
    }

    final today = DateTime.now();
    final dates = List.generate(_timeframeDays, (i) {
      final date = today.add(Duration(days: i));
      return DateTime(date.year, date.month, date.day);
    });

    final forecasts = dayThemes.map((theme) {
      final activeDates = dates
          .where((d) => isThemeActive(theme.id, d))
          .toList();

      final themeTasks = tasks.where((t) {
        if (t.scheduler == null) return false;
        return activeDates.any(
          (date) => SchedulerService.shouldFire(
            t.scheduler!,
            date,
            isThemeActive: isThemeActive,
            isBlockActive: isBlockActive,
            isItemScheduled: isItemScheduled,
          ),
        );
      }).toList();

      final themeHabits = habits.where((h) {
        if (h.schedulers.isEmpty) return false;
        return activeDates.any((date) {
          return h.schedulers.any(
            (s) => SchedulerService.shouldFire(
              s,
              date,
              isThemeActive: isThemeActive,
              isBlockActive: isBlockActive,
              isItemScheduled: isItemScheduled,
            ),
          );
        });
      }).toList();

      return _ThemeForecast(
        theme: theme,
        activeDates: activeDates,
        tasks: themeTasks,
        habits: themeHabits,
      );
    }).toList();

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 40),
      itemCount: forecasts.length,
      itemBuilder: (context, index) => _buildThemeForecastCard(
        context,
        forecasts[index],
        isThemeActive,
        isBlockActive,
        isItemScheduled,
      ),
    );
  }

  Widget _buildThemeForecastCard(
    BuildContext context,
    _ThemeForecast forecast,
    bool Function(String, DateTime) isThemeActive,
    bool Function(String, DateTime) isBlockActive,
    bool Function(String, DateTime) isItemScheduled,
  ) {
    final hasItems = forecast.tasks.isNotEmpty || forecast.habits.isNotEmpty;
    forecast.activeDates.sort();

    final daysStr = forecast.theme.daysOfWeek
        .map((day) {
          switch (day) {
            case 'Mon':
              return 'Seg';
            case 'Tue':
              return 'Ter';
            case 'Wed':
              return 'Qua';
            case 'Thu':
              return 'Qui';
            case 'Fri':
              return 'Sex';
            case 'Sat':
              return 'Sáb';
            case 'Sun':
              return 'Dom';
            default:
              return day;
          }
        })
        .join(', ');

    final themeColor = forecast.theme.color != null
        ? Color(int.tryParse(forecast.theme.color!) ?? 0xFFE0E0E0)
        : AppColors.primary;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: AppTheme.cardDecoration(context).copyWith(
        border: Border(left: BorderSide(color: themeColor, width: 4)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            key: PageStorageKey(forecast.theme.id),
            title: Text(
              forecast.theme.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text(
              'Dias: $daysStr (${forecast.activeDates.length} ocorrências)',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            leading: Icon(Icons.dashboard_customize_rounded, color: themeColor),
            childrenPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            children: [
              if (!hasItems)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Nenhum item agendado para este tema no período.',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                )
              else ...[
                if (forecast.tasks.isNotEmpty) ...[
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.only(top: 8, bottom: 4),
                      child: Text(
                        'TAREFAS GERADAS',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                          color: AppColors.textMuted,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                  ...forecast.tasks.map(
                    (task) => _buildForecastItem(
                      context,
                      task,
                      forecast.activeDates,
                      isThemeActive,
                      isBlockActive,
                      isItemScheduled,
                    ),
                  ),
                ],
                if (forecast.habits.isNotEmpty) ...[
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.only(top: 12, bottom: 4),
                      child: Text(
                        'HÁBITOS ATIVOS',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                          color: AppColors.textMuted,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                  ...forecast.habits.map(
                    (habit) => _buildForecastItem(
                      context,
                      habit,
                      forecast.activeDates,
                      isThemeActive,
                      isBlockActive,
                      isItemScheduled,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForecastItem(
    BuildContext context,
    dynamic item,
    List<DateTime> themeDates,
    bool Function(String, DateTime) isThemeActive,
    bool Function(String, DateTime) isBlockActive,
    bool Function(String, DateTime) isItemScheduled,
  ) {
    final fireDates = themeDates.where((date) {
      if (item is Task) {
        return SchedulerService.shouldFire(
          item.scheduler!,
          date,
          isThemeActive: isThemeActive,
          isBlockActive: isBlockActive,
          isItemScheduled: isItemScheduled,
        );
      } else {
        return (item as Habit).schedulers.any(
          (s) => SchedulerService.shouldFire(
            s,
            date,
            isThemeActive: isThemeActive,
            isBlockActive: isBlockActive,
            isItemScheduled: isItemScheduled,
          ),
        );
      }
    }).toList();

    fireDates.sort();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                item is Task
                    ? Icons.check_circle_outline_rounded
                    : Icons.repeat_rounded,
                size: 16,
                color: item is Task ? AppColors.info : AppColors.habitOrange,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: fireDates.map((date) {
                final dateLabel = _formatOccurrenceDate(date);
                return Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppColors.textMuted.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Text(
                    dateLabel,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 6),
          const Divider(height: 1, thickness: 0.5),
        ],
      ),
    );
  }

  String _formatOccurrenceDate(DateTime date) {
    final today = DateTime.now();
    final tomorrow = today.add(const Duration(days: 1));
    final isToday =
        date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
    final isTomorrow =
        date.year == tomorrow.year &&
        date.month == tomorrow.month &&
        date.day == tomorrow.day;
    if (isToday) return 'Hoje';
    if (isTomorrow) return 'Amanhã';

    const weekDaysPt = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
    final dayName = weekDaysPt[date.weekday - 1];
    return '$dayName, ${date.day}/${date.month}';
  }
}

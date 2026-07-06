// lib/windows_dial_main.dart
// Windows companion app entry point for DayDialWidget
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'models/day_dial_model.dart';
import 'services/day_dial_aggregator.dart';
import 'ui/widgets/day_dial_widget.dart';
import 'ui/theme.dart';
import 'providers/vault_provider.dart';
import 'providers/settings_provider.dart';
import 'models/task_model.dart';
import 'models/habit_model.dart';
import 'models/pomodoro_session.dart';
import 'package:googleapis/calendar/v3.dart' as google_calendar;
import 'providers/pomodoro_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize providers
  final container = ProviderContainer();
  
  // Trigger vault loading by accessing the allObjectsProvider
  await container.read(allObjectsProvider.future);
  
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const WindowsDialApp(),
    ),
  );
}

class WindowsDialApp extends ConsumerWidget {
  const WindowsDialApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Citrine Dial',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.accent),
        useMaterial3: true,
      ),
      home: const WindowsDialHome(),
    );
  }
}

class WindowsDialHome extends ConsumerStatefulWidget {
  const WindowsDialHome({super.key});

  @override
  ConsumerState<WindowsDialHome> createState() => _WindowsDialHomeState();
}

class _WindowsDialHomeState extends ConsumerState<WindowsDialHome> {
  late DateTime _selectedDate;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    
    // Refresh every minute to update current time
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(tasksProvider);
    final habits = ref.watch(habitsProvider);
    final pomodoroSessions = ref.watch(pomodoroProvider).history;
    
    // Filter tasks for the selected date
    final dayTasks = tasks.where((task) {
      if (task.startDate == null) return false;
      return _isSameDay(task.startDate!, _selectedDate);
    }).toList();

    // Filter habits for the selected date
    final dayHabits = habits.where((habit) {
      // Simple check - in production use SchedulerService
      return true;
    }).toList();

    // Aggregate hour states
    final hourStates = DayDialAggregator.aggregateForDate(
      date: _selectedDate,
      tasks: dayTasks,
      habits: dayHabits,
      pomodoroSessions: pomodoroSessions,
      googleEvents: [], // No Google Calendar in Windows companion
    );

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(context),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Date selector
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    setState(() {
                      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
                    });
                  },
                ),
                Text(
                  DateFormat('MMM d, yyyy').format(_selectedDate),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    setState(() {
                      _selectedDate = _selectedDate.add(const Duration(days: 1));
                    });
                  },
                ),
                const SizedBox(width: 16),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedDate = DateTime.now();
                    });
                  },
                  child: const Text('Today'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Day dial widget
            SizedBox(
              width: 350,
              height: 350,
              child: DayDialWidget(
                hourStates: hourStates,
                selectedDate: _selectedDate,
                onHourTap: (hour) {
                  // Could open a detail view or navigate to main app
                  print('Tapped hour: $hour');
                },
              ),
            ),
            const SizedBox(height: 24),
            // Legend
            _buildLegend(context),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariantColor(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Legend',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          _buildLegendItem('Completed Pomodoro', AppColors.success),
          _buildLegendItem('Planned Task', AppColors.accent.withValues(alpha: 0.6)),
          _buildLegendItem('Event', AppColors.info),
          _buildLegendItem('Idle', AppColors.textMuted.withValues(alpha: 0.2)),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

// lib/windows_dial_main.dart
// Windows companion app entry point for DayDialWidget
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'services/day_dial_aggregator.dart';
import 'ui/widgets/day_dial_widget.dart';
import 'ui/theme.dart';
import 'providers/vault_provider.dart';
import 'providers/pomodoro_provider.dart';
import 'models/content_object.dart';
import 'models/event_model.dart';
import 'models/journal_entry.dart';
import 'models/mood_model.dart';
import 'models/organizer_model.dart';
import 'models/reminder_model.dart';
import 'models/task_model.dart';
import 'models/habit_model.dart';

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
      title: 'Quartzo Dial',
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
    final allObjects = ref.watch(allObjectsProvider).valueOrNull ?? <ContentObject>[];
    final tasks = allObjects.whereType<Task>().toList();
    final habits = allObjects.whereType<Habit>().toList();
    final pomodoroHistory = ref.watch(pomodoroProvider).history;
    
    final journalEntries = allObjects.whereType<JournalEntry>().toList();
    final moodDefinitions = allObjects.whereType<MoodDefinition>().toList();
    final reminders = allObjects.whereType<Reminder>().toList();
    final localEvents = allObjects.whereType<Event>().toList();
    final timeBlocks = allObjects.whereType<Organizer>()
        .where((o) => o.organizerType == OrganizerType.timeBlock)
        .toList();
    
    final dayTasks = tasks.where((task) {
      final startDate = task.startDate;
      if (startDate == null) return false;
      return _isSameDay(startDate, _selectedDate);
    }).toList();

    final dayHabits = habits.where((habit) => true).toList();

    final snapshot = DayDialAggregator.aggregateForDate(
      date: _selectedDate,
      tasks: dayTasks,
      habits: dayHabits,
      pomodoroSessions: pomodoroHistory,
      googleEvents: const [],
      localEvents: localEvents,
      reminders: reminders,
      timeBlocks: timeBlocks,
      journalEntries: journalEntries,
      moodCatalog: moodDefinitions,
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
                snapshot: snapshot,
                selectedDate: _selectedDate,
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

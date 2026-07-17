// lib/ui/screens/widgets_management_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';
import '../../providers/settings_provider.dart';
import '../../providers/widget_sync_provider.dart';

class WidgetsManagementScreen extends ConsumerStatefulWidget {
  const WidgetsManagementScreen({super.key});

  @override
  ConsumerState<WidgetsManagementScreen> createState() => _WidgetsManagementScreenState();
}

class _WidgetsManagementScreenState extends ConsumerState<WidgetsManagementScreen> {
  final List<Map<String, dynamic>> _widgets = [
    {
      'title': 'Calendar / Planner',
      'description': 'Shows upcoming schedule and timeline.',
      'icon': Icons.calendar_month,
      'color': AppColors.habitBlue,
      'id': 'calendar',
    },
    {
      'title': 'Day Dial',
      'description': 'Visual dial showing today\'s progress and tasks.',
      'icon': Icons.data_usage,
      'color': AppColors.warning,
      'id': 'day_dial',
    },
    {
      'title': 'Month Overview',
      'description': 'Full month calendar with customizable indicators.',
      'icon': Icons.calendar_view_month,
      'color': AppColors.habitPurple,
      'id': 'month',
      'configurable': true,
    },
    {
      'title': 'Note',
      'description': 'Displays a pinned note for quick access.',
      'icon': Icons.sticky_note_2,
      'color': AppColors.warning,
      'id': 'note',
    },
    {
      'title': 'Pomodoro',
      'description': 'Shows focus timer status and weekly summary.',
      'icon': Icons.timer,
      'color': AppColors.error,
      'id': 'pomodoro',
    },
    {
      'title': 'Quick Add',
      'description': 'Action shortcuts to quickly add new items.',
      'icon': Icons.add_circle_outline,
      'color': AppColors.habitGreen,
      'id': 'quick_add',
    },
    {
      'title': 'Shopping List',
      'description': 'Quick view of your active shopping items.',
      'icon': Icons.shopping_cart,
      'color': AppColors.habitBlue,
      'id': 'shopping',
    },
    {
      'title': 'Tasks',
      'description': 'Dedicated view focused on your daily tasks.',
      'icon': Icons.check_circle_outline,
      'color': AppColors.habitGreen,
      'id': 'tasks',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Widgets'),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _widgets.length,
        itemBuilder: (context, index) {
          final widgetInfo = _widgets[index];
          return _buildWidgetCard(context, widgetInfo);
        },
      ),
    );
  }

  Widget _buildWidgetCard(BuildContext context, Map<String, dynamic> widgetInfo) {
    final bool configurable = widgetInfo['configurable'] == true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: configurable ? () => _showConfiguration(widgetInfo['id'] as String) : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: AppTheme.cardDecoration(context),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (widgetInfo['color'] as Color).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  widgetInfo['icon'] as IconData,
                  size: 24,
                  color: widgetInfo['color'] as Color,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widgetInfo['title'] as String,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widgetInfo['description'] as String,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (configurable)
                const Icon(
                  Icons.settings_outlined,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showConfiguration(String widgetId) {
    if (widgetId == 'month') {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => const MonthWidgetConfigSheet(),
      );
    }
  }
}

class MonthWidgetConfigSheet extends ConsumerStatefulWidget {
  const MonthWidgetConfigSheet({super.key});

  @override
  ConsumerState<MonthWidgetConfigSheet> createState() => _MonthWidgetConfigSheetState();
}

class _MonthWidgetConfigSheetState extends ConsumerState<MonthWidgetConfigSheet> {
  int _maxChips = 3;
  List<String> _visibleKinds = ['task', 'habit', 'reminder', 'google_calendar'];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    final prefs = ref.read(sharedPreferencesProvider);
    setState(() {
      _maxChips = prefs.getInt('monthWidgetMaxChips') ?? 3;
      _visibleKinds = prefs.getStringList('monthWidgetVisibleKinds') ?? 
          ['task', 'habit', 'reminder', 'google_calendar'];
    });
  }

  Future<void> _saveSettings() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt('monthWidgetMaxChips', _maxChips);
    await prefs.setStringList('monthWidgetVisibleKinds', _visibleKinds);
    
    if (mounted) {
      ref.invalidate(widgetSyncProvider);
      Navigator.pop(context);
    }
  }

  void _toggleKind(String kind) {
    setState(() {
      if (_visibleKinds.contains(kind)) {
        _visibleKinds.remove(kind);
      } else {
        _visibleKinds.add(kind);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24).copyWith(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Month Overview',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          const Text(
            'Max items per day',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                onPressed: _maxChips > 1 ? () => setState(() => _maxChips--) : null,
                icon: const Icon(Icons.remove_circle_outline),
                color: AppTheme.accentColor(context),
              ),
              Text(
                '$_maxChips',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              IconButton(
                onPressed: _maxChips < 3 ? () => setState(() => _maxChips++) : null,
                icon: const Icon(Icons.add_circle_outline),
                color: AppTheme.accentColor(context),
              ),
              const Spacer(),
              const Text(
                '(1 to 3 items)',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          const Text(
            'Visible Item Types',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFilterChip('Tarefas', 'task', AppColors.warning),
              _buildFilterChip('Hábitos', 'habit', AppColors.habitGreen),
              _buildFilterChip('Lembretes', 'reminder', AppColors.error),
              _buildFilterChip('Eventos', 'google_calendar', AppColors.habitBlue),
            ],
          ),
          
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _saveSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentColor(context),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Save Settings',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String kind, Color color) {
    final isSelected = _visibleKinds.contains(kind);
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      onSelected: (_) => _toggleKind(kind),
      selectedColor: color.withValues(alpha: 0.2),
      checkmarkColor: color,
      labelStyle: TextStyle(
        color: isSelected ? color : AppColors.textSecondary,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }
}

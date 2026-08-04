import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../models/monthly_focus_model.dart';
import '../../models/goal_model.dart';
import '../../models/habit_model.dart';
import '../../models/action_menu_item_model.dart';
import '../../providers/vault_provider.dart';
import '../theme.dart';

class MonthlyPlanningScreen extends ConsumerStatefulWidget {
  const MonthlyPlanningScreen({super.key});

  @override
  ConsumerState<MonthlyPlanningScreen> createState() => _MonthlyPlanningScreenState();
}

class _MonthlyPlanningScreenState extends ConsumerState<MonthlyPlanningScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  List<String> _selectedGoalIds = [];
  String? _selectedHabitId;
  List<String> _selectedSelfCareIds = [];
  final TextEditingController _reflectionController = TextEditingController();

  void _nextStep() {
    if (_currentStep < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _saveMonthlyFocus();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _saveMonthlyFocus() async {
    final now = DateTime.now();
    final focus = MonthlyFocus(
      id: const Uuid().v4(),
      title: 'Monthly Focus - ${now.month}/${now.year}',
      year: now.year,
      month: now.month,
      goalIds: _selectedGoalIds,
      habitId: _selectedHabitId,
      selfCareIds: _selectedSelfCareIds,
      reflection: _reflectionController.text,
      createdAt: now,
    );

    focus.obsidianPath = 'monthly_focus/${focus.id}.md';
    await ref.read(vaultProvider.notifier).createObject(focus);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Monthly focus saved!')),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Planning'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          _buildProgressIndicator(),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (idx) => setState(() => _currentStep = idx),
              children: [
                _buildGoalsStep(),
                _buildPriorityHabitStep(),
                _buildSelfCareStep(),
              ],
            ),
          ),
          _buildNavigationFooter(),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: List.generate(3, (index) {
          final isActive = index <= _currentStep;
          return Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: index < 2 ? 8 : 0),
              decoration: BoxDecoration(
                color: isActive ? AppTheme.accentColor(context) : AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildNavigationFooter() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 0)
            TextButton(
              onPressed: _previousStep,
              child: const Text('Back'),
            )
          else
            const SizedBox.shrink(),
          ElevatedButton(
            onPressed: _nextStep,
            child: Text(_currentStep < 2 ? 'Next' : 'Finish'),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalsStep() {
    final goals = ref.watch(goalsListProvider).where((g) => g.state == GoalStatus.active).toList();
    
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Select Goals for this month',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text('What are your main objectives?', style: TextStyle(color: AppColors.textMuted)),
        const SizedBox(height: 24),
        if (goals.isEmpty)
          const Text('No active goals found.')
        else
          ...goals.map((goal) {
            final isSelected = _selectedGoalIds.contains(goal.id);
            return CheckboxListTile(
              title: Text(goal.title),
              value: isSelected,
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    _selectedGoalIds.add(goal.id);
                  } else {
                    _selectedGoalIds.remove(goal.id);
                  }
                });
              },
            );
          }),
      ],
    );
  }

  Widget _buildPriorityHabitStep() {
    final habits = ref.watch(habitsListProvider);
    
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Choose a Priority Habit',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text('Which habit will make the most impact?', style: TextStyle(color: AppColors.textMuted)),
        const SizedBox(height: 24),
        if (habits.isEmpty)
          const Text('No habits found.')
        else
          ...habits.map((habit) {
            return RadioListTile<String>(
              title: Text(habit.title),
              value: habit.id,
              groupValue: _selectedHabitId,
              onChanged: (val) {
                setState(() {
                  _selectedHabitId = val;
                });
              },
            );
          }),
      ],
    );
  }

  Widget _buildSelfCareStep() {
    final actions = ref.watch(objectsByTypeProvider('action')).cast<ActionMenuItem>();
    
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Self-care Picks & Reflection',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text('Select actions that recharge your energy.', style: TextStyle(color: AppColors.textMuted)),
        const SizedBox(height: 24),
        if (actions.isEmpty)
          const Text('No actions found.')
        else
          ...actions.map((action) {
            final isSelected = _selectedSelfCareIds.contains(action.id);
            return CheckboxListTile(
              title: Text(action.title),
              value: isSelected,
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    _selectedSelfCareIds.add(action.id);
                  } else {
                    _selectedSelfCareIds.remove(action.id);
                  }
                });
              },
            );
          }),
        const SizedBox(height: 32),
        const Text('Reflection / Intention', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: _reflectionController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Any thoughts for this month?',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }
}

// lib/ui/widgets/steering_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/habit_model.dart';
import '../../providers/vault_provider.dart';
import '../theme.dart';
import '../forms/create_habit_form.dart';

class SteeringSheet extends ConsumerStatefulWidget {
  final Habit habit;

  const SteeringSheet({super.key, required this.habit});

  @override
  ConsumerState<SteeringSheet> createState() => _SteeringSheetState();
}

class _SteeringSheetState extends ConsumerState<SteeringSheet> {
  int _currentStep = 1;
  bool _allowClose = false;

  // Step 1 values
  final _reflectionController = TextEditingController();

  // Step 2 values
  String? _hypothesisEvaluation; // 'correct', 'incorrect', 'not_sure'
  String? _endedReason; // 'goal_achieved', 'obligation', 'adjust_scope'

  // Step 3 values
  final _learningController = TextEditingController();
  late final TextEditingController _persistDaysController;
  int _persistDays = 30;

  @override
  void initState() {
    super.initState();
    final startedAt = widget.habit.startedAt;
    final endsAt = widget.habit.endsAt;
    if (startedAt != null && endsAt != null) {
      final days = endsAt.difference(startedAt).inDays;
      if (days > 0) _persistDays = days;
    }
    _persistDaysController = TextEditingController(text: '$_persistDays');
  }

  @override
  void dispose() {
    _reflectionController.dispose();
    _learningController.dispose();
    _persistDaysController.dispose();
    super.dispose();
  }

  bool get _canAdvance {
    if (_currentStep == 1) return _reflectionController.text.trim().isNotEmpty;
    if (_currentStep == 2) {
      return _hypothesisEvaluation != null && _endedReason != null;
    }
    return true;
  }

  Color _parseColor(String hex) {
    try {
      String colorStr = hex.replaceAll('#', '');
      if (colorStr.length == 6) colorStr = 'FF$colorStr';
      return Color(int.parse(colorStr, radix: 16));
    } catch (_) {
      return AppTheme.accentColor(context);
    }
  }

  void _nextStep() {
    if (_currentStep < 3) {
      if (mounted) setState(() {
        _currentStep++;
      });
    }
  }

  void _previousStep() {
    if (_currentStep > 1) {
      if (mounted) setState(() {
        _currentStep--;
      });
    }
  }

  Future<void> _confirmClose() async {
    final shouldClose = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave review?'),
        content: const Text(
          'You can review this pact later. It will remain pending.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep reviewing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (shouldClose == true && mounted) {
      _allowClose = true;
      Navigator.pop(context);
    }
  }

  Future<void> _handleDecision(PactOutcome outcome) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final finishedCycle = PactCycle(
      startedAt:
          widget.habit.startedAt ?? today.subtract(const Duration(days: 30)),
      endsAt: widget.habit.endsAt ?? today,
      outcome: outcome,
      reflection: _reflectionController.text.trim(),
      hypothesisCorrect: _hypothesisEvaluation == 'correct'
          ? true
          : (_hypothesisEvaluation == 'incorrect' ? false : null),
      endedReason: _endedReason,
    );

    final updatedCycles = [...widget.habit.previousCycles, finishedCycle];

    Habit updatedHabit;

    if (outcome == PactOutcome.persist) {
      updatedHabit = widget.habit.copyWith(
        status: HabitStatus.active,
        pactOutcome: null,
        startedAt: today,
        endsAt: today.add(Duration(days: _persistDays)),
        previousCycles: updatedCycles,
        description: _learningController.text.trim().isNotEmpty
            ? _learningController.text.trim()
            : widget.habit.description,
      );
    } else if (outcome == PactOutcome.pause) {
      updatedHabit = widget.habit.copyWith(
        status: HabitStatus.paused,
        pactOutcome: PactOutcome.pause,
        startedAt: null,
        endsAt: null,
        previousCycles: updatedCycles,
        description: _learningController.text.trim().isNotEmpty
            ? _learningController.text.trim()
            : widget.habit.description,
      );
    } else {
      updatedHabit = widget.habit.copyWith(
        pactOutcome: PactOutcome.pivot,
        startedAt: null,
        endsAt: null,
        previousCycles: updatedCycles,
        description: _learningController.text.trim().isNotEmpty
            ? _learningController.text.trim()
            : widget.habit.description,
      );
    }

    try {
      await ref.read(vaultProvider.notifier).updateObject(updatedHabit);
    } catch (e) {
      // Error saving steering sheet outcome
    }

    if (mounted) {
      _allowClose = true;
      Navigator.pop(context);

      if (outcome == PactOutcome.pivot) {
        context.push('/create-habit', extra: {'existingHabit': updatedHabit});
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              outcome == PactOutcome.persist
                  ? 'Pacto renovado por mais $_persistDays dias!'
                  : 'Pacto finalizado e pausado.',
            ),
            backgroundColor: _parseColor(widget.habit.color),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(widget.habit.color);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: _allowClose,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _confirmClose();
      },
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.backgroundColor(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                // Drag handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.15)
                          : Colors.black.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Title area
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Steering Sheet (Pacto)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: color,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.habit.displayTitle,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimaryColor(context),
                                letterSpacing: -0.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _confirmClose,
                        icon: const Icon(Icons.close_rounded),
                        tooltip: 'Fechar',
                      ),
                      // Steps progress indicator
                      _buildStepDots(color),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(),

                // Step content
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _buildStepContent(context, color),
                  ),
                ),

                const Divider(),
                // Navigation buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_currentStep > 1)
                        TextButton.icon(
                          onPressed: _previousStep,
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: const Text('Back'),
                          style: TextButton.styleFrom(foregroundColor: color),
                        )
                      else
                        const SizedBox.shrink(),
                      const Spacer(),
                      if (_currentStep < 3)
                        FilledButton.icon(
                          onPressed: _canAdvance ? _nextStep : null,
                          icon: const Icon(Icons.arrow_forward_rounded),
                          label: const Text('Next'),
                          style: FilledButton.styleFrom(
                            backgroundColor: color,
                            disabledBackgroundColor: AppColors.textMuted
                                .withValues(alpha: 0.25),
                            disabledForegroundColor: AppColors.textMuted,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppBorderRadius.md),
                            ),
                          ),
                        )
                      else
                        const SizedBox.shrink(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepDots(Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        final isActive = index == _currentStep - 1;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: isActive ? 8 : 6,
          height: isActive ? 8 : 6,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? color : color.withValues(alpha: 0.3),
          ),
        );
      }),
    );
  }

  Widget _buildStepContent(BuildContext context, Color color) {
    switch (_currentStep) {
      case 1:
        return _buildStep1(context, color);
      case 2:
        return _buildStep2(context, color);
      case 3:
        return _buildStep3(context, color);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStep1(BuildContext context, Color color) {
    return Column(
      key: const ValueKey(1),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Step 1 — Review',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (widget.habit.hypothesis?.isNotEmpty == true) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppBorderRadius.md),
              border: Border.all(color: color.withValues(alpha: 0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your hypothesis was:',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '"${widget.habit.hypothesis!}"',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        const Text(
          'O que aconteceu?',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _reflectionController,
          onChanged: (_) { if (mounted) setState(() {}); },
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Escreva livremente sobre como foi esse ciclo...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppBorderRadius.md)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppBorderRadius.md),
              borderSide: BorderSide(color: color, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2(BuildContext context, Color color) {
    return Column(
      key: const ValueKey(2),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Step 2 — Reflection',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 14),
        const Text(
          'What did you learn from the hypothesis?',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _buildSelectOption(
          label: 'My hypothesis was correct',
          value: 'correct',
          groupValue: _hypothesisEvaluation,
          onChanged: (val) { if (mounted) setState(() => _hypothesisEvaluation = val); },
          activeColor: color,
        ),
        _buildSelectOption(
          label: 'My hypothesis was incorrect',
          value: 'incorrect',
          groupValue: _hypothesisEvaluation,
          onChanged: (val) { if (mounted) setState(() => _hypothesisEvaluation = val); },
          activeColor: color,
        ),
        _buildSelectOption(
          label: 'Not sure',
          value: 'not_sure',
          groupValue: _hypothesisEvaluation,
          onChanged: (val) { if (mounted) setState(() => _hypothesisEvaluation = val); },
          activeColor: color,
        ),
        const SizedBox(height: 20),
        const Text(
          'Por que o pacto terminou?',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _buildSelectOption(
          label: 'Achieved the goal',
          value: 'goal_achieved',
          groupValue: _endedReason,
          onChanged: (val) { if (mounted) setState(() => _endedReason = val); },
          activeColor: color,
        ),
        _buildSelectOption(
          label: 'Became a burden / weight',
          value: 'obligation',
          groupValue: _endedReason,
          onChanged: (val) { if (mounted) setState(() => _endedReason = val); },
          activeColor: color,
        ),
        _buildSelectOption(
          label: 'Quero ajustar o escopo',
          value: 'adjust_scope',
          groupValue: _endedReason,
          onChanged: (val) { if (mounted) setState(() => _endedReason = val); },
          activeColor: color,
        ),
      ],
    );
  }

  Widget _buildStep3(BuildContext context, Color color) {
    return Column(
      key: const ValueKey(3),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Step 3 — Decision',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const Text(
          'What did you learn from this pact?',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _learningController,
          maxLines: 2,
          decoration: InputDecoration(
            hintText: 'Inscreva o aprendizado chave (opcional)...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppBorderRadius.md)),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: _buildDecisionButton(
                title: 'PERSISTIR',
                subtitle: 'Por mais dias',
                onTap: () => _handleDecision(PactOutcome.persist),
                color: AppColors.habitGreen,
                extraWidget: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Dias: '),
                    SizedBox(
                      width: 54,
                      child: TextField(
                        controller: _persistDaysController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                        ),
                        onChanged: (value) {
                          final parsed = int.tryParse(value);
                          if (parsed != null && parsed > 0) {
                            _persistDays = parsed;
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildDecisionButton(
                title: 'PAUSAR',
                subtitle: 'Encerrar por ora',
                onTap: () => _handleDecision(PactOutcome.pause),
                color: Colors.grey,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildDecisionButton(
                title: 'PIVOTAR',
                subtitle: 'Ajustar pacto',
                onTap: () => _handleDecision(PactOutcome.pivot),
                color: AppTheme.accentColor(context),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSelectOption({
    required String label,
    required String value,
    required String? groupValue,
    required ValueChanged<String?> onChanged,
    required Color activeColor,
  }) {
    final isSelected = value == groupValue;
    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          children: [
            Radio<String>(
              value: value,
              // ignore: deprecated_member_use
              groupValue: groupValue,
              // ignore: deprecated_member_use
              onChanged: onChanged,
              activeColor: activeColor,
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDecisionButton({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color color,
    Widget? extraWidget,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: color,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: color.withValues(alpha: 0.8),
                fontWeight: FontWeight.bold,
              ),
            ),
            if (extraWidget != null) ...[
              const SizedBox(height: 6),
              extraWidget,
            ],
          ],
        ),
      ),
    );
  }
}

void showSteeringSheet(BuildContext context, Habit habit) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (_) => SteeringSheet(habit: habit),
  );
}

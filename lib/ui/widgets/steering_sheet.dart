// lib/ui/widgets/steering_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  // Step 1 values
  final _reflectionController = TextEditingController();

  // Step 2 values
  String? _hypothesisEvaluation; // 'correct', 'incorrect', 'not_sure'
  String? _endedReason; // 'goal_achieved', 'obligation', 'adjust_scope'

  // Step 3 values
  final _learningController = TextEditingController();
  int _persistDays = 30;

  @override
  void dispose() {
    _reflectionController.dispose();
    _learningController.dispose();
    super.dispose();
  }

  Color _parseColor(String hex) {
    try {
      String colorStr = hex.replaceAll('#', '');
      if (colorStr.length == 6) colorStr = 'FF$colorStr';
      return Color(int.parse(colorStr, radix: 16));
    } catch (_) {
      return AppColors.primary;
    }
  }

  void _nextStep() {
    if (_currentStep < 3) {
      setState(() {
        _currentStep++;
      });
    }
  }

  void _previousStep() {
    if (_currentStep > 1) {
      setState(() {
        _currentStep--;
      });
    }
  }

  Future<void> _handleDecision(PactOutcome outcome) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final finishedCycle = PactCycle(
      startedAt: widget.habit.startedAt ?? today.subtract(const Duration(days: 30)),
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
        previousCycles: updatedCycles,
        description: _learningController.text.trim().isNotEmpty
            ? _learningController.text.trim()
            : widget.habit.description,
      );
    } else {
      updatedHabit = widget.habit.copyWith(
        pactOutcome: PactOutcome.pivot,
        previousCycles: updatedCycles,
        description: _learningController.text.trim().isNotEmpty
            ? _learningController.text.trim()
            : widget.habit.description,
      );
    }

    try {
      await ref.read(vaultProvider.notifier).updateObject(updatedHabit);
    } catch (e) {
      debugPrint('Failed to save Steering Sheet outcome: $e');
    }

    if (mounted) {
      Navigator.pop(context);

      if (outcome == PactOutcome.pivot) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CreateHabitForm(existingHabit: updatedHabit),
          ),
        );
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

    return Padding(
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
                    // Steps progress indicator
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Etapa $_currentStep de 3',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Divider(),

              // Step content
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                        label: const Text('Voltar'),
                        style: TextButton.styleFrom(
                          foregroundColor: color,
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                    const Spacer(),
                    if (_currentStep < 3)
                      FilledButton.icon(
                        onPressed: _nextStep,
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: const Text('Avançar'),
                        style: FilledButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
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
          'Etapa 1 — Revisão',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (widget.habit.hypothesis?.isNotEmpty == true) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sua hipótese era:',
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
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Escreva livremente sobre como foi esse ciclo...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
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
          'Etapa 2 — Reflexão',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 14),
        const Text(
          'O que você aprendeu com a hipótese?',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _buildSelectOption(
          label: 'Minha hipótese estava correta',
          value: 'correct',
          groupValue: _hypothesisEvaluation,
          onChanged: (val) => setState(() => _hypothesisEvaluation = val),
          activeColor: color,
        ),
        _buildSelectOption(
          label: 'Minha hipótese estava incorreta',
          value: 'incorrect',
          groupValue: _hypothesisEvaluation,
          onChanged: (val) => setState(() => _hypothesisEvaluation = val),
          activeColor: color,
        ),
        _buildSelectOption(
          label: 'Não tenho certeza',
          value: 'not_sure',
          groupValue: _hypothesisEvaluation,
          onChanged: (val) => setState(() => _hypothesisEvaluation = val),
          activeColor: color,
        ),
        const SizedBox(height: 20),
        const Text(
          'Por que o pacto terminou?',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _buildSelectOption(
          label: 'Concluí o objetivo',
          value: 'goal_achieved',
          groupValue: _endedReason,
          onChanged: (val) => setState(() => _endedReason = val),
          activeColor: color,
        ),
        _buildSelectOption(
          label: 'Virou obrigação / peso',
          value: 'obligation',
          groupValue: _endedReason,
          onChanged: (val) => setState(() => _endedReason = val),
          activeColor: color,
        ),
        _buildSelectOption(
          label: 'Quero ajustar o escopo',
          value: 'adjust_scope',
          groupValue: _endedReason,
          onChanged: (val) => setState(() => _endedReason = val),
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
          'Etapa 3 — Decisão',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const Text(
          'O que você aprendeu com esse pacto?',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _learningController,
          maxLines: 2,
          decoration: InputDecoration(
            hintText: 'Inscreva o aprendizado chave (opcional)...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
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
                      width: 30,
                      child: DropdownButton<int>(
                        value: _persistDays,
                        items: [7, 14, 21, 30, 60, 90].map((d) {
                          return DropdownMenuItem<int>(
                            value: d,
                            child: Text('$d', style: const TextStyle(fontSize: 12)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _persistDays = val;
                            });
                          }
                        },
                        underline: const SizedBox.shrink(),
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
                color: AppColors.primary,
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
    backgroundColor: Colors.transparent,
    builder: (_) => SteeringSheet(habit: habit),
  );
}

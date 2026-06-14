// lib/ui/forms/create_habit_form.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/habit_model.dart';
import '../../models/scheduler.dart';
import '../../providers/vault_provider.dart';
import '../theme.dart';
import '../../models/shared_types.dart';
import '../../models/reminder_config.dart';
import 'scheduler_picker.dart';
import '../widgets/wiki_link_controller.dart';
import '../widgets/organizer_selector_field.dart';
import '../widgets/time_block_picker.dart';

class CreateHabitForm extends ConsumerStatefulWidget {
  final String? initialTitle;
  final Habit? existingHabit;
  final String? initialTimeBlock;
  const CreateHabitForm({
    super.key,
    this.initialTitle,
    this.existingHabit,
    this.initialTimeBlock,
  });

  @override
  ConsumerState<CreateHabitForm> createState() => _CreateHabitFormState();
}

class _CreateHabitFormState extends ConsumerState<CreateHabitForm> {
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  String _completionUnit = 'times';
  int _dailyGoal = 1;
  int _slots = 1;
  String _selectedColor = '#6366F1';
  List<Scheduler> _schedulers = [];
  bool _isNegative = false;
  String? _linkedTrackerSlug;
  String _goalType = 'successful_days';
  HabitStatus _status = HabitStatus.active;
  final List<HabitSlot> _slotConfigs = List.generate(10, (_) => HabitSlot());
  HabitInputType _inputType = HabitInputType.boolean;
  List<ActionDef> _actions = [];
  List<OrganizerReference> _organizers = [];
  String? _timeBlock;

  // Pact fields
  HabitMode _habitMode = HabitMode.habit;
  late final TextEditingController _statementController;
  late final TextEditingController _curiosityController;
  late final TextEditingController _hypothesisController;
  int _pactDurationDays = 30;
  DateTime? _startedAt;
  DateTime? _endsAt;
  PactOutcome? _pactOutcome;
  List<PactCycle> _previousCycles = [];

  static const _colorSwatches = [
    '#DC2626',
    '#F97316',
    '#F59E0B',
    '#22C55E',
    '#14B8A6',
    '#3B82F6',
    '#6366F1',
    '#8B5CF6',
    '#EC4899',
    '#6B7280',
  ];

  @override
  void initState() {
    super.initState();
    _titleController = WikiLinkTextController(
      context: context,
      text: widget.existingHabit?.title ?? widget.initialTitle,
    );
    _descController = WikiLinkTextController(
      context: context,
      text: widget.existingHabit?.description ?? '',
    );
    _statementController = WikiLinkTextController(
      context: context,
      text: widget.existingHabit?.statement ?? '',
    );
    _curiosityController = WikiLinkTextController(
      context: context,
      text: widget.existingHabit?.curiosityQuestion ?? '',
    );
    _hypothesisController = WikiLinkTextController(
      context: context,
      text: widget.existingHabit?.hypothesis ?? '',
    );

    if (widget.existingHabit != null) {
      final habit = widget.existingHabit!;
      _selectedColor = habit.color;
      _completionUnit = habit.completionUnit;
      _dailyGoal = habit.dailyGoal;
      _slots = habit.slots.isNotEmpty ? habit.slots.length : 1;
      _isNegative = habit.isNegative;
      _inputType = habit.inputType;
      _actions = List.from(habit.actions);
      _schedulers = List.from(habit.schedulers);
      _organizers = List.from(habit.organizers);
      _timeBlock = habit.timeBlock;

      _habitMode = habit.habitMode;
      _startedAt = habit.startedAt;
      _endsAt = habit.endsAt;
      _pactOutcome = habit.pactOutcome;
      _previousCycles = List.from(habit.previousCycles);
      if (habit.startedAt != null && habit.endsAt != null) {
        _pactDurationDays = habit.endsAt!.difference(habit.startedAt!).inDays;
      }

      for (int i = 0; i < habit.slots.length && i < _slotConfigs.length; i++) {
        _slotConfigs[i] = habit.slots[i];
      }
    } else {
      _timeBlock = widget.initialTimeBlock;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _statementController.dispose();
    _curiosityController.dispose();
    _hypothesisController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _canSave;
    final isDirty = _titleController.text.trim().isNotEmpty;

    return PopScope(
      canPop: !isDirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final discard = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Descartar alterações?'),
            content: const Text('Você possui alterações não salvas. Deseja sair mesmo assim?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: const Text('Descartar'),
              ),
            ],
          ),
        );
        if ((discard ?? false) && context.mounted) {
          Navigator.pop(context, result);
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              leading: IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.maybePop(context),
              ),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.existingHabit != null ? 'Edit Habit' : 'New Habit',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                _buildStatusBadge(),
              ],
            ),
            centerTitle: true,
            actions: [
              if (widget.existingHabit != null)
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.priorityHigh,
                  ),
                  onPressed: _deleteHabit,
                ),
              IconButton(
                icon: const Icon(Icons.check_rounded, color: AppColors.primary),
                onPressed: canSave ? _saveHabit : null,
              ),
              const SizedBox(width: 8),
            ],
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── Title ───
                  TextField(
                    controller: _titleController,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Habit title',
                      hintStyle: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                        letterSpacing: -0.5,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ─── Mode Selector (Hábito vs Pacto) ───
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _habitMode = HabitMode.habit),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _habitMode == HabitMode.habit
                                  ? AppColors.primary
                                  : AppTheme.cardFillColor(context),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _habitMode == HabitMode.habit
                                    ? AppColors.primary
                                    : AppTheme.dividerColor(context),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'Hábito',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: _habitMode == HabitMode.habit
                                      ? Colors.white
                                      : AppTheme.textPrimaryColor(context),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _habitMode = HabitMode.pact),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _habitMode == HabitMode.pact
                                  ? AppColors.primary
                                  : AppTheme.cardFillColor(context),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _habitMode == HabitMode.pact
                                    ? AppColors.primary
                                    : AppTheme.dividerColor(context),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'Pacto (Pact)',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: _habitMode == HabitMode.pact
                                      ? Colors.white
                                      : AppTheme.textPrimaryColor(context),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (_habitMode == HabitMode.pact) ...[
                    Container(
                      decoration: AppTheme.cardDecoration(context),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CAMPOS DO PACTO',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textMutedColor(context),
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Statement
                          TextField(
                            controller: _statementController,
                            decoration: const InputDecoration(
                              labelText: 'Declaração (Ex: Escrever 100 palavras por dia)',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 12),
                          // Curiosity Question
                          TextField(
                            controller: _curiosityController,
                            decoration: const InputDecoration(
                              labelText: 'Pergunta de Curiosidade (Ex: O que acontece com a resistência?)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Hypothesis
                          TextField(
                            controller: _hypothesisController,
                            decoration: const InputDecoration(
                              labelText: 'Hipótese (Ex: Escrita diária vai reduzir a ansiedade)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Duration
                          Row(
                            children: [
                              const Text(
                                'Duração do Pacto (dias)',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                              const Spacer(),
                              _stepper(
                                _pactDurationDays,
                                1,
                                365,
                                (v) => setState(() => _pactDurationDays = v),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ─── Color Swatches ───
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _colorSwatches.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final hex = _colorSwatches[index];
                        final color = _parseColor(hex);
                        final selected = _selectedColor == hex;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedColor = hex),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(10),
                              border: selected
                                  ? Border.all(color: Colors.white, width: 3)
                                  : null,
                              boxShadow: selected
                                  ? [
                                      BoxShadow(
                                        color: color.withValues(alpha: 0.5),
                                        blurRadius: 8,
                                      ),
                                    ]
                                  : [],
                            ),
                            child: selected
                                ? const Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ─── Schedule Card ───
                  Container(
                    decoration: AppTheme.cardDecoration(context),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _propertyRow(
                          'Frequency',
                          _getScheduleSummary(),
                          AppColors.primary,
                          _pickSchedule,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ─── Input Type Card ───
                  Container(
                    decoration: AppTheme.cardDecoration(context),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Input Type',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildInputTypeSelector(),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ─── Negative Habit Toggle ───
                  Container(
                    decoration: AppTheme.cardDecoration(context),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Habit Quitting',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Count success by days without recording.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: _isNegative,
                          onChanged: (v) => setState(() => _isNegative = v),
                          activeThumbColor: AppColors.error,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ─── Completion Unit Card ───
                  Container(
                    decoration: AppTheme.cardDecoration(context),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Completion Unit',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'What counts as one completion',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: _pickUnit,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: AppTheme.chipDecoration(
                              AppColors.primary,
                            ),
                            child: Text(
                              _completionUnit,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ─── Slots & Goal Card ───
                  Container(
                    decoration: AppTheme.cardDecoration(context),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Slots',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.help_outline_rounded,
                              size: 14,
                              color: AppColors.textMuted,
                            ),
                            const Spacer(),
                            _stepper(
                              _slots,
                              1,
                              10,
                              (v) => setState(() => _slots = v),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        _propertyRow(
                          'Goal',
                          _getGoalLabel(),
                          AppColors.primary,
                          _pickGoalType,
                        ),
                        const Divider(height: 24),
                        OrganizerSelectorField(
                          selectedOrganizers: _organizers,
                          onChanged: (val) => setState(() => _organizers = val),
                        ),
                        const Divider(height: 24),
                        _propertyRow(
                          'Linked Tracker',
                          _linkedTrackerSlug ?? 'None',
                          AppColors.primary,
                          _pickTracker,
                        ),
                        const Divider(height: 24),
                        TimeBlockPicker(
                          selectedBlockId: _timeBlock,
                          onBlockSelected: (val) =>
                              setState(() => _timeBlock = val),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ─── Slots Detailed Card ───
                  Container(
                    decoration: AppTheme.cardDecoration(context),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Slot Configuration',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...List.generate(
                          _slots,
                          (index) => _buildSlotConfig(index),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  Container(
                    decoration: AppTheme.cardDecoration(context),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Actions',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: _showAddActionSheet,
                              icon: const Icon(
                                Icons.add_rounded,
                                size: 20,
                                color: AppColors.primary,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_actions.isEmpty)
                          const Text(
                            'No actions yet',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 13,
                            ),
                          )
                        else
                          ..._actions.map(
                            (action) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                action.type == 'add_entry'
                                    ? Icons.auto_stories_rounded
                                    : Icons.check_circle_outline,
                                size: 18,
                                color: AppColors.primary,
                              ),
                              title: Text(
                                action.type == 'add_entry'
                                    ? 'Add Journal Entry'
                                    : 'Create Task',
                                style: const TextStyle(fontSize: 14),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.close_rounded, size: 16),
                                onPressed: () =>
                                    setState(() => _actions.remove(action)),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ─── Description Card ───
                  Container(
                    decoration: AppTheme.cardDecoration(context),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Description',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _descController,
                          maxLines: 3,
                          style: const TextStyle(fontSize: 14),
                          decoration: const InputDecoration(
                            hintText: 'Description',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),

      // ─── Save Button ───
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: canSave ? _saveHabit : null,
              style: FilledButton.styleFrom(
                backgroundColor: _parseColor(_selectedColor),
                disabledBackgroundColor: AppColors.textMuted.withValues(
                  alpha: 0.2,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Add',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  }

  bool get _canSave =>
      _titleController.text.trim().isNotEmpty && _schedulers.isNotEmpty;

  Widget _propertyRow(
    String label,
    String value,
    Color valueColor,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: valueColor,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: AppColors.textMuted,
          ),
        ],
      ),
    );
  }

  Widget _stepper(int value, int min, int max, ValueChanged<int> onChanged) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: value > min ? () => onChanged(value - 1) : null,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.remove,
              size: 16,
              color: value > min ? AppColors.textPrimary : AppColors.textMuted,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            '$value',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        GestureDetector(
          onTap: value < max ? () => onChanged(value + 1) : null,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.add,
              size: 16,
              color: value < max ? AppColors.textPrimary : AppColors.textMuted,
            ),
          ),
        ),
      ],
    );
  }

  String _getScheduleSummary() {
    if (_schedulers.isEmpty) return 'No schedule';
    final s = _schedulers.first;
    if (s.rules.isEmpty) return 'No rules';
    final r = s.rules.first;
    switch (r.repeatType) {
      case RepeatType.numberOfDays:
        return 'Every ${r.interval} days';
      case RepeatType.daysOfWeek:
        return r.daysOfWeek?.join(', ') ?? 'Weekdays';
      case RepeatType.numberOfWeeks:
        return 'Every ${r.interval} weeks';
      case RepeatType.numberOfMonths:
        return 'Every ${r.interval} months';
      default:
        return 'Advanced';
    }
  }

  void _pickSchedule() async {
    final result = await showModalBottomSheet<Scheduler>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SchedulerPicker(
          initialScheduler: _schedulers.isNotEmpty ? _schedulers.first : null,
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _schedulers = [result];
      });
    }
  }

  Widget _buildSlotConfig(int index) {
    final slot = _slotConfigs[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Slot ${index + 1}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => _pickSlotTime(index),
                icon: const Icon(
                  Icons.access_time_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 12),
              Switch.adaptive(
                value: slot.reminderEnabled,
                onChanged: (v) => setState(() => slot.reminderEnabled = v),
                activeThumbColor: AppColors.primary,
              ),
            ],
          ),
          if (slot.reminderEnabled) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _pickReminderDetails(index),
              child: Row(
                children: [
                  Icon(
                    slot.notificationType == NotificationType.alarm
                        ? Icons.alarm_rounded
                        : (slot.notificationType == NotificationType.popup
                              ? Icons.picture_in_picture_rounded
                              : Icons.notifications_active_outlined),
                    size: 14,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    slot.reminderTime != null
                        ? '${slot.reminderTime!.format(context)} • ${slot.notificationType.name.toUpperCase()}'
                        : 'Tap to set time \u0026 alert type',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.flash_on_rounded,
                  size: 14,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 8),
                Text(
                  slot.actions.isNotEmpty
                      ? '${slot.actions.length} action(s)'
                      : 'No actions set',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => _showAddActionSheetForSlot(index),
                  child: const Text(
                    'Set action',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _pickReminderDetails(int index) {
    final slot = _slotConfigs[index];
    TimeOfDay? tempTime =
        slot.reminderTime ?? const TimeOfDay(hour: 8, minute: 0);
    NotificationType tempType = slot.notificationType;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Slot Reminder',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Time', style: TextStyle(fontSize: 14)),
                      TextButton.icon(
                        icon: const Icon(Icons.access_time),
                        label: Text(tempTime!.format(context)),
                        onPressed: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: tempTime!,
                          );
                          if (time != null) {
                            setModalState(() => tempTime = time);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Notification Type',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: NotificationType.values.map((type) {
                      final isSelected = tempType == type;
                      return ChoiceChip(
                        label: Text(type.name.toUpperCase()),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setModalState(() => tempType = type);
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          slot.reminderTime = tempTime;
                          slot.notificationType = tempType;
                        });
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Save Reminder'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusBadge() {
    return GestureDetector(
      onTap: _pickStatus,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _getStatusColor().withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _getStatusColor().withValues(alpha: 0.3)),
        ),
        child: Text(
          _status.name.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: _getStatusColor(),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor() {
    switch (_status) {
      case HabitStatus.active:
        return AppColors.primary;
      case HabitStatus.paused:
        return AppColors.warning;
      case HabitStatus.completed:
        return AppColors.habitGreen;
    }
  }

  void _pickStatus() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: HabitStatus.values
              .map(
                (s) => ListTile(
                  title: Text(s.name.toUpperCase()),
                  trailing: _status == s
                      ? const Icon(Icons.check, color: AppColors.primary)
                      : null,
                  onTap: () {
                    setState(() => _status = s);
                    Navigator.pop(ctx);
                  },
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  String _getGoalLabel() {
    switch (_goalType) {
      case 'none':
        return 'None';
      case 'date':
        return 'Target Date';
      case 'successful_days':
        return 'Successful Days';
      case 'completion_count':
        return 'Completion Count';
      case 'streak':
        return 'Streak';
      default:
        return 'Successful Days';
    }
  }

  void _pickGoalType() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children:
              ['none', 'date', 'successful_days', 'completion_count', 'streak']
                  .map(
                    (g) => ListTile(
                      title: Text(g),
                      trailing: _goalType == g
                          ? const Icon(Icons.check, color: AppColors.primary)
                          : null,
                      onTap: () {
                        setState(() => _goalType = g);
                        Navigator.pop(ctx);
                      },
                    ),
                  )
                  .toList(),
        ),
      ),
    );
  }

  void _pickSlotTime(int index) async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time != null) {
      setState(() {
        _slotConfigs[index].reminderTime = time;
        _slotConfigs[index].reminderEnabled = true;
      });
    }
  }

  void _pickTracker() async {
    final allObjects = await ref.read(allObjectsProvider.future);
    final trackers = allObjects.where((o) => o.type == 'tracker').toList();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('None'),
              trailing: _linkedTrackerSlug == null
                  ? const Icon(Icons.check, color: AppColors.primary)
                  : null,
              onTap: () {
                setState(() => _linkedTrackerSlug = null);
                Navigator.pop(ctx);
              },
            ),
            ...trackers.map(
              (t) => ListTile(
                title: Text(t.title),
                trailing: _linkedTrackerSlug == t.slug
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  setState(() => _linkedTrackerSlug = t.slug);
                  Navigator.pop(ctx);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _pickUnit() {
    final controller = TextEditingController(text: _completionUnit);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final options = [
          'times',
          'glasses',
          'minutes',
          'pages',
          'workouts',
          'reps',
          'steps',
        ];
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textMuted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Completion Unit',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: 'Custom unit...',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.check, color: AppColors.primary),
                        onPressed: () {
                          if (controller.text.trim().isNotEmpty) {
                            setState(
                              () => _completionUnit = controller.text.trim(),
                            );
                            Navigator.pop(ctx);
                          }
                        },
                      ),
                    ),
                    onSubmitted: (val) {
                      if (val.trim().isNotEmpty) {
                        setState(() => _completionUnit = val.trim());
                        Navigator.pop(ctx);
                      }
                    },
                  ),
                ),
                ...options.map(
                  (opt) => ListTile(
                    title: Text(opt, style: const TextStyle(fontSize: 15)),
                    trailing: _completionUnit == opt
                        ? const Icon(
                            Icons.check_rounded,
                            color: AppColors.primary,
                          )
                        : null,
                    onTap: () {
                      setState(() => _completionUnit = opt);
                      Navigator.pop(ctx);
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveHabit() async {
    final habit = Habit(
      id:
          widget.existingHabit?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      createdAt: widget.existingHabit?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      obsidianPath: widget.existingHabit?.obsidianPath ?? '',
      title: _titleController.text.trim(),
      color: _selectedColor,
      completionUnit: _completionUnit,
      dailyGoal: _dailyGoal,
      slots: _slotConfigs.take(_slots).toList(),
      description: _descController.text.trim(),
      isNegative: _isNegative,
      inputType: _inputType,
      actions: _actions,
      schedulers: _schedulers,
      organizers: _organizers,
      timeBlock: _timeBlock,
      // Pact fields
      habitMode: _habitMode,
      statement: _habitMode == HabitMode.pact ? _statementController.text.trim() : null,
      curiosityQuestion: _habitMode == HabitMode.pact ? _curiosityController.text.trim() : null,
      hypothesis: _habitMode == HabitMode.pact ? _hypothesisController.text.trim() : null,
      startedAt: _habitMode == HabitMode.pact
          ? (_startedAt ?? DateTime.now())
          : null,
      endsAt: _habitMode == HabitMode.pact
          ? (_startedAt ?? DateTime.now()).add(Duration(days: _pactDurationDays))
          : null,
      pactOutcome: _habitMode == HabitMode.pact ? _pactOutcome : null,
      previousCycles: _previousCycles,
      isFlexibleFrequency: _schedulers.isNotEmpty && 
          _schedulers.first.rules.isNotEmpty && 
          _schedulers.first.rules.first.repeatType == RepeatType.numberOfDaysPerPeriod,
      frequencyDays: _schedulers.isNotEmpty && 
              _schedulers.first.rules.isNotEmpty && 
              _schedulers.first.rules.first.repeatType == RepeatType.numberOfDaysPerPeriod
          ? (_schedulers.first.rules.first.period == 'week' 
              ? 7 
              : (_schedulers.first.rules.first.period == 'month' ? 30 : 365))
          : null,
    );
    try {
      if (widget.existingHabit != null) {
        await ref.read(vaultProvider.notifier).updateObject(habit);
      } else {
        await ref.read(habitsProvider.notifier).addHabit(habit);
      }
    } catch (e) {
      debugPrint('Failed to save habit: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao salvar hábito: $e')));
      return;
    }
    if (mounted) Navigator.pop(context);
  }

  void _deleteHabit() {
    if (widget.existingHabit == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Habit'),
        content: Text(
          'Are you sure you want to delete "${widget.existingHabit!.title}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              ref
                  .read(habitsProvider.notifier)
                  .deleteHabit(widget.existingHabit!);
              Navigator.pop(ctx); // Close dialog
              Navigator.pop(context); // Close form
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.priorityHigh,
            ),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }

  void _showAddActionSheetForSlot(int slotIndex) {
    _buildActionPickerSheet((action) {
      setState(() => _slotConfigs[slotIndex].actions.add(action));
    });
  }

  void _showAddActionSheet() {
    _buildActionPickerSheet((action) {
      setState(() => _actions.add(action));
    });
  }

  void _buildActionPickerSheet(Function(ActionDef) onSelect) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              const Text(
                'Add Action',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(
                  Icons.auto_stories_rounded,
                  color: AppColors.habitPurple,
                ),
                title: const Text('Add Journal Entry'),
                onTap: () {
                  onSelect(
                    ActionDef(type: 'add_entry', trigger: 'day_complete'),
                  );
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.check_circle_outline,
                  color: AppColors.info,
                ),
                title: const Text('Create Follow-up Task'),
                onTap: () {
                  onSelect(
                    ActionDef(type: 'create_task', trigger: 'day_complete'),
                  );
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.bar_chart_rounded,
                  color: AppColors.primary,
                ),
                title: const Text('Add Tracking Record'),
                onTap: () {
                  onSelect(
                    ActionDef(
                      type: 'add_tracking_record',
                      trigger: 'day_complete',
                    ),
                  );
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.note_add_rounded,
                  color: AppColors.habitGreen,
                ),
                title: const Text('Add Text Note'),
                onTap: () {
                  onSelect(
                    ActionDef(type: 'add_text_note', trigger: 'day_complete'),
                  );
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.library_books_rounded,
                  color: AppColors.priorityHigh,
                ),
                title: const Text('Add Collection Item'),
                onTap: () {
                  onSelect(
                    ActionDef(
                      type: 'add_collection_item',
                      trigger: 'day_complete',
                    ),
                  );
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.link_rounded,
                  color: AppColors.textSecondary,
                ),
                title: const Text('Launch URL'),
                onTap: () {
                  onSelect(
                    ActionDef(type: 'launch_url', trigger: 'day_complete'),
                  );
                  Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputTypeSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: HabitInputType.values.map((type) {
          final selected = _inputType == type;
          return GestureDetector(
            onTap: () => setState(() => _inputType = type),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    _getInputTypeIcon(type),
                    size: 18,
                    color: selected ? Colors.white : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _getInputTypeLabel(type),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : AppColors.textSecondary,
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

  IconData _getInputTypeIcon(HabitInputType type) {
    switch (type) {
      case HabitInputType.boolean:
        return Icons.check_circle_outline_rounded;
      case HabitInputType.numeric:
        return Icons.pin_rounded;
      case HabitInputType.mood:
        return Icons.mood_rounded;
      case HabitInputType.duration:
        return Icons.timer_outlined;
    }
  }

  String _getInputTypeLabel(HabitInputType type) {
    switch (type) {
      case HabitInputType.boolean:
        return 'Yes/No';
      case HabitInputType.numeric:
        return 'Numeric';
      case HabitInputType.mood:
        return 'Mood';
      case HabitInputType.duration:
        return 'Duration';
    }
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceAll('#', '0xFF')));
    } catch (_) {
      return AppColors.primary;
    }
  }
}

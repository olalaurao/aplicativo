// lib/ui/widgets/triple_check_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/task_model.dart';
import '../../providers/vault_provider.dart';
import '../forms/create_task_form.dart';
import '../theme.dart';
import 'universal_search_picker.dart';

/// Shows the Triple Check bottom sheet for a Task.
/// Can be opened from the ⋯ menu, or from the ⚠️ badge on a stuck task.
Future<void> showTripleCheckSheet(
  BuildContext context,
  WidgetRef ref, // kept for API compatibility but not forwarded
  Task task, {
  bool readOnly = false,
  List<Task>? batchQueue,
}) async {
  HapticFeedback.mediumImpact();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: readOnly,
    enableDrag: readOnly,
    backgroundColor: Colors.transparent,
    builder: (_) => TripleCheckSheet(
      task: task,
      readOnly: readOnly,
      batchQueue: batchQueue,
    ),
  );
}

class TripleCheckSheet extends ConsumerStatefulWidget {
  final Task task;
  final bool readOnly;
  final List<Task>? batchQueue;

  const TripleCheckSheet({
    super.key,
    required this.task,
    this.readOnly = false,
    this.batchQueue,
  });

  @override
  ConsumerState<TripleCheckSheet> createState() => _TripleCheckSheetState();
}

class _TripleCheckSheetState extends ConsumerState<TripleCheckSheet>
    with SingleTickerProviderStateMixin {
  // Current answers — default to "yes" if a previous check existed, else null
  TripleCheckAnswer? _head;
  TripleCheckAnswer? _heart;
  TripleCheckAnswer? _hand;

  bool _saved = false;
  bool _editingExistingCheck = false;
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -4), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -4, end: 4), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 4, end: -4), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -4, end: 0), weight: 1),
    ]).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut),
    );
    // Pre-fill if there is an existing check result
    final prev = widget.task.tripleCheck;
    if (prev != null) {
      _head = prev.head;
      _heart = prev.heart;
      _hand = prev.hand;
    }
    _editingExistingCheck = !widget.readOnly;
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  bool get _canClose => _saved || (widget.readOnly && !_editingExistingCheck);

  // ── Diagnosis logic ───────────────────────────────────────────────────────

  String _buildDiagnosis() {
    if (_head == null || _heart == null || _hand == null) return '';

    final headBlocked = _head != TripleCheckAnswer.yes;
    final heartBlocked = _heart != TripleCheckAnswer.yes;
    final handBlocked = _hand != TripleCheckAnswer.yes;

    if (!headBlocked && !heartBlocked && !handBlocked) {
      return 'All green! The blockage may be external. Check dependencies and schedule.';
    }
    if (headBlocked) {
      return 'The task may not make sense now. Reformulate or archive?';
    }
    if (heartBlocked) {
      return 'The blockage is emotional. Try pairing with something enjoyable, changing environment, or breaking into smaller parts.';
    }
    // handBlocked
    return 'Missing resource or clarity. What do you need before starting?';
  }

  IconData _diagnosisIcon() {
    if (_head == null || _heart == null || _hand == null) {
      return Icons.help_outline;
    }
    final headBlocked = _head != TripleCheckAnswer.yes;
    final heartBlocked = _heart != TripleCheckAnswer.yes;
    final handBlocked = _hand != TripleCheckAnswer.yes;

    if (!headBlocked && !heartBlocked && !handBlocked) {
      return Icons.check_circle_outline;
    }
    if (headBlocked) return Icons.psychology_outlined;
    if (heartBlocked) return Icons.favorite_border_rounded;
    return Icons.build_outlined;
  }

  Color _diagnosisColor() {
    if (_head == null || _heart == null || _hand == null) {
      return AppColors.textMuted;
    }
    final allGood =
        _head == TripleCheckAnswer.yes &&
        _heart == TripleCheckAnswer.yes &&
        _hand == TripleCheckAnswer.yes;
    if (allGood) return AppColors.success;
    if (_head != TripleCheckAnswer.yes) return AppColors.info;
    if (_heart != TripleCheckAnswer.yes) return AppColors.warning;
    return AppTheme.accentColor(context);
  }

  // ── Save ─────────────────────────────────────────────────────────────────

  Future<void> _autoSavePartialState() async {
    // Auto-save partial state before navigation (F2.4)
    if (_head != null && _heart != null && _hand != null && !_saved) {
      await _save();
    }
  }

  Future<void> _save() async {
    if (_head == null || _heart == null || _hand == null) return;
    if (widget.readOnly && !_editingExistingCheck) return;
    HapticFeedback.lightImpact();

    final diagnosis = _buildDiagnosis();
    final tc = TripleCheck(
      head: _head!,
      heart: _heart!,
      hand: _hand!,
      diagnosis: diagnosis,
      checkedAt: DateTime.now(),
    );

    final updated = widget.task.copyWith(tripleCheck: tc);
    await ref.read(vaultProvider.notifier).updateObject(updated);

    if (!mounted) return;
    setState(() => _saved = true);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Diagnosis saved.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // ── Action buttons per blocker ────────────────────────────────────────────

  List<Widget> _buildActionButtons() {
    if (_head == null || _heart == null || _hand == null) return [];

    final headBlocked = _head != TripleCheckAnswer.yes;
    final heartBlocked = _heart != TripleCheckAnswer.yes;
    final handBlocked = _hand != TripleCheckAnswer.yes;
    final allGood = !headBlocked && !heartBlocked && !handBlocked;

    if (allGood) {
      return [
        _ActionButton(
          label: 'View dependencies',
          icon: Icons.link_off_rounded,
          onTap: () {
            _openViewDependencies();
          },
        ),
        _ActionButton(
          label: 'View schedule',
          icon: Icons.calendar_today_rounded,
          color: AppColors.textSecondary,
          onTap: () {
            _openCheckSchedule();
          },
        ),
      ];
    }

    if (headBlocked) {
      return [
        _ActionButton(
          label: 'Reformulate',
          icon: Icons.edit_note_rounded,
          onTap: () {
            _openEditTask();
          },
        ),
        _ActionButton(
          label: 'Archive',
          icon: Icons.archive_outlined,
          color: AppColors.textSecondary,
          onTap: () async {
            Navigator.pop(context);
            final messenger = ScaffoldMessenger.of(context);
            final archived = widget.task.copyWith(archived: true);
            await ref.read(vaultProvider.notifier).updateObject(archived);
            messenger.showSnackBar(
              const SnackBar(content: Text('Task archived.')),
            );
          },
        ),
      ];
    }

    if (heartBlocked) {
      return [
        _ActionButton(
          label: 'Create subtasks',
          icon: Icons.account_tree_outlined,
          onTap: () {
            _openCreateSubtask();
          },
        ),
        _ActionButton(
          label: 'Postpone',
          icon: Icons.schedule_rounded,
          color: AppColors.textSecondary,
          onTap: () async {
            _showPostponeOptions();
          },
        ),
      ];
    }

    // handBlocked
    return [
      _ActionButton(
        label: 'Add dependency',
        icon: Icons.link_rounded,
        onTap: () {
          _openDependencyPicker();
        },
      ),
      _ActionButton(
        label: 'Pediajajuda',
        icon: Icons.person_add_alt_1_outlined,
        color: AppColors.textSecondary,
        onTap: () async {
          _openWhatsAppHelp();
        },
      ),
    ];
  }

  void _openCreateSubtask() async {
    // Auto-save partial state before navigation (F2.4)
    await _autoSavePartialState();
    // TODO: Implement create subtask form pre-focused and parented to this Task
    // For now, open edit task as placeholder
    _openEditTask();
  }

  void _showPostponeOptions() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Postpone Task', style: TextStyle(fontSize: AppTextSize.xl, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                _PostponeChip(
                  label: '+1 day',
                  onTap: () => _postponeTask(1),
                ),
                _PostponeChip(
                  label: '+1 week',
                  onTap: () => _postponeTask(7),
                ),
                _PostponeChip(
                  label: '+1 month',
                  onTap: () => _postponeTask(30),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _openDatePicker();
              },
              child: const Text('Choose date...'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _postponeTask(int days) async {
    Navigator.pop(context);
    final messenger = ScaffoldMessenger.of(context);
    final newDate = DateTime.now().add(Duration(days: days));
    final snoozed = widget.task.copyWith(startDate: newDate);
    await ref.read(vaultProvider.notifier).updateObject(snoozed);
    messenger.showSnackBar(
      SnackBar(content: Text('Task postponed by $days days.')),
    );
  }

  void _openDatePicker() {
    // TODO: Implement date picker for custom postpone date
    // For now, use +1 day as placeholder
    _postponeTask(1);
  }

  void _openDependencyPicker() async {
    // Auto-save partial state before navigation (F2.4)
    await _autoSavePartialState();
    
    // F3.5: Use Universal Search Picker with "Create new task" pinned option
    if (!mounted) return;
    final navigator = Navigator.of(context);
    navigator.pop();
    
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => UniversalSearchPickerSheet(
          title: 'Add dependency',
          initialFilter: 'task',
          onSelected: (selectedObject) async {
            Navigator.pop(sheetContext);
            if (selectedObject is Task) {
              // Add as dependency
              final currentDeps = widget.task.dependsOn;
              if (!currentDeps.contains(selectedObject.id)) {
                final updated = widget.task.copyWith(
                  dependsOn: [...currentDeps, selectedObject.id],
                );
                await ref.read(vaultProvider.notifier).updateObject(updated);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Dependency "${selectedObject.title}" added.')),
                  );
                }
              }
            }
          },
        ),
      );
    });
  }

  void _openWhatsAppHelp() async {
    // TODO: Launch URL using url_launcher
    // For now, add note as placeholder
    final messenger = ScaffoldMessenger.of(context);
    final notes = [...widget.task.notes];
    if (!notes.any((note) => note.contains('Ask for help'))) {
      notes.add('Ask for help: identify person or resource needed.');
    }
    final updated = widget.task.copyWith(notes: notes);
    await ref.read(vaultProvider.notifier).updateObject(updated);
    if (!mounted) return;
    Navigator.pop(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Task marked for asking help.')),
    );
  }

  void _openViewDependencies() async {
    // Show dependencies in a dialog
    if (widget.task.dependsOn.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This task has no dependencies.')),
      );
      return;
    }
    
    final allObjects = ref.read(allObjectsProvider).value ?? [];
    final dependencies = allObjects.whereType<Task>()
        .where((t) => widget.task.dependsOn.contains(t.id))
        .toList();
    
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dependencies'),
        content: dependencies.isEmpty
            ? const Text('No matching tasks found.')
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: dependencies.map((dep) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text('• ${dep.title}'),
                )).toList(),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _openCheckSchedule() async {
    // Navigate to planner with the task's date
    await _autoSavePartialState();
    Navigator.of(context).pop();
    
    final targetDate = widget.task.startDate ?? widget.task.endDate ?? DateTime.now();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      context.push('/planner', extra: {'initialDate': targetDate});
    });
  }

  void _openEditTask() async {
    // Auto-save partial state before navigation (F2.4)
    await _autoSavePartialState();
    Navigator.of(context).pop();
    Future.delayed(const Duration(milliseconds: 200), () {
      context.push('/create-task', extra: {'existingTask': widget.task});
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final diagnosisText = _buildDiagnosis();
    final isComplete = _head != null && _heart != null && _hand != null;

    return PopScope<void>(
      canPop: _canClose,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        HapticFeedback.lightImpact();
        _shakeController.forward(from: 0);
      },
      child: DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.5,
        maxChildSize: 0.92,
        builder: (_, controller) => AnimatedBuilder(
          animation: _shakeAnimation,
          builder: (context, child) => Transform.translate(
            offset: Offset(_shakeAnimation.value, 0),
            child: child,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
            children: [
              // Handle pill
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  children: [
                    // Title row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.troubleshoot_rounded,
                            color: AppColors.warning,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.batchQueue == null
                                    ? 'Triple Check'
                                    : 'Triple Check ${widget.batchQueue!.indexWhere((t) => t.id == widget.task.id) + 1} de ${widget.batchQueue!.length}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimaryColor(context),
                                ),
                              ),
                              Text(
                                widget.task.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondaryColor(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Question 1 — Head
                    _QuestionRow(
                      emoji: '🧠',
                      question: 'Does the task make sense now?',
                      current: _head,
                      enabled: !widget.readOnly || _editingExistingCheck,
                      onChanged: (v) => setState(() => _head = v),
                    ),
                    const SizedBox(height: 16),

                    // Question 2 — Heart
                    _QuestionRow(
                      emoji: '❤️',
                      question: 'Are you excited about this?',
                      current: _heart,
                      enabled: !widget.readOnly || _editingExistingCheck,
                      onChanged: (v) => setState(() => _heart = v),
                    ),
                    const SizedBox(height: 16),

                    // Question 3 — Hand
                    _QuestionRow(
                      emoji: '🖐',
                      question: 'Do you have what you need to start?',
                      current: _hand,
                      enabled: !widget.readOnly || _editingExistingCheck,
                      onChanged: (v) => setState(() => _hand = v),
                    ),
                    const SizedBox(height: 24),

                    // Diagnosis card (real-time)
                    if (isComplete) ...[
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _diagnosisColor().withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _diagnosisColor().withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              _diagnosisIcon(),
                              color: _diagnosisColor(),
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                diagnosisText,
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.5,
                                  color: _diagnosisColor(),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Action buttons
                      ..._buildActionButtons().map(
                        (btn) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: btn,
                        ),
                      ),
                      if (_buildActionButtons().isNotEmpty)
                        const SizedBox(height: 8),
                    ],

                    // Save button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            isComplete &&
                                (!widget.readOnly || _editingExistingCheck)
                            ? _save
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentColor(context),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppColors.divider,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: Text(
                          widget.readOnly && !_editingExistingCheck
                              ? 'Diagnosis saved'
                              : 'Save diagnosis',
                        ),
                      ),
                    ),

                    if (widget.readOnly && !_editingExistingCheck) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            Future<void>.delayed(
                              const Duration(milliseconds: 180),
                              () {
                                if (context.mounted) {
                                  showTripleCheckSheet(context, ref, widget.task);
                                }
                              },
                            );
                          },
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Re-run diagnosis'),
                        ),
                      ),
                    ],

                    // If there's a previous check, show "re-run" context
                    if (widget.task.tripleCheck != null && !_saved) ...[
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          'Previous diagnosis: ${_formatDate(widget.task.tripleCheck!.checkedAt)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMutedColor(context),
                          ),
                        ),
                      ),
                    ],
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

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt).inDays;
    if (diff == 0) return 'today';
    if (diff == 1) return 'yesterday';
    return '$diff days ago';
  }
}

class TripleCheckIconRow extends StatelessWidget {
  final TripleCheck tripleCheck;
  final VoidCallback? onTap;

  const TripleCheckIconRow({
    super.key,
    required this.tripleCheck,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final icons = <IconData>[
      if (tripleCheck.head != TripleCheckAnswer.yes)
        Icons.psychology_outlined,
      if (tripleCheck.heart != TripleCheckAnswer.yes)
        Icons.favorite_outline_rounded,
      if (tripleCheck.hand != TripleCheckAnswer.yes)
        Icons.back_hand_outlined,
    ];
    if (icons.isEmpty) {
      icons.add(Icons.check_circle_outline_rounded);
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final icon in icons) ...[
              Icon(icon, size: 14, color: AppColors.textMuted),
              if (icon != icons.last) const SizedBox(width: 2),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Answer selector row ───────────────────────────────────────────────────────

class _QuestionRow extends StatelessWidget {
  final String emoji;
  final String question;
  final TripleCheckAnswer? current;
  final bool enabled;
  final ValueChanged<TripleCheckAnswer> onChanged;

  const _QuestionRow({
    required this.emoji,
    required this.question,
    required this.current,
    this.enabled = true,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                question,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimaryColor(context),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _AnswerChip(
              label: 'Yes',
              value: TripleCheckAnswer.yes,
              current: current,
              activeColor: AppColors.success,
              onTap: enabled ? onChanged : null,
            ),
            const SizedBox(width: 8),
            _AnswerChip(
              label: 'Unsure',
              value: TripleCheckAnswer.unsure,
              current: current,
              activeColor: AppColors.warning,
              onTap: enabled ? onChanged : null,
            ),
            const SizedBox(width: 8),
            _AnswerChip(
              label: 'No',
              value: TripleCheckAnswer.no,
              current: current,
              activeColor: AppColors.error,
              onTap: enabled ? onChanged : null,
            ),
          ],
        ),
      ],
    );
  }
}

class _AnswerChip extends StatelessWidget {
  final String label;
  final TripleCheckAnswer value;
  final TripleCheckAnswer? current;
  final Color activeColor;
  final ValueChanged<TripleCheckAnswer>? onTap;

  const _AnswerChip({
    required this.label,
    required this.value,
    required this.current,
    required this.activeColor,
    required this.onTap,
  });

  bool get isSelected => current == value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: GestureDetector(
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.lightImpact();
                onTap!(value);
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? activeColor.withValues(alpha: 0.12)
                : (isDark ? AppColors.darkCardFill : AppColors.surfaceVariant),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? activeColor : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? activeColor
                    : AppTheme.textSecondaryColor(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Action button ─────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color? color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.accentColor(context);
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: c,
        side: BorderSide(color: c.withValues(alpha: 0.35)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        alignment: Alignment.centerLeft,
      ),
    );
  }
}

// ── Badge widget for task cards ───────────────────────────────────────────────

/// Small ⚠️ badge shown on task cards stuck for 7+ days without a Triple Check.
class TripleCheckBadge extends StatelessWidget {
  final VoidCallback? onTap;

  const TripleCheckBadge({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('⚠️', style: TextStyle(fontSize: 11)),
            SizedBox(width: 3),
            Text(
              'Triple Check',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.warning,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostponeChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PostponeChip({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCardFill : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.divider),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppTheme.textPrimaryColor(context),
          ),
        ),
      ),
    );
  }
}

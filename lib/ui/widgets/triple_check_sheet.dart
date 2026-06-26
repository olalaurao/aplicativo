// lib/ui/widgets/triple_check_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/task_model.dart';
import '../../providers/vault_provider.dart';
import '../forms/create_task_form.dart';
import '../theme.dart';

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

class _TripleCheckSheetState extends ConsumerState<TripleCheckSheet> {
  // Current answers — default to "yes" if a previous check existed, else null
  TripleCheckAnswer? _head;
  TripleCheckAnswer? _heart;
  TripleCheckAnswer? _hand;

  bool _saved = false;
  bool _editingExistingCheck = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill if there is an existing check result
    final prev = widget.task.tripleCheck;
    if (prev != null) {
      _head = prev.head;
      _heart = prev.heart;
      _hand = prev.hand;
    }
    _editingExistingCheck = !widget.readOnly;
  }

  bool get _isDirty =>
      !_saved &&
      _editingExistingCheck &&
      (_head != null || _heart != null || _hand != null);

  // ── Diagnosis logic ───────────────────────────────────────────────────────

  String _buildDiagnosis() {
    if (_head == null || _heart == null || _hand == null) return '';

    final headBlocked = _head != TripleCheckAnswer.yes;
    final heartBlocked = _heart != TripleCheckAnswer.yes;
    final handBlocked = _hand != TripleCheckAnswer.yes;

    if (!headBlocked && !heartBlocked && !handBlocked) {
      return 'Tudo verde! O bloqueio pode ser externo. Verifique dependências e agenda.';
    }
    if (headBlocked) {
      return 'A tarefa pode não fazer sentido agora. Reformular ou arquivar?';
    }
    if (heartBlocked) {
      return 'O bloqueio é emocional. Tente parear com algo prazeroso, mudar de ambiente, ou quebrar em partes menores.';
    }
    // handBlocked
    return 'Falta recurso ou clareza. O que você precisa antes de começar?';
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
    return AppColors.primary;
  }

  // ── Save ─────────────────────────────────────────────────────────────────

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
    await ref.read(tasksProvider.notifier).updateTask(updated);

    if (!mounted) return;
    setState(() => _saved = true);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Diagnóstico salvo.'),
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

    if (allGood) return [];

    if (headBlocked) {
      return [
        _ActionButton(
          label: 'Reformular',
          icon: Icons.edit_note_rounded,
          onTap: () {
            _openEditTask();
          },
        ),
        _ActionButton(
          label: 'Arquivar',
          icon: Icons.archive_outlined,
          color: AppColors.textSecondary,
          onTap: () async {
            Navigator.pop(context);
            final messenger = ScaffoldMessenger.of(context);
            final archived = widget.task.copyWith(archived: true);
            await ref.read(tasksProvider.notifier).updateTask(archived);
            messenger.showSnackBar(
              const SnackBar(content: Text('Tarefa arquivada.')),
            );
          },
        ),
      ];
    }

    if (heartBlocked) {
      return [
        _ActionButton(
          label: 'Criar subtarefas',
          icon: Icons.account_tree_outlined,
          onTap: () {
            _openEditTask();
          },
        ),
        _ActionButton(
          label: 'Adiar',
          icon: Icons.schedule_rounded,
          color: AppColors.textSecondary,
          onTap: () async {
            // Push start date by 1 day
            Navigator.pop(context);
            final messenger = ScaffoldMessenger.of(context);
            final tomorrow = DateTime.now().add(const Duration(days: 1));
            final snoozed = widget.task.copyWith(startDate: tomorrow);
            await ref.read(tasksProvider.notifier).updateTask(snoozed);
            messenger.showSnackBar(
              const SnackBar(content: Text('Tarefa adiada para amanhã.')),
            );
          },
        ),
      ];
    }

    // handBlocked
    return [
      _ActionButton(
        label: 'Adicionar dependência',
        icon: Icons.link_rounded,
        onTap: () {
          _openEditTask();
        },
      ),
      _ActionButton(
        label: 'Pedir ajuda',
        icon: Icons.person_add_alt_1_outlined,
        color: AppColors.textSecondary,
        onTap: () async {
          final messenger = ScaffoldMessenger.of(context);
          final notes = [...widget.task.notes];
          if (!notes.any((note) => note.contains('Pedir ajuda'))) {
            notes.add('Pedir ajuda: identificar pessoa ou recurso necessário.');
          }
          final updated = widget.task.copyWith(notes: notes);
          await ref.read(tasksProvider.notifier).updateTask(updated);
          if (!mounted) return;
          Navigator.pop(context);
          messenger.showSnackBar(
            const SnackBar(content: Text('Tarefa marcada para pedir ajuda.')),
          );
        },
      ),
    ];
  }

  void _openEditTask() {
    final navigator = Navigator.of(context);
    navigator.pop();
    Future.delayed(const Duration(milliseconds: 200), () {
      navigator.push(
        MaterialPageRoute(
          builder: (_) => CreateTaskForm(existingTask: widget.task),
        ),
      );
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final diagnosisText = _buildDiagnosis();
    final isComplete = _head != null && _heart != null && _hand != null;

    return PopScope<void>(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Salve o diagnóstico antes de fechar.')),
        );
      },
      child: DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.5,
        maxChildSize: 0.92,
        builder: (_, controller) => Container(
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
                      question: 'A tarefa faz sentido agora?',
                      current: _head,
                      enabled: !widget.readOnly || _editingExistingCheck,
                      onChanged: (v) => setState(() => _head = v),
                    ),
                    const SizedBox(height: 16),

                    // Question 2 — Heart
                    _QuestionRow(
                      emoji: '❤️',
                      question: 'Você está animado com isso?',
                      current: _heart,
                      enabled: !widget.readOnly || _editingExistingCheck,
                      onChanged: (v) => setState(() => _heart = v),
                    ),
                    const SizedBox(height: 16),

                    // Question 3 — Hand
                    _QuestionRow(
                      emoji: '🖐',
                      question: 'Você tem o que precisa para começar?',
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
                          backgroundColor: AppColors.primary,
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
                              ? 'Diagnóstico salvo'
                              : 'Salvar diagnóstico',
                        ),
                      ),
                    ),

                    if (widget.readOnly && !_editingExistingCheck) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => setState(() {
                            _editingExistingCheck = true;
                            _saved = false;
                          }),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Re-executar diagnóstico'),
                        ),
                      ),
                    ],

                    // If there's a previous check, show "re-run" context
                    if (widget.task.tripleCheck != null && !_saved) ...[
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          'Diagnóstico anterior: ${_formatDate(widget.task.tripleCheck!.checkedAt)}',
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
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt).inDays;
    if (diff == 0) return 'hoje';
    if (diff == 1) return 'ontem';
    return 'há $diff dias';
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
              label: 'Sim',
              value: TripleCheckAnswer.yes,
              current: current,
              activeColor: AppColors.success,
              onTap: enabled ? onChanged : null,
            ),
            const SizedBox(width: 8),
            _AnswerChip(
              label: 'Incerto',
              value: TripleCheckAnswer.unsure,
              current: current,
              activeColor: AppColors.warning,
              onTap: enabled ? onChanged : null,
            ),
            const SizedBox(width: 8),
            _AnswerChip(
              label: 'Não',
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
    final c = color ?? AppColors.primary;
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

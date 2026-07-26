// lib/ui/widgets/quick_capture_bar.dart
//
// Quick Capture Bar — Things+Todoist+TickTick hybrid quick-entry widget.
// Two render modes:
//   QuickCaptureBar.sheet(...)  — inside a modal bottom sheet (rounded top, drag handle)
//   QuickCaptureBar.inline(...) — slim Container for use in screen Column

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/task_model.dart';
import '../../models/shared_types.dart';
import '../../providers/vault_provider.dart';
import '../../services/nlp_task_parser.dart';
import '../theme.dart';
import '../widgets/nlp_chips.dart';
import '../widgets/create_menu_sheet.dart';
import '../widgets/organizer_selector_field.dart';

// ─── Public show function ────────────────────────────────────────────────────

void showQuickCapture(BuildContext context, {QuickCaptureType defaultType = QuickCaptureType.task}) {
  HapticFeedback.lightImpact();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => QuickCaptureBar.sheet(defaultType: defaultType),
  );
}

// ─── Type enum ───────────────────────────────────────────────────────────────

enum QuickCaptureType { task, event, habit, goal }

extension _QuickCaptureTypeExt on QuickCaptureType {
  String get label {
    switch (this) {
      case QuickCaptureType.task:
        return 'Task';
      case QuickCaptureType.event:
        return 'Event';
      case QuickCaptureType.habit:
        return 'Habit';
      case QuickCaptureType.goal:
        return 'Goal';
    }
  }

  String get hint {
    switch (this) {
      case QuickCaptureType.task:
        return 'Add a task…';
      case QuickCaptureType.event:
        return 'Add an event…';
      case QuickCaptureType.habit:
        return 'Add a habit…';
      case QuickCaptureType.goal:
        return 'Add a goal…';
    }
  }

  String get createRoute {
    switch (this) {
      case QuickCaptureType.task:
        return '/create/task';
      case QuickCaptureType.event:
        return '/create/event';
      case QuickCaptureType.habit:
        return '/create/habit';
      case QuickCaptureType.goal:
        return '/create/goal';
    }
  }

  bool get showPriority => this == QuickCaptureType.task;
  bool get showRecurrence => this == QuickCaptureType.task || this == QuickCaptureType.habit;
}

// ─── Widget ──────────────────────────────────────────────────────────────────

class QuickCaptureBar extends ConsumerStatefulWidget {
  final QuickCaptureType defaultType;
  final bool _isSheet;

  const QuickCaptureBar.sheet({
    super.key,
    this.defaultType = QuickCaptureType.task,
  }) : _isSheet = true;

  const QuickCaptureBar.inline({
    super.key,
    this.defaultType = QuickCaptureType.task,
  }) : _isSheet = false;

  @override
  ConsumerState<QuickCaptureBar> createState() => _QuickCaptureBarState();
}

class _QuickCaptureBarState extends ConsumerState<QuickCaptureBar> {
  late QuickCaptureType _selectedType;
  final TextEditingController _titleController = TextEditingController();
  final FocusNode _titleFocus = FocusNode();

  // Parsed NLP state
  ParsedNlpTask? _parsed;

  // Manually discarded NLP fields (per-field removals)
  bool _dateDiscarded = false;
  bool _timeDiscarded = false;
  bool _priorityDiscarded = false;
  bool _schedulerDiscarded = false;

  // Expand state
  bool _detailsExpanded = false;

  // Expanded-state pickers
  DateTime? _extraDate;
  TaskPriority _extraPriority = TaskPriority.none;
  List<OrganizerReference> _extraOrganizers = [];
  String _extraNotes = '';

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.defaultType;
    _titleController.addListener(_onTitleChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget._isSheet) _titleFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _titleController.removeListener(_onTitleChanged);
    _titleController.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  void _onTitleChanged() {
    // Reset discards when text changes substantially
    final parsed = NlpTaskParser.parse(_titleController.text);
    setState(() {
      _parsed = parsed;
      // If a field is re-detected after discard, keep discard unless user
      // changed the underlying text that triggered detection (good enough UX).
    });
  }

  bool get _hasTitle => _titleController.text.trim().isNotEmpty;

  // Effective parsed value accounting for per-field discards
  DateTime? get _effectiveDate => _dateDiscarded ? null : _parsed?.startDate;
  TimeOfDay? get _effectiveTime => _timeDiscarded ? null : _parsed?.scheduledTime;
  TaskPriority? get _effectivePriority => _priorityDiscarded ? null : _parsed?.priority;
  dynamic get _effectiveScheduler => _schedulerDiscarded ? null : _parsed?.scheduler;

  bool get _hasNlpChips =>
      _parsed != null &&
      (_parsed!.hasAnyDetection) &&
      (!_dateDiscarded || !_timeDiscarded || !_priorityDiscarded || !_schedulerDiscarded) &&
      (_effectiveDate != null ||
          _effectiveTime != null ||
          _effectivePriority != null ||
          _effectiveScheduler != null);

  void _switchType(QuickCaptureType type) {
    setState(() {
      _selectedType = type;
      // Re-parse with same text — NLP stays, filtering is per-type at render
      if (_titleController.text.isNotEmpty) {
        _parsed = NlpTaskParser.parse(_titleController.text);
      }
    });
  }

  Future<void> _save(BuildContext ctx) async {
    if (!_hasTitle || _saving) return;
    HapticFeedback.lightImpact();

    final title = _parsed?.cleanTitle ?? _titleController.text.trim();
    final cleanTitle = title.isEmpty ? _titleController.text.trim() : title;

    if (_selectedType == QuickCaptureType.task) {
      setState(() => _saving = true);
      try {
        final task = Task(
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          title: cleanTitle,
          stage: TaskStage.idea,
          priority: _effectivePriority ?? _extraPriority,
          startDate: _effectiveDate ?? _extraDate,
          endDate: _effectiveDate ?? _extraDate,
          scheduledTime: _effectiveTime != null
              ? '${_effectiveTime!.hour.toString().padLeft(2, '0')}:${_effectiveTime!.minute.toString().padLeft(2, '0')}'
              : null,
          allDay: _effectiveTime == null,
          scheduler: _effectiveScheduler as dynamic,
          notes: _extraNotes.trim().isNotEmpty ? [_extraNotes.trim()] : [],
          duration: 15,
          reminders: [],
          subtasks: [],
          dependsOn: [],
          links: [],
          organizers: List.from(_extraOrganizers),
        );
        task.organizers.addAll(_extraOrganizers);
        await ref.read(vaultProvider.notifier).createObject(task);
        if (mounted) {
          if (widget._isSheet) Navigator.of(context).pop();
          _titleController.clear();
          setState(() {
            _parsed = null;
            _dateDiscarded = false;
            _timeDiscarded = false;
            _priorityDiscarded = false;
            _schedulerDiscarded = false;
            _detailsExpanded = false;
            _extraDate = null;
            _extraPriority = TaskPriority.none;
            _extraOrganizers = [];
            _extraNotes = '';
            _saving = false;
          });
        }
      } catch (e) {
        setState(() => _saving = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving: $e')),
          );
        }
      }
    } else {
      // Non-task types open the full creation form with the typed title
      if (widget._isSheet) Navigator.pop(ctx);
      ctx.push(
        _selectedType.createRoute,
        extra: {'initialTitle': cleanTitle},
      );
    }
  }

  void _openFullEditor(BuildContext ctx) {
    final title = _titleController.text.trim();
    if (widget._isSheet) Navigator.pop(ctx);
    ctx.push('/create/task', extra: {'initialTitle': title});
  }

  void _openMoreOptions(BuildContext ctx) {
    if (widget._isSheet) Navigator.pop(ctx);
    showCreateMenu(ctx);
  }

  @override
  Widget build(BuildContext context) {
    if (widget._isSheet) {
      return _buildSheet(context);
    } else {
      return _buildInline(context);
    }
  }

  Widget _buildSheet(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: bottomInset + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.textMuted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          _buildContent(context),
        ],
      ),
    );
  }

  Widget _buildInline(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        border: Border(
          top: BorderSide(
            color: AppColors.textMuted.withValues(alpha: 0.15),
            width: 0.5,
          ),
        ),
      ),
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final accent = AppTheme.accentColor(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 1. Type selector pills ──────────────────────────────────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: QuickCaptureType.values.map((type) {
              final selected = _selectedType == type;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => _switchType(type),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected
                          ? accent.withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected
                            ? accent
                            : AppColors.textMuted.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      type.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: selected ? accent : AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),

        // ── 2. Text field + save button row ────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: TextField(
                controller: _titleController,
                focusNode: _titleFocus,
                autofocus: widget._isSheet,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(context),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: _selectedType.hint,
                  hintStyle: TextStyle(
                    fontSize: 16,
                    color: AppColors.textMuted.withValues(alpha: 0.6),
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Full editor button (only in sheet mode)
            if (widget._isSheet && _selectedType == QuickCaptureType.task)
              IconButton(
                icon: Icon(Icons.open_in_full_rounded, size: 20, color: AppColors.textMuted),
                tooltip: 'Open full editor',
                onPressed: () => _openFullEditor(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            const SizedBox(width: 4),
            // Save button
            AnimatedOpacity(
              opacity: _hasTitle ? 1.0 : 0.4,
              duration: const Duration(milliseconds: 150),
              child: _saving
                  ? SizedBox(
                      width: 36,
                      height: 36,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: accent,
                      ),
                    )
                  : FilledButton(
                      onPressed: _hasTitle ? () => _save(context) : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Save',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
            ),
          ],
        ),

        // ── 3. Live NLP chips ───────────────────────────────────────────────
        if (_hasNlpChips) ...[
          const SizedBox(height: 10),
          NlpChipsRow(
            parsed: ParsedNlpTask(
              cleanTitle: _parsed!.cleanTitle,
              startDate: _effectiveDate,
              scheduledTime: _effectiveTime,
              priority: (_selectedType.showPriority ? _effectivePriority : null),
              scheduler: (_selectedType.showRecurrence ? _effectiveScheduler : null),
            ),
            onRemoveDate: _effectiveDate != null
                ? () => setState(() => _dateDiscarded = true)
                : null,
            onRemoveTime: _effectiveTime != null
                ? () => setState(() => _timeDiscarded = true)
                : null,
            onRemovePriority: (_selectedType.showPriority && _effectivePriority != null)
                ? () => setState(() => _priorityDiscarded = true)
                : null,
            onRemoveScheduler: (_selectedType.showRecurrence && _effectiveScheduler != null)
                ? () => setState(() => _schedulerDiscarded = true)
                : null,
          ),
        ],

        // ── 4. + Add details toggle ─────────────────────────────────────────
        const SizedBox(height: 8),
        Row(
          children: [
            GestureDetector(
              onTap: () => setState(() => _detailsExpanded = !_detailsExpanded),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _detailsExpanded
                        ? Icons.remove_rounded
                        : Icons.add_rounded,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _detailsExpanded ? 'Hide details' : 'Add details',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            // "More options…" to open CreateMenuSheet
            if (widget._isSheet)
              TextButton(
                onPressed: () => _openMoreOptions(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: AppColors.textMuted,
                ),
                child: const Text(
                  'More options…',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
          ],
        ),

        // ── 5. Expanded details ─────────────────────────────────────────────
        if (_detailsExpanded) ...[
          const SizedBox(height: 12),
          _buildDetailsSection(context, accent),
        ],
      ],
    );
  }

  Widget _buildDetailsSection(BuildContext context, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1),
        const SizedBox(height: 12),

        // Due date (only if NLP didn't already detect one, or if discarded)
        if (_effectiveDate == null) ...[
          _DetailRow(
            icon: Icons.calendar_today_rounded,
            label: _extraDate != null
                ? DateFormat('dd/MM/yyyy').format(_extraDate!)
                : 'Due date',
            color: _extraDate != null ? accent : AppColors.textMuted,
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2035),
              );
              if (picked != null) setState(() => _extraDate = picked);
            },
          ),
          const SizedBox(height: 8),
        ],

        // Priority (only for Task)
        if (_selectedType.showPriority && _effectivePriority == null) ...[
          Row(
            children: [
              Icon(Icons.flag_rounded, size: 18, color: AppColors.textMuted),
              const SizedBox(width: 8),
              Text(
                'Priority',
                style: TextStyle(fontSize: 14, color: AppColors.textMuted),
              ),
              const Spacer(),
              ...TaskPriority.values.where((p) => p != TaskPriority.none).map((p) {
                final selected = _extraPriority == p;
                Color c;
                switch (p) {
                  case TaskPriority.high:
                    c = AppColors.priorityHigh;
                    break;
                  case TaskPriority.medium:
                    c = AppColors.priorityMedium;
                    break;
                  case TaskPriority.low:
                    c = AppColors.priorityLow;
                    break;
                  default:
                    c = AppColors.textMuted;
                }
                return GestureDetector(
                  onTap: () => setState(
                    () => _extraPriority = selected ? TaskPriority.none : p,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      Icons.flag_rounded,
                      size: 22,
                      color: selected ? c : AppColors.textMuted.withValues(alpha: 0.3),
                    ),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 8),
        ],

        // Project / Area organizer
        OrganizerSelectorField(
          selectedOrganizers: _extraOrganizers,
          onChanged: (orgs) => setState(() => _extraOrganizers = orgs),
        ),
        const SizedBox(height: 8),

        // Notes
        TextField(
          onChanged: (v) => setState(() => _extraNotes = v),
          decoration: InputDecoration(
            hintText: 'Notes (optional)',
            hintStyle: TextStyle(
              fontSize: 13,
              color: AppColors.textMuted.withValues(alpha: 0.6),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: AppColors.textMuted.withValues(alpha: 0.2),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: AppColors.textMuted.withValues(alpha: 0.2),
              ),
            ),
          ),
          maxLines: 3,
          style: const TextStyle(fontSize: 13),
        ),
      ],
    );
  }
}

// ─── Small detail row helper ─────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

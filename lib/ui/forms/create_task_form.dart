import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/social_post.dart';
import '../../models/task_model.dart';
import '../../models/project_model.dart';
import '../../models/reminder_config.dart';
import '../../models/shared_types.dart';
import '../../models/relay_step.dart';
import '../../providers/vault_provider.dart';
import '../theme.dart';
import '../widgets/wiki_link_controller.dart';
import '../widgets/rich_text_editor.dart';
import '../widgets/organizer_selector_field.dart';
import '../widgets/date_picker_field.dart';
import '../widgets/property_row.dart';
import '../widgets/form_section_card.dart';
import '../widgets/discard_guard.dart';
import '../widgets/reminder_config_sheet.dart';
import '../utils/notification_type_utils.dart';
import '../forms/scheduler_picker.dart';
import '../widgets/time_block_picker.dart';
import '../../models/scheduler.dart';
import '../widgets/universal_search_picker.dart';
import 'package:go_router/go_router.dart';
import '../../providers/settings_provider.dart';
import '../../services/nlp_task_parser.dart';

class CreateTaskForm extends ConsumerStatefulWidget {
  final String? initialTitle;
  final Task? existingTask;
  final String? initialTimeBlock;
  final TaskStage? initialStage;
  final List<OrganizerReference>? initialOrganizers;
  final DateTime? initialDate;
  final TimeOfDay? initialTime;
  const CreateTaskForm({
    super.key,
    this.initialTitle,
    this.existingTask,
    this.initialTimeBlock,
    this.initialStage,
    this.initialOrganizers,
    this.initialDate,
    this.initialTime,
  });

  @override
  ConsumerState<CreateTaskForm> createState() => _CreateTaskFormState();
}

class _CreateTaskFormState extends ConsumerState<CreateTaskForm> {
  late final TextEditingController _titleController;
  String _notesContent = '';
  TaskStage _stage = TaskStage.todo;
  TaskPriority _priority = TaskPriority.none;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _allDay = true;
  TimeOfDay? _scheduledTime;
  int? _durationMinutes;
  String? _reflection;
  bool _untilDone = false;
  String? _dateRange;
  List<OrganizerReference> _organizers = [];
  final List<Subtask> _subtasks = [];
  List<ReminderConfig> _customReminders = [];
  int? _pomodoroCount;
  String? _timeBlock;
  List<String> _dependsOn = [];
  List<String> _socialRefs = [];
  Scheduler? _scheduler;
  int? _estimatedMinutes;
  String? _linkedSystem;
  String? _rotationGroupId;
  RotationFrequencyType _rotationFrequencyType = RotationFrequencyType.none;
  int? _rotationEveryN;
  final _rotationEveryNController = TextEditingController();
  
  // Alignment tracking (RA-P1-1)
  bool _trackAlignment = false;
  int? _flexibilityWindowMinutes;
  
  // Focus Relay (RA-P1-3)
  bool _useRelay = false;
  List<RelayStep> _relaySteps = [];

  @override
  void initState() {
    super.initState();
    // #region agent log
    // Removed undefined _appendDebugLog call
    // #endregion
    _titleController = WikiLinkTextController(
      context: context,
      text: widget.existingTask?.title ?? widget.initialTitle,
    );
    if (widget.existingTask != null) {
      final task = widget.existingTask!;
      _notesContent = task.notes.isNotEmpty ? task.notes.join('\n\n') : '';
      _stage = task.stage;
      _priority = task.priority;
      _startDate = task.startDate;
      _endDate = task.endDate;
      _allDay = task.allDay;
      _durationMinutes = task.duration;
      if (task.scheduledTime != null && task.scheduledTime!.contains(':')) {
        final parts = task.scheduledTime!.split(':');
        if (parts.length == 2) {
          _scheduledTime = TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 0,
            minute: int.tryParse(parts[1]) ?? 0,
          );
        }
      }
      _untilDone = task.untilDone;
      _dateRange = task.dateRange;
      _reflection = task.reflection;
      _organizers = List.from(task.organizers);
      _subtasks.addAll(
        task.subtasks.map(
          (st) => Subtask(
            title: st.title,
            completed: st.completed,
            slug: st.slug,
            isCollapsed: st.isCollapsed,
          ),
        ),
      );
      _customReminders = List.from(task.reminders);
      _scheduler = task.scheduler;
      _pomodoroCount = task.pomodoroCount;
      _timeBlock = task.timeBlock;
      _dependsOn = List.from(task.dependsOn);
      _socialRefs = List.from(task.links);
      _estimatedMinutes = task.estimatedMinutes;
      _linkedSystem = task.linkedSystem;
      _rotationGroupId = task.rotationGroupId;
      _rotationFrequencyType = task.rotationFrequencyType;
      _rotationEveryN = task.rotationEveryN;
      _rotationEveryNController.text =
          task.rotationEveryN?.toString() ?? '';
      _trackAlignment = task.flexibilityWindowMinutes != null;
      _flexibilityWindowMinutes = task.flexibilityWindowMinutes;
      _useRelay = task.hasRelaySteps;
      _relaySteps = task.relaySteps ?? [];
    } else {
      // Use initialDate and initialTime if provided
      if (widget.initialDate != null) {
        _startDate = widget.initialDate;
        _endDate = widget.initialDate;
      }
      if (widget.initialTime != null) {
        _scheduledTime = widget.initialTime;
      }
      if (widget.initialStage != null) {
        _stage = widget.initialStage!;
      }
      if (widget.initialTimeBlock != null) {
        _timeBlock = widget.initialTimeBlock;
      }
      if (widget.initialOrganizers != null) {
        _organizers = List.from(widget.initialOrganizers!);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _rotationEveryNController.dispose();
    super.dispose();
  }

  Project? _findRotationProject() {
    final projects = ref.read(projectsProvider);
    for (final org in _organizers) {
      if (org.type != 'project') continue;
      for (final project in projects) {
        if (project.slug == org.slug && project.hasRotation) return project;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final hasTitle = _titleController.text.trim().isNotEmpty;
    final settings = ref.watch(settingsProvider);
    final isDirty = hasTitle || _notesContent.trim().isNotEmpty;
    final hasDateRange = _dateRange != null && _dateRange!.trim().isNotEmpty;

    return DiscardGuard(
      isDirty: isDirty,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: CustomScrollView(
          slivers: [
            // ─── App Bar ───
            SliverAppBar(
              pinned: true,
              leading: IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.maybePop(context),
              ),
              title: Text(
                widget.existingTask != null ? 'Editar Tarefa' : 'Nova Tarefa',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              centerTitle: true,
              actions: [
                IconButton(
                  icon: Icon(
                    Icons.copy_all_rounded,
                    color: AppTheme.accentColor(context),
                  ),
                  tooltip: 'Usar Template',
                  onPressed: _showTemplatePicker,
                ),
                IconButton(
                  icon: Icon(
                    Icons.inbox_rounded,
                    color: AppTheme.accentColor(context),
                  ),
                  tooltip: 'Mover para Backlog',
                  onPressed: () {
                    setState(() {
                      _startDate = null;
                      _endDate = null;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Data removida (Backlog)')),
                    );
                  },
                ),
                if (widget.existingTask != null)
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.priorityHigh,
                    ),
                    onPressed: _deleteTask,
                  ),
                TextButton(
                  onPressed: hasTitle ? _saveTask : null,
                  child: Text(
                    'Salvar',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: hasTitle ? AppTheme.accentColor(context) : AppColors.textMuted,
                    ),
                  ),
                ),
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
                        hintText: 'Task title',
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

                    _buildNlpSuggestions(settings),

                    const SizedBox(height: 20),

                    // ─── Status Selector (Card) ───
                    FormSectionCard(
                      title: 'Status',
                      child: _buildStageSegmentedControl(),
                    ),

                    const SizedBox(height: 12),

                    // ─── Metadata Card ───
                    FormSectionCard(
                      child: Column(
                        children: [
                          // Priority
                          Row(
                            children: [
                              const Text(
                                'Priority',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Spacer(),
                              ...TaskPriority.values
                                  .where((p) => p != TaskPriority.none)
                                  .map((p) {
                                    final selected = _priority == p;
                                    return GestureDetector(
                                      onTap: () => setState(
                                        () => _priority = selected
                                            ? TaskPriority.none
                                            : p,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                        ),
                                        child: Icon(
                                          Icons.flag_rounded,
                                          size: 24,
                                          color: selected
                                              ? _priorityColor(p)
                                              : AppColors.textMuted.withValues(
                                                  alpha: 0.3,
                                                ),
                                        ),
                                      ),
                                    );
                                  }),
                            ],
                          ),
                          const Divider(height: 24),
                          // Date
                          _buildDateRow(),
                          const Divider(height: 24),
                          // All Day & Time
                          Row(
                            children: [
                              const Text(
                                'All Day',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Spacer(),
                              Switch.adaptive(
                                value: _allDay,
                                onChanged: (v) => setState(() => _allDay = v),
                                activeThumbColor: AppTheme.accentColor(context),
                              ),
                            ],
                          ),
                          if (!_allDay) ...[
                            const Divider(height: 24),
                            PropertyRow(
                              label: 'Time',
                              value: _scheduledTime != null
                                  ? _scheduledTime!.format(context)
                                  : 'Set Time',
                              valueColor: _scheduledTime != null
                                  ? AppTheme.accentColor(context)
                                  : AppColors.textMuted,
                              onTap: _pickTime,
                            ),
                          ],
                          // Alignment tracking section (RA-P1-1)
                          if (_scheduledTime != null) ...[
                            const Divider(height: 24),
                            Row(
                              children: [
                                const Text(
                                  'Track Timing',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const Spacer(),
                                Switch.adaptive(
                                  value: _trackAlignment,
                                  onChanged: (v) => setState(() => _trackAlignment = v),
                                  activeThumbColor: AppTheme.accentColor(context),
                                ),
                              ],
                            ),
                            if (_trackAlignment) ...[
                              const SizedBox(height: 12),
                              const Text(
                                'Flexibility window (minutes late still counts as on time)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [5, 10, 15, 30].map((minutes) {
                                  final isSelected = _flexibilityWindowMinutes == minutes;
                                  return FilterChip(
                                    label: Text('${minutes}m'),
                                    selected: isSelected,
                                    onSelected: (selected) {
                                      setState(() {
                                        _flexibilityWindowMinutes = selected ? minutes : null;
                                      });
                                    },
                                    selectedColor: AppTheme.accentColor(context).withValues(alpha: 0.15),
                                    checkmarkColor: AppTheme.accentColor(context),
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                          const Divider(height: 24),
                          // Duration
                          PropertyRow(
                            label: 'Duration',
                            value: '${_durationMinutes ?? 15} min',
                            valueColor: AppTheme.accentColor(context),
                            onTap: _editDuration,
                          ),
                          const Divider(height: 24),
                          // Focus Relay section (RA-P1-3)
                          Row(
                            children: [
                              const Text(
                                'Break into Steps',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Spacer(),
                              Switch.adaptive(
                                value: _useRelay,
                                onChanged: (v) => setState(() => _useRelay = v),
                                activeThumbColor: AppTheme.accentColor(context),
                              ),
                            ],
                          ),
                          if (_useRelay) ...[
                            const SizedBox(height: 12),
                            const Text(
                              'Define the sequence of steps for this task',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...List.generate(_relaySteps.length, (index) {
                              final step = _relaySteps[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceVariantColor(context),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        initialValue: step.label,
                                        decoration: InputDecoration(
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          border: const OutlineInputBorder(),
                                          labelText: 'Step ${index + 1}',
                                        ),
                                        onChanged: (value) {
                                          _relaySteps[index] = step.copyWith(label: value);
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: 70,
                                      child: TextFormField(
                                        keyboardType: TextInputType.number,
                                        initialValue: step.durationMinutes.toString(),
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                          border: OutlineInputBorder(),
                                          labelText: 'min',
                                        ),
                                        onChanged: (value) {
                                          final parsed = int.tryParse(value);
                                          if (parsed != null && parsed > 0) {
                                            _relaySteps[index] = step.copyWith(durationMinutes: parsed);
                                          }
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 18),
                                      onPressed: () {
                                        setState(() {
                                          _relaySteps.removeAt(index);
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              );
                            }),
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _relaySteps.add(RelayStep(
                                    label: 'Step ${_relaySteps.length + 1}',
                                    durationMinutes: 25,
                                  ));
                                });
                              },
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Add Step'),
                            ),
                          ],
                          const Divider(height: 24),
                          if (hasDateRange) ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Date Range',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Flexible(
                                  child: Text(
                                    _dateRange!,
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.accentColor(context),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Until Done fica desativado enquanto esta tarefa usa date_range.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                            const Divider(height: 24),
                          ],
                          // Until Done
                          Row(
                            children: [
                              const Text(
                                'Until Done',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Spacer(),
                              Switch.adaptive(
                                value: _untilDone,
                                onChanged: hasDateRange
                                    ? null
                                    : (v) => setState(() => _untilDone = v),
                                activeThumbColor: AppTheme.accentColor(context),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          // Reminder configuration (Enhanced)
                          _buildReminderSection(),
                          const Divider(height: 24),
                          // Pomodoro Blocks
                          PropertyRow(
                            label: 'Pomodoro Blocks',
                            value: _pomodoroCount != null
                                ? '$_pomodoroCount blocks'
                                : 'None',
                            valueColor: _pomodoroCount != null
                                ? AppTheme.accentColor(context)
                                : AppColors.textMuted,
                            onTap: _editPomodoros,
                          ),
                          const Divider(height: 24),
                          // Tempo Estimado
                          PropertyRow(
                            label: 'Tempo Estimado',
                            value: _estimatedMinutes != null
                                ? '$_estimatedMinutes min'
                                : 'Não estimado',
                            valueColor: _estimatedMinutes != null
                                ? AppTheme.accentColor(context)
                                : AppColors.textMuted,
                            onTap: _editEstimatedTime,
                          ),
                          const Divider(height: 24),
                          // Repeat / Scheduler
                          PropertyRow(
                            label: 'Repeat',
                            value: _scheduler != null ? 'On' : 'None',
                            valueColor: _scheduler != null
                                ? AppTheme.accentColor(context)
                                : AppColors.textMuted,
                            onTap: _rotationFrequencyType !=
                                    RotationFrequencyType.none
                                ? () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Remova a rotação para usar Repeat.',
                                        ),
                                      ),
                                    );
                                  }
                                : _pickScheduler,
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

                    // ─── Connections Card ───
                    FormSectionCard(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      child: OrganizerSelectorField(
                        selectedOrganizers: _organizers,
                        onChanged: (val) => setState(() {
                          _organizers = val;
                          if (_findRotationProject() == null) {
                            _rotationGroupId = null;
                            _rotationFrequencyType =
                                RotationFrequencyType.none;
                            _rotationEveryN = null;
                            _rotationEveryNController.clear();
                          }
                        }),
                      ),
                    ),

                    if (_findRotationProject() != null) ...[
                      const SizedBox(height: 12),
                      _buildRotationCard(_findRotationProject()!),
                    ],

                    const SizedBox(height: 12),

                    _buildSocialRefsCard(),

                    const SizedBox(height: 12),

                    // ─── Depends On Card ───
                    FormSectionCard(
                      title: 'Depende de (Bloqueantes)',
                      trailing: IconButton(
                        icon: const Icon(Icons.add, size: 20),
                        onPressed: () async {
                          final selected = await showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => UniversalSearchPickerSheet(
                              title: 'Select blocking task',
                              initialFilter: 'task',
                              onSelected: (obj) => Navigator.pop(context, obj),
                            ),
                          );
                          if (selected != null && selected is Task) {
                            setState(() {
                              if (!_dependsOn.contains(selected.slug)) {
                                _dependsOn.add(selected.slug);
                              }
                            });
                          }
                        },
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_dependsOn.isNotEmpty) const SizedBox(height: 8),
                          for (final slug in _dependsOn)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.lock_rounded,
                                    size: 16,
                                    color: AppColors.textMuted,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Consumer(
                                      builder: (context, ref, _) {
                                        final objects =
                                            ref
                                                .watch(allObjectsProvider)
                                                .value ??
                                            [];
                                        final task = objects.firstWhere(
                                          (o) => o is Task && o.slug == slug,
                                          orElse: () => Task(
                                            id: slug,
                                            title: slug,
                                            stage: TaskStage.todo,
                                            createdAt: DateTime.now(),
                                          ),
                                        );
                                        return Text(
                                          task.title,
                                          style: const TextStyle(fontSize: 14),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        );
                                      },
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 16,
                                      color: AppColors.textMuted,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _dependsOn.remove(slug);
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ─── Subtasks Card ───
                    FormSectionCard(
                      title: 'Subtasks',
                      trailing: IconButton(
                        icon: const Icon(Icons.add, size: 20),
                        onPressed: _addSubtask,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_subtasks.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _buildSubtaskReorderableList(),
                          ] else ...[
                            const SizedBox(height: 8),
                            const Text(
                              'No subtasks yet',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ─── Notes Card ───
                    FormSectionCard(
                      title: 'Notes',
                      child: SizedBox(
                        height: 200,
                        child: RichTextEditor(
                          content: _notesContent,
                          onChanged: (val) {
                            setState(() {
                              _notesContent = val;
                            });
                          },
                          placeholder: 'Add details...',
                          expands: true,
                        ),
                      ),
                    ),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addSessionHeader() {
    setState(() {
      _subtasks.add(Subtask(title: 'New Section', isHeader: true));
    });
  }

  Widget _buildStageSegmentedControl() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: TaskStage.values.map((stage) {
          final selected = _stage == stage;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _stage = stage),
              child: Container(
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? AppTheme.accentColor(context) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: AppTheme.accentColor(context).withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  _stageLabel(stage),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSubtaskReorderableList() {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: _subtasks.length,
      onReorder: _reorderSubtasks,
      itemBuilder: (context, index) {
        final subtask = _subtasks[index];
        return KeyedSubtree(
          key: ValueKey('subtask_${subtask.slug ?? subtask.title}_$index'),
          child: _buildSubtaskItem(index, subtask),
        );
      },
    );
  }

  void _reorderSubtasks(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final moved = _subtasks.removeAt(oldIndex);
      _subtasks.insert(newIndex, moved);
    });
    // #region agent log
    // Removed undefined _appendDebugLog call
    // #endregion
  }

  Widget _buildSubtaskItem(int index, Subtask subtask) {
    return Padding(
      key: ValueKey('subtask_row_$index'),
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: subtask.completed,
              onChanged: (v) => setState(() => subtask.completed = v!),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: TextEditingController(text: subtask.title),
              onChanged: (v) => subtask.title = v,
              style: TextStyle(
                fontSize: 14,
                decoration: subtask.completed
                    ? TextDecoration.lineThrough
                    : null,
                color: subtask.completed
                    ? AppColors.textMuted
                    : AppColors.textPrimary,
              ),
              decoration: const InputDecoration(
                hintText: 'Subtask title',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (subtask.slug == null)
            IconButton(
              onPressed: () => _promoteSubtask(index),
              icon: Icon(
                Icons.rocket_launch_outlined,
                size: 16,
                color: AppTheme.accentColor(context),
              ),
              tooltip: 'Promote to Task',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          if (subtask.slug != null)
            Icon(Icons.link_rounded, size: 16, color: AppTheme.accentColor(context)),
          IconButton(
            onPressed: () => setState(() => _subtasks.removeAt(index)),
            icon: const Icon(
              Icons.close_rounded,
              size: 16,
              color: AppColors.textMuted,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 6),
          ReorderableDragStartListener(
            index: index,
            child: const Icon(
              Icons.drag_indicator_rounded,
              size: 18,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  void _promoteSubtask(int index) {
    final sub = _subtasks[index];
    if (sub.title.trim().isEmpty) return;

    final slug = sub.title
        .toLowerCase()
        .replaceAll(' ', '-')
        .replaceAll(RegExp(r'[^a-z0-9-]'), '');
    setState(() {
      sub.slug = slug;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Subtask "${sub.title}" will be created as a full task on save.',
        ),
      ),
    );
  }

  void _addSubtask() {
    setState(() {
      _subtasks.add(Subtask(title: ''));
    });
  }

  Widget _buildDateRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PropertyRow(
          label: 'Start Date',
          value: _startDate != null
              ? DateFormat('MMM d, yyyy').format(_startDate!)
              : 'No Date',
          valueColor: _startDate != null
              ? AppTheme.accentColor(context)
              : AppColors.textMuted,
          onTap: _pickStartDate,
        ),
        const Divider(height: 24),
        PropertyRow(
          label: 'Due Date',
          value: _endDate != null
              ? DateFormat('MMM d, yyyy').format(_endDate!)
              : 'No Date',
          valueColor: _endDate != null
              ? AppTheme.accentColor(context)
              : AppColors.textMuted,
          onTap: _pickDueDate,
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _quickDateChip('Today', DateTime.now()),
              const SizedBox(width: 8),
              _quickDateChip(
                'Tomorrow',
                DateTime.now().add(const Duration(days: 1)),
              ),
              const SizedBox(width: 8),
              _quickDateChip(
                'Next Week',
                DateTime.now().add(const Duration(days: 7)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _quickDateChip(String label, DateTime date) {
    final isSelected =
        _endDate?.year == date.year &&
        _endDate?.month == date.month &&
        _endDate?.day == date.day;
    return GestureDetector(
      onTap: () =>
          setState(() => _endDate = DateTime(date.year, date.month, date.day)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.accentColor(context).withValues(alpha: 0.1)
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.accentColor(context) : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? AppTheme.accentColor(context) : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildSocialRefsCard() {
    final posts = ref.watch(socialPostsProvider);
    final selectedPosts = posts
        .where((post) => _socialRefs.contains('[[social/${post.socialSlug}]]'))
        .toList();

    return FormSectionCard(
      title: 'Referências',
      trailing: IconButton(
        icon: const Icon(Icons.add_link_rounded),
        color: AppTheme.accentColor(context),
        onPressed: _pickSocialReference,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (selectedPosts.isEmpty)
            const Text(
              'Nenhum post social vinculado',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final post in selectedPosts)
                  InputChip(
                    label: Text(
                      post.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onDeleted: () => setState(
                      () => _socialRefs.remove('[[social/${post.socialSlug}]]'),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  void _pickSocialReference() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => UniversalSearchPickerSheet(
        title: 'Adicionar referência',
        initialFilter: 'social_post',
        onSelected: (obj) {
          if (obj is SocialPost) {
            final ref = '[[social/${obj.socialSlug}]]';
            setState(() {
              if (!_socialRefs.contains(ref)) _socialRefs.add(ref);
            });
          }
          Navigator.pop(context);
        },
      ),
    );
  }

  void _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _scheduledTime ?? TimeOfDay.now(),
    );
    if (time != null) setState(() => _scheduledTime = time);
  }

  void _pickDueDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (date != null) setState(() => _endDate = date);
  }

  void _pickStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (date != null) setState(() => _startDate = date);
  }

  Future<void> _editDuration() async {
    final initialValue = _durationMinutes ?? 15;
    final controller = TextEditingController(text: initialValue.toString());

    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Duração'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(suffixText: 'min'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final val = int.tryParse(controller.text.trim());
              Navigator.pop(ctx, val);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (result != null && result > 0) {
      setState(() => _durationMinutes = result);
    }
    controller.dispose();
  }

  Future<void> _editPomodoros() async {
    final initialValue = _pomodoroCount ?? 0;
    final controller = TextEditingController(text: initialValue.toString());

    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Blocos Pomodoro'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(suffixText: 'blocos'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final val = int.tryParse(controller.text.trim());
              Navigator.pop(ctx, val);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() => _pomodoroCount = result > 0 ? result : null);
    }
    controller.dispose();
  }

  Future<void> _editEstimatedTime() async {
    final initialValue = _estimatedMinutes ?? 0;
    final controller = TextEditingController(
      text: initialValue > 0 ? initialValue.toString() : '',
    );

    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tempo Estimado'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(suffixText: 'min'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final val = int.tryParse(controller.text.trim());
              Navigator.pop(ctx, val);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() => _estimatedMinutes = result > 0 ? result : null);
    }
    controller.dispose();
  }

  Widget _buildReminderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Reminders',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            IconButton(
              icon: Icon(Icons.add_rounded, color: AppTheme.accentColor(context)),
              onPressed: _addReminder,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        if (_customReminders.isNotEmpty) ...[
          const SizedBox(height: 8),
          ..._customReminders.asMap().entries.map((entry) {
            final idx = entry.key;
            final reminder = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => _editReminder(idx),
                child: Row(
                  children: [
                    Icon(
                      NotificationTypeUtils.getIcon(reminder.type),
                      size: 16,
                      color: AppTheme.accentColor(context),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      reminder.minutesBefore != null
                          ? '${reminder.minutesBefore} min before'
                          : reminder.triggerTime != null
                          ? DateFormat(
                              'MMM d, HH:mm',
                            ).format(reminder.triggerTime!)
                          : 'Set Time',
                      style: const TextStyle(fontSize: 13),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16),
                      onPressed: () =>
                          setState(() => _customReminders.removeAt(idx)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            );
          }),
        ] else ...[
          const SizedBox(height: 4),
          const Text(
            'Default (1h before)',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ],
    );
  }

  void _addReminder() {
    _showReminderDialog();
  }

  void _editReminder(int index) {
    _showReminderDialog(index: index);
  }

  void _showReminderDialog({int? index}) async {
    final existing = index != null ? _customReminders[index] : null;
    final bool hasTime = !_allDay && _scheduledTime != null;

    DateTime? parentDateTime;
    if (hasTime && _scheduledTime != null && _startDate != null) {
      parentDateTime = DateTime(
        _startDate!.year,
        _startDate!.month,
        _startDate!.day,
        _scheduledTime!.hour,
        _scheduledTime!.minute,
      );
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReminderConfigSheet(
        onSave: (config) {
          setState(() {
            if (index != null) {
              _customReminders[index] = config;
            } else {
              _customReminders.add(config);
            }
          });
        },
        parentDateTime: parentDateTime,
        parentDateOnly: _startDate,
      ),
    );
  }

  void _saveTask() async {
    final hasDateRange = _dateRange != null && _dateRange!.trim().isNotEmpty;
    if (_endDate == null && _stage != TaskStage.idea) {
      final result = await showDialog<String>(
        context: context,
        barrierDismissible: true,
        builder: (context) => AlertDialog(
          title: const Text('No date set'),
          content: const Text('Where do you want to save this task?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'backlog'),
              child: const Text('Backlog'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, 'today'),
              child: const Text('Today'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (result == 'backlog') {
        setState(() => _stage = TaskStage.backlog);
      } else {
        final now = DateTime.now();
        setState(() {
          _endDate = DateTime(now.year, now.month, now.day);
          _stage = TaskStage.todo;
        });
      }
    }

    if (_stage == TaskStage.finalized) {
      final reflection = await _showReflectionPrompt();
      if (reflection == null) return;
      if (!mounted) return;
      _notesContent = '$_notesContent\n\n### Reflection\n$reflection';
      _reflection = reflection;
    }

    final task = Task(
      id: widget.existingTask?.id,
      createdAt: widget.existingTask?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      title: _titleController.text.trim(),
      stage: _stage,
      priority: _priority,
      startDate: _startDate,
      endDate: _endDate,
      subtasks: _subtasks,
      notes: _notesContent.trim().isNotEmpty ? [_notesContent.trim()] : [],
      reflection: _reflection,
      allDay: _allDay,
      scheduledTime: _scheduledTime != null
          ? '${_scheduledTime!.hour.toString().padLeft(2, '0')}:${_scheduledTime!.minute.toString().padLeft(2, '0')}'
          : null,
      untilDone: hasDateRange ? false : _untilDone,
      dateRange: _dateRange,
      duration: _durationMinutes ?? 15,
      reminders: _customReminders,
      scheduler: _scheduler,
      pomodoroCount: _pomodoroCount,
      timeBlock: _timeBlock,
      dependsOn: _dependsOn,
      links: _socialRefs,
      estimatedMinutes: _estimatedMinutes,
      linkedSystem: _linkedSystem,
      rotationGroupId: _rotationFrequencyType != RotationFrequencyType.none
          ? _rotationGroupId
          : null,
      rotationFrequencyType: _rotationFrequencyType,
      rotationEveryN: _rotationFrequencyType ==
              RotationFrequencyType.everyNRotations
          ? int.tryParse(_rotationEveryNController.text.trim()) ??
              _rotationEveryN
          : null,
      rotationLastCompletedAtOccurrence:
          widget.existingTask?.rotationLastCompletedAtOccurrence,
      rotationDailyCompletions:
          widget.existingTask?.rotationDailyCompletions ?? {},
      flexibilityWindowMinutes: _trackAlignment ? _flexibilityWindowMinutes : null,
      relaySteps: _useRelay ? _relaySteps : null,
    );

    task.organizers.clear();
    task.organizers.addAll(_organizers);

    try {
      if (widget.existingTask != null) {
        await ref.read(vaultProvider.notifier).updateObject(task);
      } else {
        await ref.read(vaultProvider.notifier).createObject(task);
      }

      await _createPromotedSubtasks(task);
    } catch (e) {
      debugPrint('Failed to save task: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao salvar tarefa: $e')));
      return;
    }
    if (mounted) Navigator.pop(context, true);
  }

  void _deleteTask() {
    if (widget.existingTask == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text(
          'Are you sure you want to delete "${widget.existingTask!.title}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              ref.read(vaultProvider.notifier).deleteObject(widget.existingTask!);
              Navigator.pop(ctx);
              Navigator.pop(context);
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

  Future<void> _createPromotedSubtasks(Task parentTask) async {
    final promoted = _subtasks.where((subtask) {
      return subtask.slug != null && subtask.title.trim().isNotEmpty;
    }).toList();
    if (promoted.isEmpty) return;

    for (final subtask in promoted) {
      final child = Task(
        title: subtask.title,
        stage: subtask.completed ? TaskStage.finalized : TaskStage.todo,
        priority: _priority,
        startDate: DateTime.now(),
        notes: ['Promoted from [[${parentTask.slug}]].'],
        organizers: [
          ...parentTask.organizers,
          OrganizerReference(
            type: 'task',
            slug: parentTask.slug,
            title: parentTask.title,
          ),
        ],
      );
      await ref.read(vaultProvider.notifier).createObject(child);
      subtask.slug = child.slug;
    }
    await ref
        .read(vaultProvider.notifier)
        .updateObject(parentTask.copyWith(subtasks: _subtasks));
  }

  Future<String?> _showReflectionPrompt() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Task Reflection'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('How was it completing this task? Any learnings?'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Write your reflection...',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('Skip'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text(
              'Complete',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  String _stageLabel(TaskStage stage) {
    switch (stage) {
      case TaskStage.idea:
        return 'Idea';
      case TaskStage.backlog:
        return 'Backlog';
      case TaskStage.todo:
        return 'To-do';
      case TaskStage.inProgress:
        return 'Doing';
      case TaskStage.pending:
        return 'Wait';
      case TaskStage.finalized:
        return 'Done';
    }
  }

  void _pickScheduler() async {
    final result = await showModalBottomSheet<Scheduler>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: SchedulerPicker(initialScheduler: _scheduler),
      ),
    );
    if (result != null) {
      setState(() {
        _scheduler = result;
        _rotationGroupId = null;
        _rotationFrequencyType = RotationFrequencyType.none;
        _rotationEveryN = null;
        _rotationEveryNController.clear();
      });
    }
  }

  Widget _buildRotationCard(Project project) {
    final groups = [...project.rotationGroups]
      ..sort((a, b) => a.order.compareTo(b.order));

    return FormSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sync_rounded, size: 18, color: AppTheme.accentColor(context)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Rotação — ${project.title}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Mutuamente exclusivo com Repeat.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: 'Zona',
              border: OutlineInputBorder(),
            ),
            items: groups
                .map(
                  (g) => DropdownMenuItem(
                    value: g.id,
                    child: Text(
                      '${g.emoji != null ? '${g.emoji} ' : ''}${g.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _rotationGroupId = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<RotationFrequencyType>(
            decoration: const InputDecoration(
              labelText: 'Tipo de frequência',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: RotationFrequencyType.daily,
                child: Text('Diária'),
              ),
              DropdownMenuItem(
                value: RotationFrequencyType.oncePerPeriod,
                child: Text('Uma vez no período'),
              ),
              DropdownMenuItem(
                value: RotationFrequencyType.everyNRotations,
                child: Text('Por frequência'),
              ),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                _rotationFrequencyType = v;
                _scheduler = null;
                if (v != RotationFrequencyType.everyNRotations) {
                  _rotationEveryN = null;
                  _rotationEveryNController.clear();
                }
              });
            },
          ),
          if (_rotationFrequencyType ==
              RotationFrequencyType.everyNRotations) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _rotationEveryNController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'A cada N rotações',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => _rotationEveryN = int.tryParse(v),
            ),
          ],
          if (_rotationFrequencyType != RotationFrequencyType.none) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() {
                  _rotationGroupId = null;
                  _rotationFrequencyType = RotationFrequencyType.none;
                  _rotationEveryN = null;
                  _rotationEveryNController.clear();
                }),
                child: const Text('Remover rotação'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _priorityColor(TaskPriority p) {
    switch (p) {
      case TaskPriority.high:
        return AppColors.priorityHigh;
      case TaskPriority.medium:
        return AppColors.priorityMedium;
      case TaskPriority.low:
        return AppColors.priorityLow;
      default:
        return AppColors.textMuted;
    }
  }

  Widget _buildNlpSuggestions(AppSettings settings) {
    if (!settings.nlpTaskParsingEnabled) return const SizedBox.shrink();

    final text = _titleController.text;
    if (text.trim().isEmpty) return const SizedBox.shrink();

    final parsed = NlpTaskParser.parse(text);
    if (!parsed.hasAnyDetection) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.accentColor(context).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 16,
                color: AppTheme.accentColor(context),
              ),
              const SizedBox(width: 6),
              const Text(
                'Sugestões inteligentes detectadas',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _titleController.text = parsed.cleanTitle;
                    if (parsed.startDate != null) {
                      _startDate = parsed.startDate;
                      _endDate = parsed.endDate;
                    }
                    if (parsed.scheduledTime != null) {
                      _scheduledTime = parsed.scheduledTime;
                      _allDay = false;
                    }
                    if (parsed.priority != null) {
                      _priority = parsed.priority!;
                    }
                    if (parsed.scheduler != null) {
                      _scheduler = parsed.scheduler;
                    }
                  });
                },
                icon: Icon(
                  Icons.check_rounded,
                  size: 14,
                  color: AppTheme.accentColor(context),
                ),
                label: Text(
                  'Aplicar',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.accentColor(context),
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (parsed.startDate != null)
                _nlpChip(
                  icon: Icons.calendar_today_rounded,
                  label: DateFormat('dd/MM/yyyy').format(parsed.startDate!),
                  color: AppTheme.accentColor(context),
                ),
              if (parsed.scheduledTime != null)
                _nlpChip(
                  icon: Icons.access_time_rounded,
                  label: parsed.scheduledTime!.format(context),
                  color: AppTheme.accentColor(context),
                ),
              if (parsed.priority != null)
                _nlpChip(
                  icon: Icons.flag_rounded,
                  label: _priorityLabel(parsed.priority!),
                  color: _priorityColor(parsed.priority!),
                ),
              if (parsed.scheduler != null)
                _nlpChip(
                  icon: Icons.repeat_rounded,
                  label: _schedulerLabel(parsed.scheduler!),
                  color: AppTheme.accentColor(context),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _nlpChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _priorityLabel(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high:
        return 'High';
      case TaskPriority.medium:
        return 'Medium';
      case TaskPriority.low:
        return 'Low';
      case TaskPriority.none:
        return 'None';
    }
  }

  String _schedulerLabel(Scheduler scheduler) {
    if (scheduler.rules.isEmpty) return 'Non-recurring';
    final rule = scheduler.rules.first;
    switch (rule.repeatType) {
      case RepeatType.numberOfDays:
        if (rule.interval == 1) return 'Daily';
        return 'Every ${rule.interval} days';
      case RepeatType.daysOfWeek:
        if (rule.daysOfWeek != null && rule.daysOfWeek!.isNotEmpty) {
          final days = rule.daysOfWeek!
              .map((d) {
                switch (d) {
                  case '1':
                    return 'Seg';
                  case '2':
                    return 'Ter';
                  case '3':
                    return 'Qua';
                  case '4':
                    return 'Qui';
                  case '5':
                    return 'Sex';
                  case '6':
                    return 'Sáb';
                  case '7':
                    return 'Dom';
                  default:
                    return d;
                }
              })
              .join(', ');
          return 'Toda semana ($days)';
        }
        return 'Semanal';
      case RepeatType.numberOfWeeks:
        return 'A cada ${rule.interval ?? 1} semanas';
      case RepeatType.numberOfMonths:
        return 'A cada ${rule.interval ?? 1} meses';
      default:
        return 'Recorrente';
    }
  }

  void _showTemplatePicker() async {
    final templates = ref
        .read(templatesProvider)
        .where((t) => t.templateType == 'task')
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text(
                  'Templates',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push(
                      '/create/template',
                      extra: {'initialType': 'task'},
                    );
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Novo'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (templates.isEmpty)
              const Text(
                'Nenhum template encontrado.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ...templates.map(
              (t) => ListTile(
                title: Text(t.title),
                onTap: () {
                  String body = t.body;
                  final refDate = _startDate ?? DateTime.now();
                  body = body.replaceAll(
                    '{{date}}',
                    DateFormat('dd/MM/yyyy').format(refDate),
                  );
                  body = body.replaceAll(
                    '{{time}}',
                    DateFormat('HH:mm').format(refDate),
                  );
                  body = body.replaceAll(
                    '{{weekday}}',
                    DateFormat('EEEE').format(refDate),
                  );
                  body = body.replaceAll(
                    '{{title}}',
                    _titleController.text.isNotEmpty
                        ? _titleController.text
                        : 'Nova Task',
                  );

                  setState(() {
                    if (_notesContent.isEmpty) {
                      _notesContent = body;
                    } else {
                      _notesContent += '\n$body';
                    }

                    if (t.frontmatterDefaults.containsKey('priority')) {
                      final p = t.frontmatterDefaults['priority'];
                      if (p == 'high') {
                        _priority = TaskPriority.high;
                      } else if (p == 'medium') {
                        _priority = TaskPriority.medium;
                      } else if (p == 'low') {
                        _priority = TaskPriority.low;
                      } else if (p == 'urgent') {
                        _priority = TaskPriority.high;
                      }
                    }
                    if (t.frontmatterDefaults.containsKey('duration')) {
                      _durationMinutes = int.tryParse(
                        t.frontmatterDefaults['duration'].toString(),
                      );
                    }
                  });
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/organizer_model.dart';
import '../../models/routine_model.dart';
import '../../models/shared_types.dart';
import '../../models/scheduler.dart';
import '../../models/reminder_config.dart';
import '../../providers/vault_provider.dart';
import '../widgets/organizer_selector_field.dart';
import '../theme.dart';
import 'scheduler_picker.dart';
import 'create_routine_form.dart';

class CreateOrganizerForm extends ConsumerStatefulWidget {
  final OrganizerType? initialType;
  final Organizer? organizer;
  const CreateOrganizerForm({super.key, this.initialType, this.organizer});

  @override
  ConsumerState<CreateOrganizerForm> createState() =>
      _CreateOrganizerFormState();
}

class _CreateOrganizerFormState extends ConsumerState<CreateOrganizerForm> {
  final _titleController = TextEditingController();
  final _statementController = TextEditingController();
  OrganizerType _type = OrganizerType.area;
  String _selectedColor = '#3B82F6';
  String? _parentId;
  List<OrganizerReference> _organizers = [];
  
  // Specific fields for DayTheme and TimeBlock
  List<String> _daysOfWeek = [];
  List<TimeRange> _timeRanges = [];
  int? _energyLevel;
  Scheduler? _scheduler;
  List<ReminderConfig> _reminders = [];

  static const _colors = [
    '#DC2626',
    '#F97316',
    '#F59E0B',
    '#10B981',
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
    if (widget.initialType != null) _type = widget.initialType!;
    final organizer = widget.organizer;
    if (organizer != null) {
      _titleController.text = organizer.title;
      _statementController.text = organizer.statement ?? '';
      _type = organizer.organizerType;
      _selectedColor = organizer.color ?? _selectedColor;
      _parentId = organizer.parentId;
      _organizers = List.from(organizer.organizers);
      _daysOfWeek = List.from(organizer.daysOfWeek);
      _timeRanges = List.from(organizer.timeRanges);
      _energyLevel = organizer.energyLevel;
      _scheduler = organizer.scheduler;
      _reminders = List.from(organizer.reminders);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _statementController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasTitle = _titleController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              widget.organizer == null
                  ? 'Novo Organizador'
                  : 'Edit Organizador',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            centerTitle: true,
            actions: [
              TextButton(
                onPressed: hasTitle ? _saveOrganizer : null,
                child: Text(
                  'Save',
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
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _titleController,
                    onChanged: (_) { if (mounted) setState(() {}); },
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Organizer Title',
                      hintStyle: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                        letterSpacing: -0.5,
                      ),
                      border: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    'Tipo',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: OrganizerType.values.map((t) {
                      final selected = _type == t;
                      return ChoiceChip(
                        label: Text(
                          t.name[0].toUpperCase() + t.name.substring(1),
                        ),
                        selected: selected,
                        onSelected: (v) => setState(() => _type = t),
                        selectedColor: AppTheme.accentColor(context),
                        backgroundColor: AppColors.surfaceVariant,
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        labelStyle: TextStyle(
                          color: selected
                              ? Colors.white
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),
                  const SizedBox(height: 24),
                  const Text(
                    'Cor',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _colors.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final hex = _colors[index];
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

                  const SizedBox(height: 24),
                  const Text(
                    'Parente (Família)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Consumer(
                    builder: (context, ref, _) {
                      final allOrganizers = ref.watch(organizersProvider);
                      // Avoid self-reference if editing
                      final availableParents = allOrganizers
                          .where((Organizer o) => widget.organizer == null || o.id != widget.organizer!.id)
                          .toList();

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            value: _parentId,
                            isExpanded: true,
                            hint: const Text('Sem Parente'),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('Sem Parente (Raiz)'),
                              ),
                              ...availableParents.map(
                                (Organizer o) => DropdownMenuItem<String?>(
                                  value: o.id,
                                  child: Text(o.title),
                                ),
                              ),
                            ],
                            onChanged: (val) => setState(() => _parentId = val),
                          ),
                        ),
                      );
                    },
                  ),

                  if (_type == OrganizerType.dayTheme) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Dias da Semana',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].map((day) {
                        final selected = _daysOfWeek.contains(day);
                        return FilterChip(
                          label: Text(day),
                          selected: selected,
                          onSelected: (val) {
                            setState(() {
                              if (val) {
                                _daysOfWeek.add(day);
                              } else {
                                _daysOfWeek.remove(day);
                              }
                            });
                          },
                          selectedColor: AppTheme.accentColor(context),
                          checkmarkColor: Colors.white,
                          labelStyle: TextStyle(
                            color: selected ? Colors.white : AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 24),
                    // Scheduler for DayTheme
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.repeat_rounded, size: 20),
                      title: const Text(
                        'Scheduler',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        _scheduler != null ? 'Configured' : 'None',
                        style: TextStyle(
                          fontSize: 13,
                          color: _scheduler != null ? AppTheme.accentColor(context) : AppColors.textMuted,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: _pickScheduler,
                    ),

                    const SizedBox(height: 24),
                    // Reminders for DayTheme
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Reminders',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        TextButton(
                          onPressed: _addReminder,
                          child: const Text('+ Add Reminder'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    for (var i = 0; i < _reminders.length; i++)
                      Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          dense: true,
                          leading: const Icon(Icons.notifications_none, size: 18),
                          title: Text(
                            _reminders[i].triggerTime != null
                                ? '${_reminders[i].triggerTime!.hour.toString().padLeft(2, '0')}:${_reminders[i].triggerTime!.minute.toString().padLeft(2, '0')}'
                                : 'No time set',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                            onPressed: () => setState(() => _reminders.removeAt(i)),
                          ),
                          onTap: () => _editReminder(i),
                        ),
                      ),
                  ],

                  if (_type == OrganizerType.timeBlock) ...[
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Horários',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _timeRanges.add(TimeRange(startHour: 9, startMinute: 0, endHour: 10, endMinute: 0));
                            });
                          },
                          child: const Text('+ Adicionar Horário'),
                        ),
                      ],
                    ),
                    ..._timeRanges.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final range = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () async {
                                  final time = await showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay(hour: range.startHour, minute: range.startMinute),
                                  );
                                  if (time != null) {
                                    setState(() {
                                      _timeRanges[idx] = TimeRange(
                                        startHour: time.hour,
                                        startMinute: time.minute,
                                        endHour: range.endHour,
                                        endMinute: range.endMinute,
                                      );
                                    });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(8)),
                                  alignment: Alignment.center,
                                  child: Text('${range.startHour.toString().padLeft(2, '0')}:${range.startMinute.toString().padLeft(2, '0')}'),
                                ),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text('até'),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () async {
                                  final time = await showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay(hour: range.endHour, minute: range.endMinute),
                                  );
                                  if (time != null) {
                                    setState(() {
                                      _timeRanges[idx] = TimeRange(
                                        startHour: range.startHour,
                                        startMinute: range.startMinute,
                                        endHour: time.hour,
                                        endMinute: time.minute,
                                      );
                                    });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(8)),
                                  alignment: Alignment.center,
                                  child: Text('${range.endHour.toString().padLeft(2, '0')}:${range.endMinute.toString().padLeft(2, '0')}'),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: AppColors.error),
                              onPressed: () {
                                setState(() => _timeRanges.removeAt(idx));
                              },
                            ),
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 24),
                    // Scheduler for TimeBlock
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.repeat_rounded, size: 20),
                      title: const Text(
                        'Scheduler',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        _scheduler != null ? 'Configured' : 'None',
                        style: TextStyle(
                          fontSize: 13,
                          color: _scheduler != null ? AppTheme.accentColor(context) : AppColors.textMuted,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: _pickScheduler,
                    ),

                    const SizedBox(height: 24),
                    // Reminders for TimeBlock
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Reminders',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        TextButton(
                          onPressed: _addReminder,
                          child: const Text('+ Add Reminder'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    for (var i = 0; i < _reminders.length; i++)
                      Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          dense: true,
                          leading: const Icon(Icons.notifications_none, size: 18),
                          title: Text(
                            _reminders[i].triggerTime != null
                                ? '${_reminders[i].triggerTime!.hour.toString().padLeft(2, '0')}:${_reminders[i].triggerTime!.minute.toString().padLeft(2, '0')}'
                                : 'No time set',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                            onPressed: () => setState(() => _reminders.removeAt(i)),
                          ),
                          onTap: () => _editReminder(i),
                        ),
                      ),
                  ],

                  if (_type == OrganizerType.value) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Statement',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _statementController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'What does this value mean to you?',
                        hintText: 'e.g., "I value honesty because it builds trust"',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ],

                  const SizedBox(height: 24),
                  const Text(
                    'Vincular Organizadores',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: OrganizerSelectorField(
                      selectedOrganizers: _organizers,
                      onChanged: (val) => setState(() => _organizers = val),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _saveOrganizer() {
    // If type is routine, redirect to routine-specific form
    if (_type == OrganizerType.routine) {
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CreateRoutineForm(
            existingRoutine: widget.organizer as Routine?,
          ),
        ),
      );
      return;
    }

    final existing = widget.organizer;
    final organizer = Organizer(
      id: existing?.id,
      title: _titleController.text.trim(),
      organizerType: _type,
      color: _selectedColor,
      parentId: _parentId,
      startDate: existing?.startDate,
      endDate: existing?.endDate,
      icon: existing?.icon,
      statement: _statementController.text.trim().isEmpty ? null : _statementController.text.trim(),
      organizers: _organizers,
      daysOfWeek: _daysOfWeek,
      timeRanges: _timeRanges,
      energyLevel: _energyLevel,
      scheduler: _scheduler,
      reminders: _reminders,
      categories: existing?.categories,
      createdAt: existing?.createdAt,
      obsidianPath: existing?.obsidianPath ?? '',
    );

    if (existing == null) {
      ref.read(organizersProvider.notifier).addOrganizer(organizer);
    } else {
      ref.read(organizersProvider.notifier).updateOrganizer(organizer);
    }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Organizador "${organizer.title}" salvo com sucesso!'),
      ),
    );
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceAll('#', '0xFF')));
    } catch (_) {
      return AppTheme.accentColor(context);
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
      setState(() => _scheduler = result);
    }
  }

  void _addReminder() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time != null) {
      final now = DateTime.now();
      final triggerTime = DateTime(now.year, now.month, now.day, time.hour, time.minute);
      setState(() {
        _reminders.add(
          ReminderConfig(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            triggerTime: triggerTime,
            type: NotificationType.push,
          ),
        );
      });
    }
  }

  void _editReminder(int index) async {
    final existing = _reminders[index];
    final initialTime = existing.triggerTime != null
        ? TimeOfDay(hour: existing.triggerTime!.hour, minute: existing.triggerTime!.minute)
        : TimeOfDay.now();
    final time = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (time != null) {
      final now = DateTime.now();
      final triggerTime = DateTime(now.year, now.month, now.day, time.hour, time.minute);
      setState(() {
        _reminders[index] = existing.copyWith(triggerTime: triggerTime);
      });
    }
  }
}

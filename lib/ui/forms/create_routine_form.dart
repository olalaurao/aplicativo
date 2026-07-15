import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/routine_model.dart';
import '../../models/organizer_model.dart';
import '../../models/shared_types.dart';
import '../../models/scheduler.dart';
import '../../models/reminder_config.dart';
import '../../models/content_object.dart';
import '../../providers/vault_provider.dart';
import '../theme.dart';
import '../widgets/universal_search_picker.dart';
import '../widgets/reminder_config_sheet.dart';
import 'scheduler_picker.dart';

class CreateRoutineForm extends ConsumerStatefulWidget {
  final Routine? existingRoutine;
  const CreateRoutineForm({super.key, this.existingRoutine});

  @override
  ConsumerState<CreateRoutineForm> createState() => _CreateRoutineFormState();
}

class _CreateRoutineFormState extends ConsumerState<CreateRoutineForm> {
  final _titleController = TextEditingController();
  String _selectedColor = '#3B82F6';
  String? _parentId;
  List<RoutineItem> _items = [];
  bool _showInPlanner = true;
  String? _moodTrigger;
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

  static const _moodTriggers = [
    'meltdown',
    'anxious',
    'stressed',
    'sad',
    'overwhelmed',
    'tired',
  ];

  @override
  void initState() {
    super.initState();
    final routine = widget.existingRoutine;
    if (routine != null) {
      _titleController.text = routine.title;
      _selectedColor = routine.color ?? _selectedColor;
      _parentId = routine.parentId;
      _items = List.from(routine.items);
      _showInPlanner = routine.showInPlanner;
      _moodTrigger = routine.moodTrigger;
      _scheduler = routine.scheduler;
      _reminders = List.from(routine.reminders);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
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
              widget.existingRoutine == null
                  ? 'New Routine'
                  : 'Edit Routine',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            centerTitle: true,
            actions: [
              TextButton(
                onPressed: hasTitle ? _saveRoutine : null,
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
                      hintText: 'Routine Title',
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
                    'Color',
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
                    'Show in Planner',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: _showInPlanner,
                    onChanged: (v) => setState(() => _showInPlanner = v),
                    title: const Text('Display in planner when scheduled'),
                    contentPadding: EdgeInsets.zero,
                  ),

                  const SizedBox(height: 24),
                  const Text(
                    'Mood Trigger (Optional)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: _moodTrigger,
                        isExpanded: true,
                        hint: const Text('No mood trigger'),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('No mood trigger'),
                          ),
                          ..._moodTriggers.map(
                            (mood) => DropdownMenuItem<String?>(
                              value: mood,
                              child: Text(mood[0].toUpperCase() + mood.substring(1)),
                            ),
                          ),
                        ],
                        onChanged: (val) => setState(() => _moodTrigger = val),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
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

                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Routine Items',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      TextButton(
                        onPressed: _addItem,
                        child: const Text('+ Add Item'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No items added yet. Tap "+ Add Item" to include tasks, habits, or other objects.',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    )
                  else
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _items.length,
                      onReorder: (oldIndex, newIndex) {
                        setState(() {
                          if (newIndex > oldIndex) newIndex--;
                          final item = _items.removeAt(oldIndex);
                          _items.insert(newIndex, item);
                          // Update order values
                          for (int i = 0; i < _items.length; i++) {
                            _items[i] = _items[i].copyWith(order: i);
                          }
                        });
                      },
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return Card(
                          key: ValueKey(item.id),
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            dense: true,
                            leading: const Icon(Icons.drag_handle, size: 18),
                            title: Text(
                              _getObjectTitle(item.referencedObjectId),
                              style: const TextStyle(fontSize: 14),
                            ),
                            subtitle: Text(
                              item.referencedObjectId,
                              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    item.required ? Icons.star : Icons.star_border,
                                    size: 18,
                                    color: item.required ? AppColors.warning : AppColors.textMuted,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _items[index] = item.copyWith(required: !item.required);
                                    });
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                                  onPressed: () {
                                    setState(() => _items.removeAt(index));
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

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
                  // TODO: Add OrganizerSelectorField when available
                  const Text(
                    'Organizer selection coming soon',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
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

  String _getObjectTitle(String wikiLink) {
    // Extract title from WikiLink [[title]] or [[title|alias]]
    final match = RegExp(r'\[\[([^\]|]+)(?:\|[^\]]+)?\]\]').firstMatch(wikiLink);
    if (match != null) {
      return match.group(1) ?? wikiLink;
    }
    return wikiLink;
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

  void _addItem() async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UniversalSearchPickerSheet(
        title: 'Select item',
        onSelected: (obj) => Navigator.pop(context, obj),
      ),
    );
    if (result != null) {
      final wikiLink = '[[${result.id}]]';
      setState(() {
        _items.add(RoutineItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          referencedObjectId: wikiLink,
          order: _items.length,
        ));
      });
    }
  }

  void _saveRoutine() {
    final existing = widget.existingRoutine;
    final routine = Routine(
      id: existing?.id,
      title: _titleController.text.trim(),
      items: _items,
      executionHistory: existing?.executionHistory ?? [],
      showInPlanner: _showInPlanner,
      moodTrigger: _moodTrigger,
      parentId: _parentId,
      color: _selectedColor,
      scheduler: _scheduler,
      reminders: _reminders,
      organizers: existing?.organizers ?? [],
      categories: existing?.categories,
      createdAt: existing?.createdAt,
      obsidianPath: existing?.obsidianPath ?? 'organizers/routines/',
    );

    if (existing == null) {
      ref.read(vaultProvider.notifier).createObject(routine);
    } else {
      ref.read(vaultProvider.notifier).updateObject(routine);
    }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Routine "${routine.title}" saved successfully!'),
      ),
    );
  }
}

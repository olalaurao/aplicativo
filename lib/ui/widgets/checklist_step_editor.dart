import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/checklist_step.dart';
import '../../models/content_object.dart';
import '../../models/reminder_config.dart';
import '../../providers/vault_provider.dart';
import '../theme.dart';
import 'collection_item_picker_sheet.dart';
import 'universal_search_picker.dart';

/// Reusable checklist step editor widget
class ChecklistStepEditor extends StatefulWidget {
  final ChecklistStep step;
  final int index;
  final Function(String) onChanged;
  final VoidCallback onRemove;
  final Function(ChecklistStep) onStepChanged;

  const ChecklistStepEditor({
    super.key,
    required this.step,
    required this.index,
    required this.onChanged,
    required this.onRemove,
    required this.onStepChanged,
  });

  @override
  State<ChecklistStepEditor> createState() => _ChecklistStepEditorState();
}

class _ChecklistStepEditorState extends State<ChecklistStepEditor> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.step.title);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ReorderableDragStartListener(
                index: widget.index,
                child: const Icon(Icons.drag_handle_rounded, color: AppColors.textMuted, size: 20),
              ),
              const SizedBox(width: 12),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.textMuted, width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${widget.index + 1}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  onChanged: widget.onChanged,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Describe step...',
                    hintStyle: TextStyle(color: AppTheme.textMutedColor(context), fontSize: 14),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.textMuted),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: widget.onRemove,
              ),
            ],
          ),
          // Kind selector
          Padding(
            padding: const EdgeInsets.only(left: 48, top: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'plain',
                    label: Text('Reminder'),
                  ),
                  ButtonSegment(
                    value: 'habit',
                    label: Text('Habit'),
                  ),
                  ButtonSegment(
                    value: 'task',
                    label: Text('Task'),
                  ),
                  ButtonSegment(
                    value: 'tracker_entry',
                    label: Text('Tracker'),
                  ),
                  ButtonSegment(
                    value: 'pomodoro',
                    label: Text('Pomodoro'),
                  ),
                ],
                selected: {widget.step.kind},
                onSelectionChanged: (Set<String> selected) {
                  widget.onStepChanged(widget.step.copyWith(kind: selected.first));
                },
              ),
            ),
          ),
          // Reminder config for plain kind
          if (widget.step.kind == 'plain')
            Padding(
              padding: const EdgeInsets.only(left: 48, top: 8),
              child: TextButton(
                onPressed: () async {
                  final config = await showDialog<ReminderConfig>(
                    context: context,
                    builder: (context) => _ReminderConfigDialog(
                      initialConfig: widget.step.reminderConfig,
                    ),
                  );
                  if (config != null) {
                    widget.onStepChanged(widget.step.copyWith(reminderConfig: config));
                  }
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.step.reminderConfig != null 
                          ? Icons.notifications_active 
                          : Icons.notifications_none,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        widget.step.reminderConfig != null
                            ? 'Reminder: ${widget.step.reminderConfig!.type.name}'
                            : 'Add reminder notification',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Object picker for non-plain kinds
          if (widget.step.kind != 'plain')
            Padding(
              padding: const EdgeInsets.only(left: 48, top: 8),
              child: Consumer(
                builder: (context, ref, child) {
                  return TextButton(
                    onPressed: () async {
                      final selected = await showModalBottomSheet<ContentObject>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => UniversalSearchPickerSheet(
                          title: 'Select ${widget.step.kind}',
                          initialFilter: widget.step.kind == 'tracker_entry' ? 'tracker' : widget.step.kind,
                          showClear: widget.step.kind == 'task',
                          onSelected: (obj) => Navigator.pop(context, obj),
                        ),
                      );
                      if (selected != null) {
                        widget.onStepChanged(widget.step.copyWith(linkedObjectSlug: selected.slug));
                      }
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.step.linkedObjectSlug != null 
                              ? Icons.check_circle_rounded 
                              : Icons.add_circle_outline_rounded,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            widget.step.linkedObjectSlug != null
                                ? 'Linked: ${widget.step.linkedObjectSlug}'
                                : 'Link ${widget.step.kind}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          // Tracker field picker for tracker_entry kind
          if (widget.step.kind == 'tracker_entry' && widget.step.linkedObjectSlug != null)
            Padding(
              padding: const EdgeInsets.only(left: 48, top: 8),
              child: Consumer(
                builder: (context, ref, child) {
                  return TextButton(
                    onPressed: () async {
                      // Show tracker field picker
                      final trackers = ref.read(trackersProvider);
                      final tracker = trackers.where((t) => t.slug == widget.step.linkedObjectSlug).firstOrNull;
                      if (tracker == null) return;

                      final fields = tracker.sections.expand((s) => s.inputFields).toList();
                      final selected = await showDialog<String>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Select Field'),
                          content: SizedBox(
                            width: double.maxFinite,
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: fields.length,
                              itemBuilder: (ctx, i) => ListTile(
                                title: Text(fields[i].title),
                                onTap: () => Navigator.pop(ctx, fields[i].id),
                              ),
                            ),
                          ),
                        ),
                      );
                      if (selected != null) {
                        widget.onStepChanged(widget.step.copyWith(trackerFieldId: selected));
                      }
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.step.trackerFieldId != null 
                              ? Icons.check_circle_rounded 
                              : Icons.add_circle_outline_rounded,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            widget.step.trackerFieldId != null
                                ? 'Field selected'
                                : 'Select tracker field',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          // Collection attachment for habit and tracker_entry kinds
          if (widget.step.kind == 'habit' || widget.step.kind == 'tracker_entry')
            Padding(
              padding: const EdgeInsets.only(left: 48, top: 8),
              child: TextButton(
                onPressed: () async {
                  final pickedRef = await CollectionItemPickerSheet.show(
                    context,
                    collectionNoteSlug: widget.step.attachedCollectionSlug ?? '',
                  );
                  if (pickedRef != null) {
                    widget.onStepChanged(widget.step.copyWith(attachedCollectionSlug: pickedRef.noteSlug));
                  }
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.step.attachedCollectionSlug != null 
                          ? Icons.link_rounded 
                          : Icons.link_off_rounded,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        widget.step.attachedCollectionSlug != null
                            ? 'Collection attached'
                            : 'Attach collection',
                        overflow: TextOverflow.ellipsis,
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
}

class _ReminderConfigDialog extends StatefulWidget {
  final ReminderConfig? initialConfig;

  const _ReminderConfigDialog({this.initialConfig});

  @override
  State<_ReminderConfigDialog> createState() => _ReminderConfigDialogState();
}

class _ReminderConfigDialogState extends State<_ReminderConfigDialog> {
  late NotificationType _type;
  late int _minutesBefore;

  @override
  void initState() {
    super.initState();
    _type = widget.initialConfig?.type ?? NotificationType.push;
    _minutesBefore = widget.initialConfig?.minutesBefore ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reminder Config'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SegmentedButton<NotificationType>(
            segments: const [
              ButtonSegment(value: NotificationType.push, label: Text('Notification')),
              ButtonSegment(value: NotificationType.alarm, label: Text('Alarm')),
            ],
            selected: {_type},
            onSelectionChanged: (Set<NotificationType> selected) {
              setState(() => _type = selected.first);
            },
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Minutes before',
            ),
            onChanged: (value) => _minutesBefore = int.tryParse(value) ?? 0,
            controller: TextEditingController(text: _minutesBefore.toString()),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(
              context,
              ReminderConfig(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                type: _type,
                minutesBefore: _minutesBefore,
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

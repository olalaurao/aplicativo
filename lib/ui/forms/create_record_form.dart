// lib/ui/forms/create_record_form.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../models/tracker_model.dart';
import '../../models/note_model.dart';
import '../../models/shared_types.dart';
import '../../providers/vault_provider.dart';
import '../theme.dart';
import '../widgets/date_picker_field.dart';

class CreateRecordForm extends ConsumerStatefulWidget {
  final TrackerDefinition? tracker;
  const CreateRecordForm({super.key, this.tracker});

  @override
  ConsumerState<CreateRecordForm> createState() => _CreateRecordFormState();
}

class _CreateRecordFormState extends ConsumerState<CreateRecordForm> {
  TrackerDefinition? _selectedTracker;
  final Map<String, dynamic> _values = {};
  DateTime _date = DateTime.now();
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _selectedTracker = widget.tracker;
    if (_selectedTracker != null) {
      _initializeValues();
    }
  }

  void _initializeValues() {
    _values.clear();
    for (final section in _selectedTracker!.sections) {
      for (var field in section.inputFields) {
        _values[field.id] = field.defaultValue;
      }
    }
  }

  List<String> _getCollectionOptions(String collectionSlug) {
    final notes = ref.read(notesProvider);
    final collection = notes.where((n) => n.slug == collectionSlug).firstOrNull;
    if (collection == null || collection.subtype != NoteSubtype.collection) {
      return [];
    }

    try {
      final data = jsonDecode(collection.body);
      final items = data is Map ? data['items'] : null;
      if (items is! List) return [];

      final options = <String>[];
      for (final item in items) {
        if (item is Map) {
          // Find first text/richText property value
          for (final entry in item.entries) {
            final value = entry.value;
            if (value is String && value.trim().isNotEmpty) {
              options.add(value.trim());
              break;
            }
          }
        }
      }
      return options;
    } catch (e) {
      debugPrint('Error parsing Collection options: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final trackers = ref.watch(trackersProvider);

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
              _selectedTracker != null
                  ? 'Log ${_selectedTracker!.title}'
                  : 'New Record',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            centerTitle: true,
          ),

          if (_selectedTracker == null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select Tracker',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...trackers.map(
                      (t) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _parseColor(t.color).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.show_chart_rounded,
                            color: _parseColor(t.color),
                            size: 20,
                          ),
                        ),
                        title: Text(
                          t.title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                        ),
                        onTap: () => setState(() {
                          _selectedTracker = t;
                          _initializeValues();
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // ─── Header Information ───
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Row(
                  children: [
                    DatePickerField(
                      label: 'Date',
                      selectedDate: _date,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 365),
                      ),
                      lastDate: DateTime.now(),
                      onDateChanged: (d) {
                        if (d != null) setState(() => _date = d);
                      },
                    ),
                  ],
                ),
              ),
            ),

            // ─── Dynamic Fields ───
            ..._buildDynamicFields(),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ],
      ),
      bottomNavigationBar: _selectedTracker != null
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: _saveRecord,
                    style: FilledButton.styleFrom(
                      backgroundColor: _parseColor(_selectedTracker!.color),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Save Record',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  List<Widget> _buildDynamicFields() {
    final widgets = <Widget>[];
    for (var section in _selectedTracker!.sections) {
      if (section.title.isNotEmpty) {
        widgets.add(
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Text(
                section.title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        );
      }

      widgets.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: AppTheme.cardDecoration(context),
              padding: const EdgeInsets.all(4),
              child: Column(
                children: section.inputFields
                    .map((field) => _buildField(field))
                    .toList(),
              ),
            ),
          ),
        ),
      );
    }
    return widgets;
  }

  Widget _buildField(InputField field) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          field.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _showFieldHistory(field),
                          child: const Icon(
                            Icons.history_rounded,
                            size: 14,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () =>
                              _editFieldSettings(field), // Quick config edit
                          child: const Icon(
                            Icons.settings_outlined,
                            size: 14,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    if (field.unit != null)
                      Text(
                        field.unit!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _buildInputControl(field),
            ],
          ),
        ),
        if (!_isLastField(field))
          const Divider(height: 1, indent: 12, endIndent: 12),
      ],
    );
  }

  Widget _buildInputControl(InputField field) {
    switch (field.type) {
      case InputFieldType.quantity:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _stepperButton(Icons.remove, () {
              setState(() {
                final val = _asDouble(_values[field.id]);
                _values[field.id] = val - 1.0;
              });
            }),
            Container(
              width: 60,
              alignment: Alignment.center,
              child: Text(
                (_values[field.id] ?? 0.0).toString(),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            _stepperButton(Icons.add, () {
              setState(() {
                final val = _asDouble(_values[field.id]);
                _values[field.id] = val + 1.0;
              });
            }),
          ],
        );
      case InputFieldType.checkbox:
        return Switch(
          value: _values[field.id] is bool ? _values[field.id] as bool : false,
          onChanged: (v) => setState(() => _values[field.id] = v),
          activeThumbColor: _parseColor(_selectedTracker!.color),
        );
      case InputFieldType.range:
        final rawMin = field.min ?? 0.0;
        final rawMax = field.max ?? 10.0;
        final min = rawMin <= rawMax ? rawMin : rawMax;
        final max = rawMax >= rawMin ? rawMax : rawMin;
        final value = _asDouble(
          _values[field.id] ?? min,
        ).clamp(min, max).toDouble();
        final divisions = (max - min).round();
        return Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions > 0 ? divisions : null,
            label: _asDouble(_values[field.id] ?? min).toString(),
            activeColor: _parseColor(_selectedTracker!.color),
            onChanged: (v) => setState(() => _values[field.id] = v),
          ),
        );
      case InputFieldType.mood:
        final moods = ['😞', '😕', '😐', '🙂', '😄'];
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: moods.asMap().entries.map((entry) {
            final idx = entry.key;
            final selected = (_values[field.id] ?? 2) == idx;
            return GestureDetector(
              onTap: () => setState(() => _values[field.id] = idx),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Opacity(
                  opacity: selected ? 1.0 : 0.4,
                  child: Text(
                    entry.value,
                    style: TextStyle(fontSize: selected ? 24 : 18),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      case InputFieldType.text:
        return Expanded(
          child: TextField(
            onChanged: (v) => _values[field.id] = v,
            minLines: 1,
            maxLines: 4,
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'Digite...',
              border: InputBorder.none,
            ),
            textAlign: TextAlign.right,
          ),
        );
      case InputFieldType.selection:
        final options = field.optionsSourceCollectionSlug != null
            ? _getCollectionOptions(field.optionsSourceCollectionSlug!)
            : (field.options ?? const <String>[]);
        final rawValue = _values[field.id];
        final selectedValue = rawValue is String && options.contains(rawValue)
            ? rawValue
            : null;
        return DropdownButton<String>(
          value: selectedValue,
          hint: const Text('Select...'),
          items: options
              .map((o) => DropdownMenuItem(value: o, child: Text(o)))
              .toList(),
          onChanged: (v) => setState(() => _values[field.id] = v),
          underline: const SizedBox(),
        );
      case InputFieldType.checklist:
        final checklistOptions = field.optionsSourceCollectionSlug != null
            ? _getCollectionOptions(field.optionsSourceCollectionSlug!)
            : (field.options ?? []);
        return Expanded(
          child: Wrap(
            spacing: 8,
            children: checklistOptions.map((opt) {
              final selected = ((_values[field.id] as List?) ?? []).contains(
                opt,
              );
              return ChoiceChip(
                label: Text(opt),
                selected: selected,
                onSelected: (val) {
                  setState(() {
                    final list = List<String>.from(
                      (_values[field.id] as List?) ?? [],
                    );
                    if (val) {
                      list.add(opt);
                    } else {
                      list.remove(opt);
                    }
                    _values[field.id] = list;
                  });
                },
              );
            }).toList(),
          ),
        );
      case InputFieldType.duration:
        return Expanded(
          child: TextField(
            onChanged: (v) => _values[field.id] = v,
            keyboardType: TextInputType.datetime,
            decoration: const InputDecoration(
              isDense: true,
              hintText: '00:00',
              border: InputBorder.none,
            ),
            textAlign: TextAlign.right,
          ),
        );
      case InputFieldType.media:
        final mediaValue = _values[field.id];
        final hasMedia = mediaValue is Map && mediaValue['path'] != null;
        return IconButton(
          tooltip: hasMedia ? mediaValue['path'].toString() : 'Add media',
          icon: Icon(
            hasMedia ? Icons.attachment_rounded : Icons.add_a_photo_outlined,
            color: hasMedia ? _parseColor(_selectedTracker!.color) : null,
          ),
          onPressed: () => _pickMedia(field),
        );
    }
  }

  bool _isLastField(InputField field) {
    final sections = _selectedTracker?.sections;
    if (sections == null) return true;

    for (final section in sections.reversed) {
      if (section.inputFields.isEmpty) continue;
      return identical(section.inputFields.last, field);
    }
    return true;
  }

  void _editFieldSettings(InputField field) {
    final unitController = TextEditingController(text: field.unit);
    final optionsController = TextEditingController(
      text: field.options?.join(', '),
    );
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Configure ${field.title}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              if (field.type == InputFieldType.quantity ||
                  field.type == InputFieldType.range ||
                  field.type == InputFieldType.duration)
                TextField(
                  controller: unitController,
                  decoration: const InputDecoration(labelText: 'Unidade'),
                ),
              if (field.type == InputFieldType.selection ||
                  field.type == InputFieldType.checklist)
                TextField(
                  controller: optionsController,
                  decoration: const InputDecoration(
                    labelText: 'Options (comma-separated)',
                  ),
                ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  field.unit = unitController.text.trim().isEmpty
                      ? null
                      : unitController.text.trim();
                  field.options = optionsController.text
                      .split(',')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList();
                  await ref
                      .read(trackersProvider.notifier)
                      .updateTracker(_selectedTracker!);
                  if (!ctx.mounted) return;
                  setState(() {});
                  Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${field.title} settings saved')),
                    );
                  }
                },
                child: const Text('OK'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showFieldHistory(InputField field) async {
    final tracker = _selectedTracker;
    if (tracker == null) return;

    final records =
        ref
            .read(trackingRecordsProvider)
            .where(
              (record) =>
                  (record.trackerId == tracker.id ||
                      record.trackerId == tracker.slug ||
                      record.trackerId == tracker.title) &&
                  record.fieldValues.containsKey(field.id) &&
                  record.fieldValues[field.id] != null,
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));

    await showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.5,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${field.title} history',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              if (records.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text(
                      'No previous values',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: records.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final record = records[index];
                      final value = record.fieldValues[field.id];
                      return ListTile(
                        title: Text(_formatFieldValue(value)),
                        subtitle: Text(
                          DateFormat('MMM d, yyyy HH:mm').format(record.date),
                        ),
                        trailing: const Icon(
                          Icons.content_copy_rounded,
                          size: 18,
                        ),
                        onTap: () {
                          setState(() => _values[field.id] = value);
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickMedia(InputField field) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Photo Library'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await _imagePicker.pickImage(source: source);
    if (picked == null) return;

    final path = await ref
        .read(obsidianServiceProvider)
        .saveAttachment(File(picked.path));
    if (path == null) return;

    setState(() {
      _values[field.id] = {'type': 'image', 'path': path, 'name': picked.name};
    });
  }

  Widget _stepperButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: AppColors.textPrimary),
      ),
    );
  }

  void _saveRecord() async {
    if (_selectedTracker == null) return;

    await saveTrackerRecord(ref, _selectedTracker!, _date, _values);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Record saved')));
    }
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceAll('#', '0xFF')));
    } catch (_) {
      return AppTheme.accentColor(context);
    }
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  String _formatFieldValue(dynamic value) {
    if (value is Map && value['path'] != null) return value['path'].toString();
    if (value is List) return value.join(', ');
    return value?.toString() ?? '';
  }
}

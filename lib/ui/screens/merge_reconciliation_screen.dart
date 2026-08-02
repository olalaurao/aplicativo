// lib/ui/screens/merge_reconciliation_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/content_object.dart';
import '../../models/task_model.dart';
import '../../models/habit_model.dart';
import '../../models/goal_model.dart';
import '../../models/note_model.dart';
import '../../models/event_model.dart';
import '../../models/project_model.dart';
import '../theme.dart';

class MergeReconciliationScreen extends ConsumerStatefulWidget {
  final List<ContentObject> selectedObjects;
  final String targetType;

  const MergeReconciliationScreen({
    super.key,
    required this.selectedObjects,
    required this.targetType,
  });

  @override
  ConsumerState<MergeReconciliationScreen> createState() =>
      _MergeReconciliationScreenState();
}

class _MergeReconciliationScreenState
    extends ConsumerState<MergeReconciliationScreen> {
  final Map<String, dynamic> _reconciledFields = {};
  bool _droppedFieldsAcknowledged = false;
  final Set<String> _requiredFields = {
    'title', // All content objects require title
  };

  // Add type-specific required fields based on actual model serialization
  final Map<String, Set<String>> _typeRequiredFields = {
    'task': {'stage', 'priority'}, // Both are serialized in Task.toMarkdown()
    'habit': {'color'},
    'goal': {'state', 'goalType'},
    'event': {'date', 'duration'},
    'project': {'state'},
  };

  @override
  void initState() {
    super.initState();
    _initializeReconciledFields();
  }

  void _initializeReconciledFields() {
    // Find the object with the latest updatedAt as default
    final latestObject = widget.selectedObjects.reduce((a, b) =>
        a.updatedAt.isAfter(b.updatedAt) ? a : b);

    // Initialize with the latest object's values
    _reconciledFields.addAll(_extractFields(latestObject));
  }

  Map<String, dynamic> _extractFields(ContentObject obj) {
    final fields = <String, dynamic>{};

    // Base ContentObject fields
    fields['title'] = obj.title;
    fields['categories'] = obj.categories;
    fields['tags'] = obj.tags;
    fields['aliases'] = obj.aliases;
    fields['archived'] = obj.archived;
    fields['pinned'] = obj.pinned;
    fields['order'] = obj.order;

    // Type-specific fields
    if (obj is Task) {
      fields['stage'] = obj.stage.name;
      fields['priority'] = obj.priority.name;
      fields['startDate'] = obj.startDate?.toIso8601String();
      fields['endDate'] = obj.endDate?.toIso8601String();
    } else if (obj is Habit) {
      fields['color'] = obj.color;
      // habitStatus might not exist, use default
      fields['habitStatus'] = 'active';
    } else if (obj is Goal) {
      fields['description'] = obj.description;
      fields['goalType'] = obj.goalType.name;
      // state might be a String, not an enum
      fields['state'] = obj.state ?? 'active';
    } else if (obj is Note) {
      fields['body'] = obj.body;
      fields['noteSubtype'] = obj.subtype.name;
    } else if (obj is Event) {
      fields['date'] = obj.date.toIso8601String();
      fields['duration'] = obj.duration;
      fields['timeOfDay'] = obj.timeOfDay;
    } else if (obj is Project) {
      fields['description'] = obj.description;
      // state might be a String, not an enum
      fields['state'] = obj.state ?? 'active';
    }

    return fields;
  }

  List<String> _getDroppedFields() {
    // Fields that will be dropped when merging to target type
    final allFields = <String>{};
    final targetFields = _getTargetTypeFields();

    // Collect all fields from source objects
    for (final obj in widget.selectedObjects) {
      allFields.addAll(_extractFields(obj).keys);
    }

    // Return fields that are not in target type
    return allFields.where((field) => !targetFields.contains(field)).toList();
  }

  Set<String> _getTargetTypeFields() {
    // Return fields that are valid for the target type
    final baseFields = {
      'title', 'categories', 'tags', 'aliases', 'archived', 'pinned', 'order',
    };

    final typeSpecificFields = <String>{};
    switch (widget.targetType) {
      case 'task':
        typeSpecificFields.addAll(['stage', 'priority', 'startDate', 'endDate']);
        break;
      case 'habit':
        typeSpecificFields.addAll(['color', 'habitStatus']);
        break;
      case 'goal':
        typeSpecificFields.addAll(['description', 'goalType', 'state']);
        break;
      case 'note':
        typeSpecificFields.addAll(['body', 'noteSubtype']);
        break;
      case 'event':
        typeSpecificFields.addAll(['date', 'duration', 'timeOfDay']);
        break;
      case 'project':
        typeSpecificFields.addAll(['description', 'state']);
        break;
    }

    return {...baseFields, ...typeSpecificFields};
  }

  bool _isFieldRequired(String fieldName) {
    final typeRequired = _typeRequiredFields[widget.targetType] ?? <String>{};
    return _requiredFields.contains(fieldName) || typeRequired.contains(fieldName);
  }

  dynamic _extractFieldValue(ContentObject obj, String fieldName) {
    switch (fieldName) {
      case 'title':
        return obj.title;
      case 'categories':
        return obj.categories;
      case 'tags':
        return obj.tags;
      case 'aliases':
        return obj.aliases;
      case 'archived':
        return obj.archived;
      case 'pinned':
        return obj.pinned;
      case 'order':
        return obj.order;
      case 'stage':
        if (obj is Task) return obj.stage.name;
        break;
      case 'priority':
        if (obj is Task) return obj.priority.name;
        break;
      case 'startDate':
        if (obj is Task) return obj.startDate?.toIso8601String();
        break;
      case 'endDate':
        if (obj is Task) return obj.endDate?.toIso8601String();
        break;
      case 'color':
        if (obj is Habit) return obj.color;
        break;
      case 'habitStatus':
        if (obj is Habit) return 'active'; // Default since habitStatus might not exist
        break;
      case 'description':
        if (obj is Goal) return obj.description;
        if (obj is Project) return obj.description;
        break;
      case 'goalType':
        if (obj is Goal) return obj.goalType.name;
        break;
      case 'state':
        if (obj is Goal) return obj.state ?? 'active'; // Might be String, not enum
        if (obj is Project) return obj.state ?? 'active'; // Might be String, not enum
        break;
      case 'body':
        if (obj is Note) return obj.body;
        break;
      case 'noteSubtype':
        if (obj is Note) return obj.subtype.name;
        break;
      case 'date':
        if (obj is Event) return obj.date.toIso8601String();
        break;
      case 'duration':
        if (obj is Event) return obj.duration;
        break;
      case 'timeOfDay':
        if (obj is Event) return obj.timeOfDay;
        break;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final droppedFields = _getDroppedFields();
    final targetFields = _getTargetTypeFields();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Reconcile Properties'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          TextButton(
            onPressed: droppedFields.isEmpty || _droppedFieldsAcknowledged
                ? () => Navigator.pop(context, _reconciledFields)
                : null,
            child: Text(
              'Continue',
              style: TextStyle(
                color: droppedFields.isEmpty || _droppedFieldsAcknowledged
                    ? AppTheme.accentColor(context)
                    : AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildSectionHeader('Target Properties'),
                  const SizedBox(height: 16),
                  ...targetFields.map((field) => _buildFieldCard(field)),
                  if (droppedFields.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    _buildSectionHeader('Fields That Will Be Dropped'),
                    const SizedBox(height: 16),
                    _buildDroppedFieldsSection(droppedFields),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textMuted,
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildFieldCard(String fieldName) {
    final isRequired = _isFieldRequired(fieldName);
    final currentValue = _reconciledFields[fieldName];
    
    // Get all values for this field from selected objects
    final fieldValues = <String, dynamic>{};
    for (final obj in widget.selectedObjects) {
      final value = _extractFieldValue(obj, fieldName);
      if (value != null) {
        final valueKey = value.toString();
        if (!fieldValues.containsKey(valueKey)) {
          fieldValues[valueKey] = value;
        }
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          if (fieldValues.length > 1) {
            _showFieldSelector(context, fieldName, fieldValues);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _formatFieldName(fieldName),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimaryColor(context),
                          ),
                        ),
                        if (isRequired) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Required',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatFieldValue(currentValue),
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (fieldValues.length > 1)
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFieldSelector(BuildContext context, String fieldName, Map<String, dynamic> values) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select value for ${_formatFieldName(fieldName)}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryColor(context),
              ),
            ),
            const SizedBox(height: 16),
            ...values.entries.map((entry) => ListTile(
              title: Text(_formatFieldValue(entry.value)),
              trailing: _reconciledFields[fieldName].toString() == entry.key
                  ? Icon(Icons.check_circle, color: AppTheme.accentColor(context))
                  : null,
              onTap: () {
                setState(() {
                  _reconciledFields[fieldName] = entry.value;
                });
                Navigator.pop(context);
              },
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildDroppedFieldsSection(List<String> droppedFields) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: AppColors.warning,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'These fields will be lost',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...droppedFields.map((field) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Text('• ', style: TextStyle(color: AppColors.warning)),
                    Text(
                      _formatFieldName(field),
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 16),
          Row(
            children: [
              Checkbox(
                value: _droppedFieldsAcknowledged,
                onChanged: (value) {
                  setState(() {
                    _droppedFieldsAcknowledged = value ?? false;
                  });
                },
              ),
              Expanded(
                child: Text(
                  'I understand these fields will be permanently deleted',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatFieldName(String fieldName) {
    // Convert field_name to Field Name
    return fieldName.split('_').map((word) {
      final first = word[0].toUpperCase();
      final rest = word.substring(1);
      return '$first$rest';
    }).join(' ');
  }

  String _formatFieldValue(dynamic value) {
    if (value == null) return 'Not set';
    if (value is List) {
      return value.join(', ');
    }
    return value.toString();
  }
}
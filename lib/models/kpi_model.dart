// lib/models/kpi_model.dart

enum KPISourceType {
  subtasks,
  trackerField,
  habit,
  collection,
  entry,
  timeSpent,
  manualQuantity,
  others,
}

enum KPIDisplayType { number, percentage, progressBar }

extension KPISourceTypeLabel on KPISourceType {
  String get label {
    switch (this) {
      case KPISourceType.subtasks:
        return 'Subtarefas Completas';
      case KPISourceType.trackerField:
        return 'Campo do Tracker';
      case KPISourceType.habit:
        return 'Hábito';
      case KPISourceType.collection:
        return 'Coleção de Itens';
      case KPISourceType.entry:
        return 'Mencionados/Diários';
      case KPISourceType.timeSpent:
        return 'Tempo Dedicado';
      case KPISourceType.manualQuantity:
        return 'Quantidade Manual';
      case KPISourceType.others:
        return 'Outros Indicadores';
    }
  }
}

class KPI {
  String id;
  String title;
  KPISourceType sourceType;
  String? calculationMode;
  String? sourceId; // Reference to specific Habit, Tracker, etc.
  String? fieldId; // For Trackers
  double targetValue;
  double currentValue;
  DateTime? startDate;
  DateTime? endDate;
  KPIDisplayType displayType;
  bool completed;
  Map<String, dynamic>? autoCompleteAction;

  KPI({
    required this.id,
    required this.title,
    required this.sourceType,
    this.calculationMode,
    this.sourceId,
    this.fieldId,
    this.targetValue = 100,
    this.currentValue = 0,
    this.startDate,
    this.endDate,
    this.displayType = KPIDisplayType.number,
    this.completed = false,
    this.autoCompleteAction,
  });

  Map<String, dynamic> toMap() {
    String toSnakeCase(String str) {
      return str.replaceAllMapped(
        RegExp(r'([A-Z])'),
        (match) => '_${match.group(1)!.toLowerCase()}',
      );
    }

    return {
      'id': id,
      'title': title,
      'source_type': toSnakeCase(sourceType.name),
      if (calculationMode != null) 'calculation_mode': calculationMode,
      'source_id': sourceId,
      'field_id': fieldId,
      'target_value': targetValue,
      'current_value': currentValue,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'display_type': displayType.name,
      'completed': completed,
      if (autoCompleteAction != null) 'auto_complete_action': autoCompleteAction,
    };
  }

  factory KPI.fromMap(Map<String, dynamic> map) {
    final rawSourceType = map['source_type']?.toString() ?? '';
    
    // Normalization mapping from 24 legacy values to the new 8 source types
    KPISourceType resolvedType = KPISourceType.others;
    String? resolvedCalcMode = map['calculation_mode']?.toString();

    final legacyKey = rawSourceType.replaceAllMapped(
      RegExp(r'_([a-z])'),
      (match) => match.group(1)!.toUpperCase(),
    );

    switch (legacyKey) {
      case 'habitCompletionCount':
        resolvedType = KPISourceType.habit;
        resolvedCalcMode = 'total_completions';
        break;
      case 'habitStreak':
        resolvedType = KPISourceType.habit;
        resolvedCalcMode = 'streak';
        break;
      case 'habitSuccessRate':
        resolvedType = KPISourceType.habit;
        resolvedCalcMode = 'success_rate';
        break;
      case 'trackerFieldSum':
        resolvedType = KPISourceType.trackerField;
        resolvedCalcMode = 'sum';
        break;
      case 'trackerFieldAverage':
        resolvedType = KPISourceType.trackerField;
        resolvedCalcMode = 'average';
        break;
      case 'trackerFieldMax':
        resolvedType = KPISourceType.trackerField;
        resolvedCalcMode = 'max';
        break;
      case 'trackerFieldMin':
        resolvedType = KPISourceType.trackerField;
        resolvedCalcMode = 'min';
        break;
      case 'trackerFieldLatest':
        resolvedType = KPISourceType.trackerField;
        resolvedCalcMode = 'latest';
        break;
      case 'entryCount':
        resolvedType = KPISourceType.entry;
        resolvedCalcMode = 'count';
        break;
      case 'journalWordCount':
        resolvedType = KPISourceType.entry;
        resolvedCalcMode = 'word_count';
        break;
      case 'plannerTaskCount':
        resolvedType = KPISourceType.others;
        resolvedCalcMode = 'planner_task_count';
        break;
      case 'plannerTaskDuration':
        resolvedType = KPISourceType.timeSpent;
        resolvedCalcMode = 'planner_task_duration';
        break;
      case 'plannerOverdueCount':
        resolvedType = KPISourceType.others;
        resolvedCalcMode = 'planner_overdue_count';
        break;
      case 'goalSubtaskCompletion':
        resolvedType = KPISourceType.subtasks;
        resolvedCalcMode = 'goal_subtasks';
        break;
      case 'goalProgressPercentage':
        resolvedType = KPISourceType.subtasks;
        resolvedCalcMode = 'goal_percentage';
        break;
      case 'customNumericInput':
      case 'manualQuantity':
        resolvedType = KPISourceType.manualQuantity;
        resolvedCalcMode = 'manual';
        break;
      case 'moodAverage':
        resolvedType = KPISourceType.others;
        resolvedCalcMode = 'mood_average';
        break;
      case 'moodTrend':
        resolvedType = KPISourceType.others;
        resolvedCalcMode = 'mood_trend';
        break;
      case 'photoCount':
        resolvedType = KPISourceType.others;
        resolvedCalcMode = 'photo_count';
        break;
      case 'commentCount':
        resolvedType = KPISourceType.others;
        resolvedCalcMode = 'comment_count';
        break;
      case 'reflectionLength':
        resolvedType = KPISourceType.others;
        resolvedCalcMode = 'reflection_length';
        break;
      case 'organizerAssociationCount':
        resolvedType = KPISourceType.others;
        resolvedCalcMode = 'organizer_association_count';
        break;
      case 'timeSpentInCategory':
        resolvedType = KPISourceType.timeSpent;
        resolvedCalcMode = 'category_duration';
        break;
      case 'collectionItemCount':
        resolvedType = KPISourceType.collection;
        resolvedCalcMode = 'count';
        break;
      default:
        // Try direct matching if it's already using the new names
        final normalized = rawSourceType.replaceAllMapped(
          RegExp(r'_([a-z])'),
          (match) => match.group(1)!.toUpperCase(),
        );
        resolvedType = KPISourceType.values.firstWhere(
          (e) => e.name == normalized,
          orElse: () => KPISourceType.others,
        );
        break;
    }

    return KPI(
      id: map['id'] as String,
      title: map['title'] as String,
      sourceType: resolvedType,
      calculationMode: resolvedCalcMode,
      sourceId: map['source_id'] as String?,
      fieldId: map['field_id'] as String?,
      targetValue: (map['target_value'] as num? ?? 100).toDouble(),
      currentValue: (map['current_value'] as num? ?? 0).toDouble(),
      startDate: map['start_date'] != null ? DateTime.parse(map['start_date']) : null,
      endDate: map['end_date'] != null ? DateTime.parse(map['end_date']) : null,
      displayType: KPIDisplayType.values.firstWhere(
        (e) => e.name == map['display_type'],
        orElse: () => KPIDisplayType.number,
      ),
      completed: map['completed'] as bool? ?? false,
      autoCompleteAction: map['auto_complete_action'] != null ? Map<String, dynamic>.from(map['auto_complete_action'] as Map) : null,
    );
  }
}

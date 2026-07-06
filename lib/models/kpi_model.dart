// lib/models/kpi_model.dart
import 'shared_types.dart';

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
  DataSourceReference dataSource;
  String? calculationMode;
  double targetValue;
  double currentValue;
  DateTime? startDate;
  DateTime? endDate;
  KPIDisplayType displayType;
  bool completed;
  bool autoComplete;
  Map<String, dynamic>? autoCompleteAction;

  KPI({
    required this.id,
    required this.title,
    KPISourceType sourceType = KPISourceType.manualQuantity,
    DataSourceReference? dataSource,
    this.calculationMode,
    String? sourceId,
    String? fieldId,
    String? dimension,
    Map<String, dynamic>? valueMapping,
    this.targetValue = 100,
    this.currentValue = 0,
    this.startDate,
    this.endDate,
    this.displayType = KPIDisplayType.number,
    this.completed = false,
    this.autoComplete = false,
    this.autoCompleteAction,
  }) : dataSource =
           dataSource ??
           DataSourceReference(
             sourceType: _toDataSourceType(sourceType, calculationMode),
             sourceId: _shouldOmitSourceId(sourceType) ? null : sourceId,
             fieldId: fieldId,
             dimension: dimension,
             valueMapping: valueMapping,
             aggregation:
                 _aggregationFromCalculationMode(calculationMode, sourceType),
           );

  KPISourceType get sourceType =>
      _toKPISourceType(dataSource.sourceType, calculationMode);
  String? get sourceId => dataSource.sourceId;
  String? get fieldId => dataSource.fieldId;
  String? get dimension => dataSource.dimension;
  Map<String, dynamic>? get valueMapping => dataSource.valueMapping;
  DataSourceAggregation? get aggregation => dataSource.aggregation;

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'id': id,
      'title': title,
      'data_source': dataSource.toMap(),
      'target_value': targetValue,
      'current_value': currentValue,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'display_type': displayType.name,
      'completed': completed,
      'auto_complete': autoComplete,
      if (autoCompleteAction != null) 'auto_complete_action': autoCompleteAction,
    };

    if (_requiresLegacyCalculationMode(calculationMode, sourceType)) {
      map['calculation_mode'] = calculationMode;
    }

    return map;
  }

  factory KPI.fromMap(Map<String, dynamic> map) {
    final resolvedCalcMode = map['calculation_mode']?.toString();
    final dataSource = map['data_source'] is Map
        ? DataSourceReference.fromMap(
            Map<String, dynamic>.from(map['data_source'] as Map),
          )
        : _legacyDataSourceFromFlatMap(map, resolvedCalcMode);

    return KPI(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      dataSource: dataSource,
      calculationMode: resolvedCalcMode,
      targetValue: (map['target_value'] as num? ?? 100).toDouble(),
      currentValue: (map['current_value'] as num? ?? 0).toDouble(),
      startDate: map['start_date'] != null ? DateTime.parse(map['start_date']) : null,
      endDate: map['end_date'] != null ? DateTime.parse(map['end_date']) : null,
      displayType: KPIDisplayType.values.firstWhere(
        (e) => e.name == map['display_type'],
        orElse: () => KPIDisplayType.number,
      ),
      completed: map['completed'] as bool? ?? false,
      autoComplete: map['auto_complete'] as bool? ?? false,
      autoCompleteAction: map['auto_complete_action'] != null ? Map<String, dynamic>.from(map['auto_complete_action'] as Map) : null,
    );
  }
}

DataSourceReference _legacyDataSourceFromFlatMap(
  Map<String, dynamic> map,
  String? calculationMode,
) {
  final rawSourceType = map['source_type']?.toString() ?? '';
  final resolvedType = _resolveLegacySourceType(rawSourceType, calculationMode);
  return DataSourceReference(
    sourceType: _toDataSourceType(resolvedType, calculationMode),
    sourceId: _shouldOmitSourceId(resolvedType)
        ? null
        : map['source_id']?.toString(),
    fieldId: map['field_id']?.toString(),
    dimension: _dimensionFromLegacy(resolvedType, calculationMode, map),
    valueMapping: map['value_mapping'] is Map
        ? Map<String, dynamic>.from(map['value_mapping'] as Map)
        : null,
    aggregation: _aggregationFromCalculationMode(calculationMode, resolvedType),
  );
}

KPISourceType _resolveLegacySourceType(String rawSourceType, String? calcMode) {
  final legacyKey = rawSourceType.replaceAllMapped(
    RegExp(r'_([a-z])'),
    (match) => match.group(1)!.toUpperCase(),
  );

  switch (legacyKey) {
    case 'habitCompletionCount':
    case 'habitStreak':
    case 'habitSuccessRate':
      return KPISourceType.habit;
    case 'trackerFieldSum':
    case 'trackerFieldAverage':
    case 'trackerFieldMax':
    case 'trackerFieldMin':
    case 'trackerFieldLatest':
      return KPISourceType.trackerField;
    case 'entryCount':
    case 'journalWordCount':
      return KPISourceType.entry;
    case 'plannerTaskDuration':
    case 'timeSpentInCategory':
      return KPISourceType.timeSpent;
    case 'goalSubtaskCompletion':
    case 'goalProgressPercentage':
      return KPISourceType.subtasks;
    case 'customNumericInput':
    case 'manualQuantity':
      return KPISourceType.manualQuantity;
    case 'collectionItemCount':
      return KPISourceType.collection;
    case 'moodAverage':
    case 'moodTrend':
      return KPISourceType.others;
    case 'plannerTaskCount':
    case 'plannerOverdueCount':
    case 'photoCount':
    case 'commentCount':
    case 'reflectionLength':
    case 'organizerAssociationCount':
      return KPISourceType.others;
    default:
      final normalized = rawSourceType.replaceAllMapped(
        RegExp(r'_([a-z])'),
        (match) => match.group(1)!.toUpperCase(),
      );
      return KPISourceType.values.firstWhere(
        (e) => e.name == normalized,
        orElse: () {
          if (calcMode == 'mood_average' || calcMode == 'mood_trend') {
            return KPISourceType.others;
          }
          return KPISourceType.manualQuantity;
        },
      );
  }
}

DataSourceType _toDataSourceType(
  KPISourceType type,
  String? calculationMode,
) {
  switch (type) {
    case KPISourceType.subtasks:
      return DataSourceType.subtasks;
    case KPISourceType.trackerField:
      return DataSourceType.trackerField;
    case KPISourceType.habit:
      return DataSourceType.habit;
    case KPISourceType.collection:
      return DataSourceType.collection;
    case KPISourceType.entry:
      return DataSourceType.entry;
    case KPISourceType.timeSpent:
      return DataSourceType.timeSpent;
    case KPISourceType.manualQuantity:
      return DataSourceType.manualQuantity;
    case KPISourceType.others:
      if (calculationMode == 'mood_average' || calculationMode == 'mood_trend') {
        return DataSourceType.journalMood;
      }
      return DataSourceType.manualQuantity;
  }
}

KPISourceType _toKPISourceType(
  DataSourceType type,
  String? calculationMode,
) {
  switch (type) {
    case DataSourceType.subtasks:
      return KPISourceType.subtasks;
    case DataSourceType.trackerField:
      return KPISourceType.trackerField;
    case DataSourceType.habit:
      return KPISourceType.habit;
    case DataSourceType.collection:
      return KPISourceType.collection;
    case DataSourceType.entry:
      return KPISourceType.entry;
    case DataSourceType.timeSpent:
      return KPISourceType.timeSpent;
    case DataSourceType.manualQuantity:
      return calculationMode == 'manual'
          ? KPISourceType.manualQuantity
          : KPISourceType.manualQuantity;
    case DataSourceType.journalMood:
      return KPISourceType.others;
  }
}

DataSourceAggregation? _aggregationFromCalculationMode(
  String? calculationMode,
  KPISourceType sourceType,
) {
  switch (calculationMode) {
    case 'sum':
    case 'total_completions':
    case 'planner_task_duration':
    case 'category_duration':
      return DataSourceAggregation.sum;
    case 'average':
    case 'mood_average':
      return DataSourceAggregation.average;
    case 'count':
    case 'entry_count':
    case 'goal_subtasks':
    case 'collection_count':
    case 'planner_task_count':
    case 'planner_overdue_count':
    case 'photo_count':
    case 'comment_count':
    case 'organizer_association_count':
      return DataSourceAggregation.count;
    case 'max':
      return DataSourceAggregation.max;
    case 'min':
      return DataSourceAggregation.min;
    case 'streak':
      return DataSourceAggregation.streak;
  }

  switch (sourceType) {
    case KPISourceType.trackerField:
      return DataSourceAggregation.sum;
    case KPISourceType.entry:
    case KPISourceType.collection:
    case KPISourceType.subtasks:
      return DataSourceAggregation.count;
    case KPISourceType.habit:
    case KPISourceType.timeSpent:
    case KPISourceType.manualQuantity:
    case KPISourceType.others:
      return null;
  }
}

bool _requiresLegacyCalculationMode(String? calculationMode, KPISourceType type) {
  if (calculationMode == null || calculationMode.isEmpty) return false;
  return _aggregationFromCalculationMode(calculationMode, type) == null ||
      const {
        'latest',
        'success_rate',
        'word_count',
        'goal_percentage',
        'mood_trend',
        'reflection_length',
      }.contains(calculationMode);
}

String? _dimensionFromLegacy(
  KPISourceType sourceType,
  String? calculationMode,
  Map<String, dynamic> map,
) {
  if (sourceType != KPISourceType.others &&
      _toDataSourceType(sourceType, calculationMode) != DataSourceType.journalMood) {
    return map['dimension']?.toString();
  }
  if (map['field_id']?.toString() == 'energy') return 'energy';
  return 'pleasantness';
}

bool _shouldOmitSourceId(KPISourceType sourceType) {
  switch (sourceType) {
    case KPISourceType.subtasks:
    case KPISourceType.entry:
    case KPISourceType.timeSpent:
    case KPISourceType.manualQuantity:
      return true;
    case KPISourceType.trackerField:
    case KPISourceType.habit:
    case KPISourceType.collection:
    case KPISourceType.others:
      return false;
  }
}

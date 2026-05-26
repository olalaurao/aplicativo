// lib/models/kpi_model.dart

enum KPISourceType {
  habitCompletionCount,
  habitStreak,
  habitSuccessRate,
  trackerFieldSum,
  trackerFieldAverage,
  trackerFieldMax,
  trackerFieldMin,
  trackerFieldLatest,
  entryCount,
  journalWordCount,
  plannerTaskCount,
  plannerTaskDuration,
  plannerOverdueCount,
  goalSubtaskCompletion,
  goalProgressPercentage,
  customNumericInput,
  moodAverage,
  moodTrend,
  photoCount,
  commentCount,
  reflectionLength,
  organizerAssociationCount,
  timeSpentInCategory,
  collectionItemCount,
}

enum KPIDisplayType { number, percentage, progressBar }

extension KPISourceTypeLabel on KPISourceType {
  String get label {
    switch (this) {
      case KPISourceType.habitCompletionCount:
        return 'Total de Vezes que o Habit foi Completed';
      case KPISourceType.habitStreak:
        return 'Current Day Streak';
      case KPISourceType.habitSuccessRate:
        return 'Success Rate (Frequency)';
      case KPISourceType.trackerFieldSum:
        return 'Soma Total dos Valores Registrados';
      case KPISourceType.trackerFieldAverage:
        return 'Average Logged Value';
      case KPISourceType.trackerFieldMax:
        return 'Highest Value Reached';
      case KPISourceType.trackerFieldMin:
        return 'Lowest Value Reached';
      case KPISourceType.trackerFieldLatest:
        return 'Latest Logged Value';
      case KPISourceType.entryCount:
        return 'Contagem de Entrys no Journal';
      case KPISourceType.journalWordCount:
        return 'Contagem de Palavras Escritas';
      case KPISourceType.plannerTaskCount:
        return 'Number of Tasks in Planner';
      case KPISourceType.plannerTaskDuration:
        return 'Total Task Time';
      case KPISourceType.plannerOverdueCount:
        return 'Quantidade de Itens Atrasados';
      case KPISourceType.goalSubtaskCompletion:
        return 'Subtasks Completeds da Meta';
      case KPISourceType.goalProgressPercentage:
        return 'Progresso Percentual da Meta';
      case KPISourceType.customNumericInput:
        return 'Valor manual';
      case KPISourceType.moodAverage:
        return 'Average Mood in Period';
      case KPISourceType.moodTrend:
        return 'Mood Trend';
      case KPISourceType.photoCount:
        return 'Total de Fotos Adicionadas';
      case KPISourceType.commentCount:
        return 'Total Comments';
      case KPISourceType.reflectionLength:
        return 'Reflection Depth (Characters)';
      case KPISourceType.organizerAssociationCount:
        return 'Uso de Organizadores/Tags';
      case KPISourceType.timeSpentInCategory:
        return 'Tempo Dedicado por Categoria';
      case KPISourceType.collectionItemCount:
        return 'Total Collection Items';
    }
  }
}

class KPI {
  String id;
  String title;
  KPISourceType sourceType;
  String? sourceId; // Reference to specific Habit, Tracker, etc.
  String? fieldId; // For Trackers
  double targetValue;
  double currentValue;
  DateTime? startDate;
  DateTime? endDate;
  KPIDisplayType displayType;
  bool completed;

  KPI({
    required this.id,
    required this.title,
    required this.sourceType,
    this.sourceId,
    this.fieldId,
    this.targetValue = 100,
    this.currentValue = 0,
    this.startDate,
    this.endDate,
    this.displayType = KPIDisplayType.number,
    this.completed = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'source_type': sourceType.name,
      'source_id': sourceId,
      'field_id': fieldId,
      'target_value': targetValue,
      'current_value': currentValue,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'display_type': displayType.name,
      'completed': completed,
    };
  }

  factory KPI.fromMap(Map<String, dynamic> map) {
    final rawSourceType = map['source_type']?.toString() ?? '';
    final normalizedSourceType = rawSourceType.replaceAllMapped(
      RegExp(r'_([a-z])'),
      (match) => match.group(1)!.toUpperCase(),
    );
    return KPI(
      id: map['id'] as String,
      title: map['title'] as String,
      sourceType: KPISourceType.values.firstWhere(
        (e) => e.name == normalizedSourceType,
        orElse: () => KPISourceType.customNumericInput,
      ),
      sourceId: map['source_id'] as String?,
      fieldId: map['field_id'] as String?,
      targetValue: (map['target_value'] as num? ?? 100).toDouble(),
      currentValue: (map['current_value'] as num? ?? 0).toDouble(),
      startDate: map['start_date'] != null
          ? DateTime.parse(map['start_date'])
          : null,
      endDate: map['end_date'] != null ? DateTime.parse(map['end_date']) : null,
      displayType: KPIDisplayType.values.firstWhere(
        (e) => e.name == map['display_type'],
        orElse: () => KPIDisplayType.number,
      ),
      completed: map['completed'] as bool? ?? false,
    );
  }
}

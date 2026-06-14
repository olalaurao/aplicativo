// lib/models/saved_filter.dart

import 'content_object.dart';
import 'task_model.dart';

enum ViewMode { grid, list, grouped, matrix }

class MatrixConfig {
  final String axisXProperty;   // propriedade para colunas, ex: 'priority'
  final List<String> axisXValues; // 2 valores = 2 colunas, ex: ['high','low']
  final String axisXLabels;     // ex: 'Important' / 'Not important'
  final String axisYProperty;   // propriedade para linhas, ex: 'tags'
  final List<String> axisYValues; // 2 valores = 2 linhas
  final String axisYLabels;
  final String title;

  const MatrixConfig({
    required this.axisXProperty,
    required this.axisXValues,
    this.axisXLabels = '',
    required this.axisYProperty,
    required this.axisYValues,
    this.axisYLabels = '',
    required this.title,
  });

  Map<String, dynamic> toJson() => {
    'axisXProperty': axisXProperty,
    'axisXValues': axisXValues,
    'axisXLabels': axisXLabels,
    'axisYProperty': axisYProperty,
    'axisYValues': axisYValues,
    'axisYLabels': axisYLabels,
    'title': title,
  };

  factory MatrixConfig.fromJson(Map<String, dynamic> j) => MatrixConfig(
    axisXProperty: j['axisXProperty'] ?? 'priority',
    axisXValues: List<String>.from(j['axisXValues'] ?? []),
    axisXLabels: j['axisXLabels'] ?? '',
    axisYProperty: j['axisYProperty'] ?? 'tags',
    axisYValues: List<String>.from(j['axisYValues'] ?? []),
    axisYLabels: j['axisYLabels'] ?? '',
    title: j['title'] ?? 'Matrix',
  );

  // Preset de Eisenhower clássico:
  static MatrixConfig get eisenhower => const MatrixConfig(
    title: 'Eisenhower',
    axisXProperty: 'priority',
    axisXValues: ['high', 'low'],
    axisXLabels: 'Important',
    axisYProperty: 'tags',
    axisYValues: ['urgent', 'not-urgent'],
    axisYLabels: 'Urgent',
  );
}

class SavedFilter {
  final String id;
  final String name;
  final String targetType;
  final MatrixConfig? matrixConfig;
  final ViewMode viewMode;

  const SavedFilter({
    required this.id,
    required this.name,
    required this.targetType,
    this.matrixConfig,
    this.viewMode = ViewMode.list,
  });

  List<T> apply<T extends ContentObject>(List<T> items) {
    // Basic apply implementation, for now just filtering by targetType
    if (targetType == 'task') {
      return items.whereType<Task>().toList() as List<T>;
    }
    return items;
  }
}

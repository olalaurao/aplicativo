import 'package:flutter/material.dart';
import 'content_object.dart';
import 'shared_types.dart';
import '../ui/widgets/quartzo_chart.dart'; // for ChartType

enum MetricType {
  mood,
  habit,
  trackerField,
  trackerScore,
  googleCalendar,
  pomodoro,
}

class MetricSource {
  final MetricType type;
  final String id;
  final String label;
  final String? fieldId;
  final Color? color;
  final String? dimension;
  final String axis;
  final bool showEmojiMarkers;
  final Map<String, num>? valueMapping;

  DataSourceReference? get unifiedDataSource =>
      _toUnifiedDataSource(
        type: type,
        id: id,
        fieldId: fieldId,
        dimension: dimension,
        valueMapping: valueMapping,
      );

  MetricSource({
    required this.type,
    required this.id,
    required this.label,
    this.fieldId,
    this.color,
    this.dimension,
    this.axis = 'left',
    this.showEmojiMarkers = false,
    this.valueMapping,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'label': label,
      if (fieldId != null) 'field_id': fieldId,
      if (color != null)
        'color': '#${color!.toARGB32().toRadixString(16).padLeft(8, '0')}',
      'axis': axis,
      'show_emoji_markers': showEmojiMarkers,
      if (dimension != null) 'dimension': dimension,
      if (valueMapping != null) 'value_mapping': valueMapping,
    };

    final unified = unifiedDataSource;
    if (unified != null) {
      map['data_source'] = unified.toMap();
      map.remove('field_id');
      map.remove('dimension');
      map.remove('value_mapping');
    } else {
      map['type'] = type.name;
      map['id'] = id;
    }

    return map;
  }

  factory MetricSource.fromMap(Map<String, dynamic> map) {
    if (map['data_source'] is Map) {
      final unified = DataSourceReference.fromMap(
        Map<String, dynamic>.from(map['data_source'] as Map),
      );
      final resolvedType = _metricTypeFromUnified(unified);
      return MetricSource(
        type: resolvedType,
        id: unified.sourceId ?? '',
        label: map['label']?.toString() ?? '',
        fieldId: unified.fieldId,
        color: _parseColor(map['color']),
        axis: map['axis']?.toString() ?? 'left',
        showEmojiMarkers: map['show_emoji_markers'] == true,
        dimension: unified.dimension,
        valueMapping: unified.valueMapping?.map(
          (key, value) => MapEntry(key, value is num ? value : num.tryParse(value.toString()) ?? 0),
        ),
      );
    }

    return MetricSource(
      type: MetricType.values.firstWhere(
        (e) => e.name == map['type']?.toString(),
        orElse: () => MetricType.mood,
      ),
      id: map['id']?.toString() ?? '',
      label: map['label']?.toString() ?? '',
      fieldId: map['field_id']?.toString(),
      color: _parseColor(map['color']),
      axis: map['axis']?.toString() ?? 'left',
      showEmojiMarkers: map['show_emoji_markers'] == true,
      dimension: map['dimension']?.toString(),
      valueMapping: map['value_mapping'] != null
          ? Map<String, num>.from(map['value_mapping'] as Map)
          : null,
    );
  }

  static Color? _parseColor(dynamic rawColor) {
    if (rawColor == null) return null;
    final value = rawColor.toString().trim();
    if (value.isEmpty) return null;
    try {
      if (value.startsWith('#')) {
        final hex = value.substring(1);
        return Color(int.parse(hex.length == 6 ? 'ff$hex' : hex, radix: 16));
      }
      if (value.startsWith('0x')) return Color(int.parse(value));
      return Color(int.parse(value, radix: 16));
    } catch (_) {
      return null;
    }
  }
}

class AnalysisChart {
  String title;
  ChartType type;
  List<MetricSource> sources;
  String normalization;

  AnalysisChart({
    required this.title,
    this.type = ChartType.line,
    this.sources = const [],
    this.normalization = 'dual_axis',
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'type': type.name,
      'sources': sources.map((s) => s.toMap()).toList(),
      'normalization': normalization,
    };
  }

  factory AnalysisChart.fromMap(Map<String, dynamic> map) {
    return AnalysisChart(
      title: map['title'] as String? ?? 'Chart',
      type: ChartType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => ChartType.line,
      ),
      sources: (map['sources'] as List? ?? [])
          .whereType<Map>()
          .map((s) => MetricSource.fromMap(Map<String, dynamic>.from(s)))
          .toList(),
      normalization: map['normalization'] as String? ?? 'dual_axis',
    );
  }
}

class CombinedAnalysis extends ContentObject {
  String? description;
  List<MetricSource> dataSources;
  List<AnalysisChart> charts;
  DateTimeRange? defaultDateRange;

  CombinedAnalysis({
    super.id,
    required super.title,
    this.description,
    this.dataSources = const [],
    this.charts = const [],
    this.defaultDateRange,
    super.organizers,
    super.categories,
    super.createdAt,
    super.updatedAt,
    super.obsidianPath,
  });

  @override
  String get type => 'combined_analysis';

  @override
  String toMarkdown() {
    final frontmatter = toBaseMap();
    if (description != null) frontmatter['description'] = description;
    frontmatter['data_sources'] = dataSources.map((s) => s.toMap()).toList();
    frontmatter['charts'] = charts.map((c) => c.toMap()).toList();
    if (defaultDateRange != null) {
      frontmatter['default_date_range'] = {
        'start': defaultDateRange!.start.toIso8601String().split('T').first,
        'end': defaultDateRange!.end.toIso8601String().split('T').first,
      };
    }

    final buffer = StringBuffer();
    if (description != null && description!.isNotEmpty) {
      buffer.writeln(description);
      buffer.writeln();
    }

    // O bloco do plugin Obsidian Charts e Obsidian Tracker são gerados dinamicamente em VaultNotifier._writeObject

    return generateMarkdown(frontmatter, buffer.toString());
  }

  factory CombinedAnalysis.fromMarkdown(
    Map<String, dynamic> frontmatter,
    String body,
  ) {
    final analysis = CombinedAnalysis(
      title: frontmatter['title'] as String? ?? 'Untitled Analysis',
    );
    analysis.loadBaseMap(frontmatter);
    analysis.description = frontmatter['description'] as String?;
    if (frontmatter['data_sources'] != null &&
        frontmatter['data_sources'] is List) {
      analysis.dataSources = (frontmatter['data_sources'] as List)
          .whereType<Map>()
          .map((s) => MetricSource.fromMap(Map<String, dynamic>.from(s)))
          .toList();
    }
    if (frontmatter['charts'] != null && frontmatter['charts'] is List) {
      analysis.charts = (frontmatter['charts'] as List)
          .whereType<Map>()
          .map((c) => AnalysisChart.fromMap(Map<String, dynamic>.from(c)))
          .toList();
    }
    if (frontmatter['default_date_range'] != null && frontmatter['default_date_range'] is Map) {
      final rangeMap = frontmatter['default_date_range'] as Map;
      final startStr = rangeMap['start']?.toString();
      final endStr = rangeMap['end']?.toString();
      if (startStr != null && endStr != null) {
        final start = DateTime.tryParse(startStr);
        final end = DateTime.tryParse(endStr);
        if (start != null && end != null) {
          analysis.defaultDateRange = DateTimeRange(start: start, end: end);
        }
      }
    }
    if (analysis.dataSources.isEmpty) {
      analysis.dataSources = analysis.charts.expand((c) => c.sources).toList();
    }
    return analysis;
  }
}

DataSourceReference? _toUnifiedDataSource({
  required MetricType type,
  required String id,
  required String? fieldId,
  required String? dimension,
  required Map<String, num>? valueMapping,
}) {
  switch (type) {
    case MetricType.mood:
      return DataSourceReference(
        sourceType: DataSourceType.journalMood,
        dimension: dimension ?? 'pleasantness',
      );
    case MetricType.habit:
      return DataSourceReference(
        sourceType: DataSourceType.habit,
        sourceId: id.isEmpty ? null : id,
      );
    case MetricType.trackerField:
    case MetricType.trackerScore:
      return DataSourceReference(
        sourceType: DataSourceType.trackerField,
        sourceId: id.isEmpty ? null : id,
        fieldId: fieldId,
        valueMapping: valueMapping == null
            ? null
            : Map<String, dynamic>.from(valueMapping),
      );
    case MetricType.pomodoro:
      return DataSourceReference(
        sourceType: DataSourceType.timeSpent,
        sourceId: id.isEmpty ? null : id,
      );
    case MetricType.googleCalendar:
      return null;
  }
}

MetricType _metricTypeFromUnified(DataSourceReference source) {
  switch (source.sourceType) {
    case DataSourceType.journalMood:
      return MetricType.mood;
    case DataSourceType.habit:
      return MetricType.habit;
    case DataSourceType.trackerField:
      return MetricType.trackerField;
    case DataSourceType.timeSpent:
      return MetricType.pomodoro;
    case DataSourceType.subtasks:
    case DataSourceType.collection:
    case DataSourceType.entry:
    case DataSourceType.manualQuantity:
      return MetricType.trackerScore;
  }
}

import 'package:flutter/material.dart';
import 'content_object.dart';
import '../ui/widgets/citrine_chart.dart'; // for ChartType

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

  MetricSource({
    required this.type,
    required this.id,
    required this.label,
    this.fieldId,
    this.color,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'id': id,
      'label': label,
      if (fieldId != null) 'field_id': fieldId,
      if (color != null)
        'color': '#${color!.toARGB32().toRadixString(16).padLeft(8, '0')}',
    };
  }

  factory MetricSource.fromMap(Map<String, dynamic> map) {
    return MetricSource(
      type: MetricType.values.firstWhere(
        (e) => e.name == map['type']?.toString(),
        orElse: () => MetricType.mood,
      ),
      id: map['id']?.toString() ?? '',
      label: map['label']?.toString() ?? '',
      fieldId: map['field_id']?.toString(),
      color: _parseColor(map['color']),
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

  AnalysisChart({
    required this.title,
    this.type = ChartType.line,
    this.sources = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'type': type.name,
      'sources': sources.map((s) => s.toMap()).toList(),
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
    );
  }
}

class CombinedAnalysis extends ContentObject {
  String? description;
  List<MetricSource> dataSources;
  List<AnalysisChart> charts;

  CombinedAnalysis({
    super.id,
    required super.title,
    this.description,
    this.dataSources = const [],
    this.charts = const [],
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

    final buffer = StringBuffer();
    if (description != null && description!.isNotEmpty) {
      buffer.writeln(description);
      buffer.writeln();
    }

    for (final chart in charts) {
      buffer.writeln('## ${chart.title}');
      buffer.writeln('```dataviewjs');
      buffer.writeln('// Gráfico renderizado dinamicamente pelo Citrine');
      buffer.writeln('// Tipo: ${chart.type.name}');
      buffer.writeln('// Fontes: ${chart.sources.map((s) => s.id).join(", ")}');
      buffer.writeln('```');
      buffer.writeln();
    }

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
    if (analysis.dataSources.isEmpty) {
      analysis.dataSources = analysis.charts.expand((c) => c.sources).toList();
    }
    return analysis;
  }
}

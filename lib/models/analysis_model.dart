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
      if (color != null) 'color': color!.toARGB32().toRadixString(16),
    };
  }

  factory MetricSource.fromMap(Map<String, dynamic> map) {
    return MetricSource(
      type: MetricType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => MetricType.mood,
      ),
      id: map['id'] as String? ?? '',
      label: map['label'] as String? ?? '',
      fieldId: map['field_id'] as String?,
      color: map['color'] != null
          ? Color(int.parse(map['color'], radix: 16))
          : null,
    );
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
      sources: (map['sources'] as List? ?? []).map((s) {
        return MetricSource.fromMap(Map<String, dynamic>.from(s as Map));
      }).toList(),
    );
  }
}

class CombinedAnalysis extends ContentObject {
  String? description;
  List<AnalysisChart> charts;

  CombinedAnalysis({
    super.id,
    required super.title,
    this.description,
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
    if (frontmatter['charts'] != null && frontmatter['charts'] is List) {
      analysis.charts = (frontmatter['charts'] as List).map((c) {
        return AnalysisChart.fromMap(Map<String, dynamic>.from(c as Map));
      }).toList();
    }
    return analysis;
  }
}

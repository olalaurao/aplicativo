// lib/services/dataview_generator.dart
// Generates Dataview query blocks for Obsidian compatibility.
// These are written to index.md files in each vault folder during sync.

import 'package:flutter/foundation.dart';
import '../models/analysis_model.dart';
import '../models/tracker_model.dart';
import 'obsidian_service.dart';

class DataviewGenerator {
  final ObsidianService _obsidian;

  DataviewGenerator(this._obsidian);

  // ─── Public API ──────────────────────────────────────────────────────────────

  /// Regenerates all index files with Dataview queries.
  Future<void> regenerateAll() async {
    await Future.wait([
      _writeTasksIndex(),
      _writeHabitsIndex(),
      _writeMoodIndex(),
      _writeGoalsIndex(),
      _writeNotesIndex(),
      _writeSocialIndex(),
      _writeSystemsIndex(),
      _writePactsIndex(),
    ]);
  }

  /// Generates a tracker chart block for Obsidian Charts plugin.
  static String generateTrackerDataviewBlock(TrackerDefinition tracker) {
    final fields = tracker.sections
        .expand((section) => section.inputFields)
        .map((field) => '${tracker.slug}.${field.id} AS "${field.title}"')
        .join(', ');
    final tableFields = fields.isEmpty ? 'file.link AS "Registro"' : fields;

    return '''```dataview
TABLE $tableFields
FROM "daily"
WHERE ${tracker.slug}
SORT file.name DESC
```''';
  }

  static String generateChartBlock(TrackerDefinition tracker) {
    final numericFields = tracker.sections
        .expand((section) => section.inputFields)
        .where(
          (field) =>
              field.type == InputFieldType.quantity ||
              field.type == InputFieldType.range ||
              field.type == InputFieldType.duration ||
              field.type == InputFieldType.mood ||
              field.type == InputFieldType.checkbox,
        )
        .toList();
    if (numericFields.isEmpty) return '';

    final series = numericFields
        .map(
          (field) => '''  - title: "${field.title}"
    data: []''',
        )
        .join('\n');

    return '''```chart
type: line
labels: []
series:
$series
width: 80%
beginAtZero: false
```''';
  }

  static String generateTrackerPluginBlock(CombinedAnalysis analysis) {
    final sources = analysis.dataSources.isNotEmpty
        ? analysis.dataSources
        : analysis.charts.expand((chart) => chart.sources).toList();
    if (sources.isEmpty) return '';

    final blocks = sources
        .map((source) {
          final target = source.fieldId == null || source.fieldId!.isEmpty
              ? source.id
              : '${source.id}.${source.fieldId}';
          return '''```tracker
searchType: frontmatter
searchTarget: $target
folder: daily
line:
  title: "${source.label}"
  yAxisLabel: "${source.label}"
```''';
        })
        .join('\n\n');

    return blocks;
  }

  static String generateChartsPluginBlock(
    CombinedAnalysis analysis, {
    required List<String> labels,
    required List<List<num>> seriesData,
  }) {
    if (analysis.charts.isEmpty) return '';

    final buffer = StringBuffer();
    for (int i = 0; i < analysis.charts.length; i++) {
      final chart = analysis.charts[i];
      final seriesBuffer = StringBuffer();

      for (final source in chart.sources) {
        final sourceIdx = analysis.dataSources.indexWhere(
          (s) => s.id == source.id && s.fieldId == source.fieldId,
        );
        final List<num> data = (sourceIdx >= 0 && sourceIdx < seriesData.length)
            ? seriesData[sourceIdx]
            : [];

        seriesBuffer.writeln('  - title: "${source.label}"');
        seriesBuffer.writeln('    data: [${data.join(", ")}]');
      }

      buffer.writeln('```chart');
      buffer.writeln('type: ${chart.type.name}');
      buffer.writeln('labels: [${labels.map((l) => '"$l"').join(", ")}]');
      buffer.writeln('series:');
      buffer.write(seriesBuffer.toString());
      buffer.writeln('width: 80%');
      buffer.writeln('beginAtZero: false');
      buffer.write('```');
      if (i < analysis.charts.length - 1) {
        buffer.writeln();
        buffer.writeln();
      }
    }
    return buffer.toString();
  }

  static String trackerChartBlock({
    required String trackerSlug,
    required String fieldSlug,
    required String label,
    required List<String> dates,
    required List<num> values,
  }) {
    final labelsStr = dates.map((d) => '"$d"').join(', ');
    final valuesStr = values.join(', ');
    return '''```chart
type: line
labels: [$labelsStr]
series:
  - title: $label
    data: [$valuesStr]
width: 80%
beginAtZero: false
```''';
  }

  /// Generates an Obsidian Tracker plugin block for habit heatmap.
  static String habitTrackerBlock({
    required String habitSlug,
    required String folder,
    String? startDate,
    String? endDate,
  }) {
    final today = DateTime.now();
    final lastMonth = DateTime(today.year, today.month - 1, today.day);
    final start =
        startDate ??
        '${lastMonth.year}-${lastMonth.month.toString().padLeft(2, '0')}-${lastMonth.day.toString().padLeft(2, '0')}';
    final end =
        endDate ??
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    return '''```tracker
searchType: frontmatter
searchTarget: $habitSlug
folder: $folder
startDate: $start
endDate: $end
month:
  startWeekOn: Mon
  color: orange
  colorByValue: true
```''';
  }

  // ─── Private Index Writers ─────────────────────────────────────────────────

  Future<void> _writeTasksIndex() async {
    const content = '''---
type: index
title: Tasks Index
---

# Tasks

## Active Tasks

```dataview
TABLE stage AS "Stage", priority AS "Priority", file.link AS "Task"
FROM "app"
WHERE type = "task" AND stage != "finalized"
SORT priority DESC, file.name ASC
```

## All Tasks by Stage

```dataview
TABLE stage AS "Stage", priority AS "Priority", file.link AS "Task", end_date AS "Deadline"
FROM "app"
WHERE type = "task"
SORT stage ASC, priority DESC
```
''';
    await _safeWrite('app/tasks-index.md', content);
  }

  Future<void> _writeHabitsIndex() async {
    const content = '''---
type: index
title: Habits Index
---

# Habits

## Active Habits

```dataview
TABLE file.link AS "Habit", frequency AS "Frequency"
FROM "app"
WHERE type = "habit" AND status = "active"
SORT file.name ASC
```

## Habit Streaks (last 30 days)

```dataviewjs
const habitFiles = dv.pages('"app"').where(p => p.type === "habit" && p.status === "active");
const dailyNotes = dv.pages('"daily"').sort(p => p.file.name, "desc").limit(30);

for (const habit of habitFiles) {
  const slug = habit.file.name;
  const title = habit.title ?? habit.file.aliases?.[0] ?? "Sem título";
  let streak = 0;
  for (const note of dailyNotes) {
    const val = note[slug];
    if (val === true || (typeof val === "number" && val > 0)) streak++;
    else break;
  }
  dv.paragraph(`**\${title}**: streak \${streak} dias`);
}
```
''';
    await _safeWrite('app/habits-index.md', content);
  }

  Future<void> _writeMoodIndex() async {
    const content = '''---
type: index
title: Humor — Tendência
---

# Humor

## Últimos 30 dias

```dataview
TABLE mood_emoji AS "😊", mood_label AS "Humor", mood_pleasantness AS "Agradabilidade", mood_energy AS "Energia", date AS "Data"
FROM "daily"
WHERE type = "daily_note" AND mood_label
SORT file.name DESC
LIMIT 30
```
''';
    await _safeWrite('daily/mood-index.md', content);
  }

  Future<void> _writeGoalsIndex() async {
    const content = '''---
type: index
title: Goals Index
---

# Goals

```dataview
TABLE status AS "Status", description AS "Descrição"
FROM "app"
WHERE type = "goal"
SORT file.name ASC
```
''';
    await _safeWrite('app/goals-index.md', content);
  }

  Future<void> _writeNotesIndex() async {
    const content = '''---
type: index
title: Notes Index
---

# Notes

```dataview
TABLE note_subtype AS "Tipo", file.mtime AS "Modificada"
FROM "app"
WHERE type = "note"
SORT file.mtime DESC
```
''';
    await _safeWrite('app/notes-index.md', content);
  }

  Future<void> _writeSocialIndex() async {
    const content = '''---
type: index
title: Social Posts Index
---

# Social

## Todos os posts

```dataview
TABLE platform AS "Plataforma", author_handle AS "Autor", posted_at AS "Data", watched AS "Visto"
FROM "app"
WHERE type = "social_post"
SORT created_at DESC
```

## Não vistos

```dataview
TABLE platform AS "Plataforma", author_handle AS "Autor", file.link AS "Post"
FROM "app"
WHERE type = "social_post" AND watched = false
SORT created_at DESC
```
''';
    await _safeWrite('app/social-index.md', content);
  }

  Future<void> _writeSystemsIndex() async {
    const content = '''---
type: index
title: Systems Index
---

# Systems

## Por frequência de uso

```dataview
TABLE trigger AS "Quando", run_count AS "Execuções", estimated_minutes AS "Estimado"
FROM "app"
WHERE type = "system"
SORT run_count DESC
```

## Todos os Systems

```dataview
TABLE status AS "Status", file.mtime AS "Modificado"
FROM "app"
WHERE type = "system"
SORT file.name ASC
```
''';
    await _safeWrite('app/systems-index.md', content);
  }

  Future<void> _writePactsIndex() async {
    const content = '''---
type: index
title: Pacts Index
---

# Pacts

## Todos os Pacts ativos

```dataview
TABLE ends_at AS "Termina", hypothesis AS "Hipótese"
FROM "app"
WHERE type = "habit" AND habit_mode = "pact" AND status = "active"
SORT ends_at ASC
```

## Pacts Vencidos (sem outcome registrado)

```dataview
TABLE ends_at AS "Venceu em", hypothesis AS "Hipótese"
FROM "app"
WHERE type = "habit" AND habit_mode = "pact" AND status = "active" AND ends_at < date(today)
SORT ends_at ASC
```
''';
    await _safeWrite('app/pacts-index.md', content);
  }

  Future<void> _safeWrite(String path, String content) async {
    try {
      await _obsidian.writeFile(path, content);
    } catch (e) {
      debugPrint('[DataviewGenerator] Failed to write $path: $e');
    }
  }
}

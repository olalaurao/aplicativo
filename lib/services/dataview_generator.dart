// lib/services/dataview_generator.dart
// Generates Dataview query blocks for Obsidian compatibility.
// These are written to index.md files in each vault folder during sync.

import 'package:flutter/foundation.dart';
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
    ]);
  }

  /// Generates a MOC-filtered query string to copy to clipboard.
  static String mocDataviewQuery(String mocSlug, String mocTitle) {
    return '''```dataview
TABLE type AS "Tipo", updated AS "Atualizado"
FROM "app"
WHERE contains(moc, [[${mocSlug}]])
SORT file.mtime DESC
```''';
  }

  /// Generates a tracker chart block for Obsidian Charts plugin.
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
    final start = startDate ?? '${lastMonth.year}-${lastMonth.month.toString().padLeft(2, '0')}-${lastMonth.day.toString().padLeft(2, '0')}';
    final end = endDate ?? '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

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
FROM "tasks"
WHERE stage != "finalized"
SORT priority DESC, file.name ASC
```

## All Tasks by Stage

```dataview
TABLE stage AS "Stage", priority AS "Priority", file.link AS "Task", end_date AS "Deadline"
FROM "tasks"
SORT stage ASC, priority DESC
```
''';
    await _safeWrite('tasks/index.md', content);
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
FROM "habits"
WHERE status = "active"
SORT file.name ASC
```

## Habit Streaks (last 30 days)

```dataviewjs
const folder = "daily";
const habitFiles = dv.pages('"habits"').where(p => p.status === "active");
const dailyNotes = dv.pages('"daily"').sort(p => p.file.name, "desc").limit(30);

for (const habit of habitFiles) {
  const slug = habit.file.name;
  let streak = 0;
  for (const note of dailyNotes) {
    const val = note[slug];
    if (val === true || (typeof val === "number" && val > 0)) streak++;
    else break;
  }
  dv.paragraph(\`**\${habit.title}**: streak \${streak} dias\`);
}
```
''';
    await _safeWrite('habits/index.md', content);
  }

  Future<void> _writeMoodIndex() async {
    const content = '''---
type: index
title: Mood Trend
---

# Mood

## Last 30 Days

```dataview
TABLE mood AS "Humor", date AS "Data"
FROM "daily"
WHERE type = "daily_note" AND mood
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
FROM "goals"
SORT file.name ASC
```
''';
    await _safeWrite('goals/index.md', content);
  }

  Future<void> _writeNotesIndex() async {
    const content = '''---
type: index
title: Notes Index
---

# Notes

```dataview
TABLE note_subtype AS "Tipo", file.mtime AS "Modificada"
FROM "notes"
SORT file.mtime DESC
```
''';
    await _safeWrite('notes/index.md', content);
  }

  Future<void> _safeWrite(String path, String content) async {
    try {
      await _obsidian.writeFile(path, content);
    } catch (e) {
      debugPrint('[DataviewGenerator] Failed to write $path: $e');
    }
  }
}

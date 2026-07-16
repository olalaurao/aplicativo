// lib/services/day_dial_legend_builder.dart
import 'package:flutter/material.dart';
import '../models/day_dial_model.dart';

class DialLegendEntry {
  final String categoryLabel;
  final Color color;
  final double totalHours;
  final int itemCount;
  final IconData? icon;

  const DialLegendEntry({
    required this.categoryLabel,
    required this.color,
    required this.totalHours,
    required this.itemCount,
    this.icon,
  });
}

List<DialLegendEntry> buildDialLegend(List<DialSegment> segments) {
  // Point-in-time segments (habitSlot, reminder) have no real duration to sum — they'd all show "0.0h"
  // and dilute the legend with meaningless zeros. Exclude them from the legend; they're still visible
  // on the ring itself as icon markers, which is enough representation for a point-in-time item.
  final durationSegments = segments.where(
    (s) => s.kind != DialSegmentKind.habitSlot && s.kind != DialSegmentKind.reminder,
  );

  final grouped = <String, List<DialSegment>>{};
  for (final s in durationSegments) {
    grouped.putIfAbsent(_categoryKeyFor(s), () => []).add(s);
  }

  final entries = grouped.entries.map((e) {
    final totalMinutes = e.value.fold<double>(
      0, (sum, s) => sum + s.end.difference(s.start).inMinutes,
    );
    return DialLegendEntry(
      categoryLabel: e.key,
      color: _parseColor(e.value.first.colorHex),
      totalHours: totalMinutes / 60.0,
      itemCount: e.value.length,
      icon: _iconForKind(e.value.first.kind),
    );
  }).toList()
    ..sort((a, b) => b.totalHours.compareTo(a.totalHours));   // biggest chunks of the day first

  return entries;
}

String _categoryKeyFor(DialSegment s) {
  // DialSegmentKind is a structural type (event/task/pomodoro/...), not a meaningful semantic bucket —
  // grouping strictly by kind would produce a legend of "Tasks 4.2h / Events 2.1h" which loses exactly
  // the "Rotina / Login / Reunião" flavor the original design wanted. Group by kind for now (see note
  // below) — the category-tag-based grouping this really wants depends on segments carrying the source
  // object's own `categories` field through from the aggregator, which they currently don't (DialSegment
  // has no `categories` field — see "One more thing to decide" below).
  return switch (s.kind) {
    DialSegmentKind.event => 'Events',
    DialSegmentKind.timeBlock => 'Time blocks',
    DialSegmentKind.taskPlanned => 'Tasks',
    DialSegmentKind.pomodoroPlanned || DialSegmentKind.pomodoroCompleted => 'Focus time',
    DialSegmentKind.dayTheme => 'Day theme',
    DialSegmentKind.sleep => 'Sleep',
    DialSegmentKind.habitSlot => 'Habits',
    DialSegmentKind.reminder => 'Reminders',
  };
}

Color _parseColor(String colorString) {
  if (colorString.startsWith('#')) {
    return Color(int.parse(colorString.replaceFirst('#', '0xFF')));
  }
  return Colors.grey;
}

IconData _iconForKind(DialSegmentKind kind) {
  return switch (kind) {
    DialSegmentKind.event => Icons.calendar_today,
    DialSegmentKind.timeBlock => Icons.access_time,
    DialSegmentKind.taskPlanned => Icons.check_circle_outline,
    DialSegmentKind.pomodoroPlanned || DialSegmentKind.pomodoroCompleted => Icons.timer,
    DialSegmentKind.dayTheme => Icons.wb_sunny,
    DialSegmentKind.sleep => Icons.bedtime,
    DialSegmentKind.habitSlot => Icons.refresh,
    DialSegmentKind.reminder => Icons.notifications,
  };
}

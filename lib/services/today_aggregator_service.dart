import 'package:flutter/material.dart';

import '../models/content_object.dart';
import '../models/shared_types.dart';
import 'daily_schedule_service.dart';

enum TodayItemKind {
  entry,
  task,
  event,
  habitSlot,
  pomodoro,
  trackerRecord,
  reminder,
  timeBlock,
  system,
  rotationZone,
  googleCalendar,
  personContact,
  goal,
}

enum TodayItemOrigin { created, scheduled }

class TodayItem {
  final String id;
  final TodayItemKind kind;
  final TodayItemOrigin origin;
  final DateTime timestamp;
  final String title;
  final IconData iconData;
  final Color color;
  final bool isCompletable;
  final bool isCompleted;
  final bool isPlayable;
  final ContentObject source;
  final int? slotIndex;
  final String sourceLabel;

  TodayItem({
    required this.id,
    required this.kind,
    required this.origin,
    required this.timestamp,
    required this.title,
    required this.iconData,
    required this.color,
    required this.isCompletable,
    required this.isCompleted,
    required this.isPlayable,
    required this.source,
    this.slotIndex,
    this.sourceLabel = '',
  });
}

class TodayAggregatorService {
  List<TodayItem> buildForDate(
    DateTime date, {
    required List<ContentObject> allObjects,
    Map<String, TypeSignature> typeSignatures = const {},
  }) {
    final snapshot = DailyScheduleAggregator.buildForDate(
      date,
      allObjects: allObjects,
      typeSignatures: typeSignatures,
    );

    return snapshot.allItems
        .where((item) => item.source != null)
        .map((item) => TodayItem(
              id: item.id,
              kind: _kind(item.kind),
              origin: item.kind == DailyScheduleKind.journalEntry ||
                      item.kind == DailyScheduleKind.trackerRecord ||
                      item.kind == DailyScheduleKind.pomodoro
                  ? TodayItemOrigin.created
                  : TodayItemOrigin.scheduled,
              timestamp: item.timestamp,
              title: item.title,
              iconData: item.iconData,
              color: item.color,
              isCompletable: item.isCompletable,
              isCompleted: item.isCompleted,
              isPlayable: item.isPlayable,
              source: item.source!,
              slotIndex: item.slotIndex,
              sourceLabel: item.sourceLabel,
            ))
        .toList();
  }

  TodayItemKind _kind(DailyScheduleKind kind) {
    return switch (kind) {
      DailyScheduleKind.task => TodayItemKind.task,
      DailyScheduleKind.habit => TodayItemKind.habitSlot,
      DailyScheduleKind.event => TodayItemKind.event,
      DailyScheduleKind.googleCalendar => TodayItemKind.googleCalendar,
      DailyScheduleKind.reminder => TodayItemKind.reminder,
      DailyScheduleKind.pomodoro => TodayItemKind.pomodoro,
      DailyScheduleKind.trackerRecord => TodayItemKind.trackerRecord,
      DailyScheduleKind.journalEntry => TodayItemKind.entry,
      DailyScheduleKind.timeBlock => TodayItemKind.timeBlock,
      DailyScheduleKind.system => TodayItemKind.system,
      DailyScheduleKind.rotationZone => TodayItemKind.rotationZone,
      DailyScheduleKind.personContact => TodayItemKind.personContact,
      DailyScheduleKind.goal => TodayItemKind.goal,
    };
  }
}

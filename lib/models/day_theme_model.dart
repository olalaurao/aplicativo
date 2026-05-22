// lib/models/day_theme_model.dart
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'content_object.dart';

class TimeRange {
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;

  TimeRange({
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
  });

  Map<String, dynamic> toMap() {
    return {
      'start_hour': startHour,
      'start_minute': startMinute,
      'end_hour': endHour,
      'end_minute': endMinute,
    };
  }

  factory TimeRange.fromMap(Map<String, dynamic> map) {
    return TimeRange(
      startHour: map['start_hour'] as int? ?? 0,
      startMinute: map['start_minute'] as int? ?? 0,
      endHour: map['end_hour'] as int? ?? 0,
      endMinute: map['end_minute'] as int? ?? 0,
    );
  }
}

class TimeBlock extends ContentObject {
  List<TimeRange> timeRanges;
  String? color;

  TimeBlock({
    String? id,
    required String title,
    this.timeRanges = const [],
    this.color,
    int? order,
  }) : super(id: id, title: title, order: order);

  @override
  String get type => 'time_block';

  @override
  String toMarkdown() {
    final frontmatter = toBaseMap();
    frontmatter['color'] = color;
    frontmatter['time_ranges'] = timeRanges.map((tr) => tr.toMap()).toList();
    return generateMarkdown(frontmatter, '');
  }

  factory TimeBlock.fromMap(Map<String, dynamic> map, {String? body}) {
    final block = TimeBlock(
      title: map['title'] as String? ?? 'Untitled Block',
      color: map['color'] as String?,
      timeRanges: (map['time_ranges'] as List?)
              ?.map((e) => TimeRange.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
    );
    block.loadBaseMap(map);
    return block;
  }
}

class DayTheme extends ContentObject {
  List<String> blockIds;
  List<String> daysOfWeek;
  String? color;

  DayTheme({
    String? id,
    required String title,
    this.blockIds = const [],
    this.daysOfWeek = const [],
    this.color,
  }) : super(id: id, title: title);

  @override
  String get type => 'day_theme';

  @override
  String toMarkdown() {
    final frontmatter = toBaseMap();
    frontmatter['color'] = color;
    frontmatter['block_ids'] = blockIds;
    frontmatter['days_of_week'] = daysOfWeek;
    return generateMarkdown(frontmatter, '');
  }

  factory DayTheme.fromMap(Map<String, dynamic> map, {String? body}) {
    final theme = DayTheme(
      title: map['title'] as String? ?? 'Untitled Theme',
      color: map['color'] as String?,
      blockIds: List<String>.from(map['block_ids'] as List? ?? []),
      daysOfWeek: List<String>.from(map['days_of_week'] as List? ?? []),
    );
    theme.loadBaseMap(map);
    return theme;
  }
}

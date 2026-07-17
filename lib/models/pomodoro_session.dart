import 'content_object.dart';

enum PomodoroSessionState { scheduled, active, paused, completed, cancelled }
enum PomodoroType { work, shortBreak, longBreak, custom, stopwatch }

class PomodoroSession extends ContentObject {
  String? linkedItemSlug;
  DateTime date;
  /// V5: Actual timestamp when the session occurred.
  /// Used for retroactive logging (F2.18) where the session is entered after the fact.
  /// Defaults to [date] when not set.
  DateTime? occurredAt;
  int workDuration;
  int shortBreakDuration;
  int longBreakDuration;
  int longBreakAfterBlocks;
  int blocksCompleted;
  int minutesWorked;
  int minutesBreak;
  PomodoroSessionState state;

  PomodoroSession({
    super.id,
    required String taskTitle,
    required this.date,
    this.occurredAt,
    this.linkedItemSlug,
    this.workDuration = 25,
    this.shortBreakDuration = 5,
    this.longBreakDuration = 20,
    this.longBreakAfterBlocks = 4,
    this.blocksCompleted = 0,
    this.minutesWorked = 0,
    this.minutesBreak = 0,
    this.state = PomodoroSessionState.scheduled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : super(title: taskTitle, createdAt: createdAt ?? date, updatedAt: updatedAt ?? date);

  @override
  String get type => 'pomodoro_session';

  @override
  String toMarkdown() {
    final frontmatter = toBaseMap();
    frontmatter['task_title'] = title;
    frontmatter['date'] = date.toIso8601String();
    if (occurredAt != null) {
      frontmatter['occurred_at'] = occurredAt!.toIso8601String();
    }
    if (linkedItemSlug != null) {
      frontmatter['linked_item_slug'] = linkedItemSlug;
    }
    frontmatter['work_duration'] = workDuration;
    frontmatter['short_break_duration'] = shortBreakDuration;
    frontmatter['long_break_duration'] = longBreakDuration;
    frontmatter['long_break_after_blocks'] = longBreakAfterBlocks;
    frontmatter['blocks_completed'] = blocksCompleted;
    frontmatter['minutes_worked'] = minutesWorked;
    frontmatter['minutes_break'] = minutesBreak;
    frontmatter['session_state'] = state.name;
    return generateMarkdown(frontmatter, '');
  }

  factory PomodoroSession.fromMarkdown(
    Map<String, dynamic> frontmatter,
    String body,
  ) {
    final session = PomodoroSession(
      id: frontmatter['id']?.toString(),
      taskTitle: frontmatter['task_title']?.toString() ?? frontmatter['title']?.toString() ?? 'Focus Session',
      date: DateTime.tryParse(frontmatter['date']?.toString() ?? '') ?? DateTime.now(),
      occurredAt: DateTime.tryParse(frontmatter['occurred_at']?.toString() ?? ''),
      linkedItemSlug: frontmatter['linked_item_slug']?.toString(),
      workDuration: (frontmatter['work_duration'] as num? ?? 25).toInt(),
      shortBreakDuration: (frontmatter['short_break_duration'] as num? ?? 5).toInt(),
      longBreakDuration: (frontmatter['long_break_duration'] as num? ?? 20).toInt(),
      longBreakAfterBlocks: (frontmatter['long_break_after_blocks'] as num? ?? 4).toInt(),
      blocksCompleted: (frontmatter['blocks_completed'] as num? ?? 0).toInt(),
      minutesWorked: (frontmatter['minutes_worked'] as num? ?? 0).toInt(),
      minutesBreak: (frontmatter['minutes_break'] as num? ?? 0).toInt(),
      state: PomodoroSessionState.values.firstWhere(
        (s) => s.name == (frontmatter['session_state'] ?? frontmatter['state'])?.toString(),
        orElse: () => PomodoroSessionState.completed,
      ),
      createdAt: DateTime.tryParse(frontmatter['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(frontmatter['updated_at']?.toString() ?? ''),
    );
    session.loadBaseMap(frontmatter);
    return session;
  }

  String toDailyNoteBlock() {
    final effectiveDate = occurredAt ?? date;
    final hh = effectiveDate.hour.toString().padLeft(2, '0');
    final mm = effectiveDate.minute.toString().padLeft(2, '0');
    final buf = StringBuffer()
      ..writeln('### $hh:$mm — $title');
    if (linkedItemSlug != null) {
      buf.writeln('- Linked: [[$linkedItemSlug]]');
    }
    if (occurredAt != null && occurredAt != date) {
      buf.writeln('- Occurred at: ${occurredAt!.toIso8601String()}');
    }
    buf
      ..writeln('- Blocos: $blocksCompleted')
      ..writeln('- Tempo trabalhado: $minutesWorked min')
      ..writeln('- Tempo de pausa: $minutesBreak min');
    return buf.toString();
  }

  factory PomodoroSession.fromDailyNoteBlock(String block, DateTime day) {
    final lines = block.split('\n').map((l) => l.trim()).toList();
    String title = 'Focus Session';
    int hours = day.hour;
    int minutes = day.minute;

    final headerLine = lines.isNotEmpty ? lines[0] : '';
    final headerMatch = RegExp(r'^###\s*(\d{2}):(\d{2})\s*—\s*(.*)$').firstMatch(headerLine);
    if (headerMatch != null) {
      hours = int.tryParse(headerMatch.group(1)!) ?? hours;
      minutes = int.tryParse(headerMatch.group(2)!) ?? minutes;
      title = headerMatch.group(3)!.trim();
    }

    String? linkedItem;
    int blocks = 0;
    int worked = 0;
    int breakTime = 0;

    for (final line in lines) {
      if (line.contains('- Linked:')) {
        final match = RegExp(r'\[\[(.*?)\]\]').firstMatch(line);
        if (match != null) {
          linkedItem = match.group(1);
        }
      } else if (line.contains('- Blocos:')) {
        blocks = int.tryParse(line.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      } else if (line.contains('- Tempo trabalhado:') || line.contains('- Tempo:')) {
        worked = int.tryParse(line.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      } else if (line.contains('- Tempo de pausa:') || line.contains('- Pausas:')) {
        breakTime = int.tryParse(line.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      }
    }

    final date = DateTime(day.year, day.month, day.day, hours, minutes);
    return PomodoroSession(
      taskTitle: title,
      date: date,
      linkedItemSlug: linkedItem,
      blocksCompleted: blocks,
      minutesWorked: worked,
      minutesBreak: breakTime,
      state: PomodoroSessionState.completed,
    );
  }
}


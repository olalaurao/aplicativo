import 'content_object.dart';

enum PomodoroSessionState { scheduled, active, paused, completed, cancelled }
enum PomodoroType { work, shortBreak, longBreak, custom }

class PomodoroSession extends ContentObject {
  String? linkedItemSlug;
  DateTime date;
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
  String toMarkdown() => ''; // Not standalone, embedded in daily note

  String toDailyNoteBlock() {
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    final buf = StringBuffer()
      ..writeln('### $hh:$mm — $title');
    if (linkedItemSlug != null) {
      buf.writeln('- Linked: [[$linkedItemSlug]]');
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

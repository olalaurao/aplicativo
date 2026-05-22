import 'content_object.dart';
import 'shared_types.dart';

enum PomodoroType { work, shortBreak, longBreak, custom }

class PomodoroSession extends ContentObject {
  final String taskTitle;
  final DateTime startTime;
  final Duration duration;
  final PomodoroType pomodoroType;
  bool completed;

  PomodoroSession({
    super.id,
    required this.taskTitle,
    required this.startTime,
    required this.duration,
    required this.pomodoroType,
    this.completed = false,
    this.linkedOrganizerRef,
  }) : super(title: taskTitle, createdAt: startTime);

  final OrganizerReference? linkedOrganizerRef;

  @override
  String get type => 'pomodoro_session';

  @override
  String toMarkdown() => ''; // Not saved as standalone file
}

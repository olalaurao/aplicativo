// lib/models/day_dial_model.dart

/// The category of a dial segment — drives color, icon fallback, and
/// whether the segment is user-editable (draggable/resizable).
enum DialSegmentKind {
  event,            // Event / Google Calendar event
  timeBlock,        // Organizer of type time-block, spanning its configured hours
  taskPlanned,      // Task with scheduledTime, not yet completed via Pomodoro
  pomodoroPlanned,  // Scheduled/upcoming Pomodoro session
  pomodoroCompleted,// Completed Pomodoro session (historical, read-only)
  habitSlot,        // A habit's scheduled slot for the day (from HabitSlot.primaryReminderTime)
  reminder,         // Standalone reminder (not a habit reminder)
  dayTheme,         // Day Theme background band
  sleep,            // Derived idle/sleep band (optional)
}

/// One continuous arc segment on the dial: has a real start+end DateTime,
/// not an hour bucket. This is the core fix over the current model.
class DialSegment {
  final String id;              // stable id: '<kind>:<sourceId>[:<slotIndex>]'
  final DialSegmentKind kind;
  final DateTime start;
  final DateTime end;           // always > start; midnight-spanning allowed
  final String title;
  final String colorHex;        // resolved concrete color
  final String? emoji;          // habit icon, mood emoji, etc. — null for events/blocks
  final String? sourceSlug;     // the underlying object's slug/id, for tap-to-open
  final bool isEditable;        // true only for taskPlanned, pomodoroPlanned, reminder, event (if local), habitSlot
  final bool isResizable;       // subset of isEditable
  int layer;                    // 0 = innermost ring, assigned by the layering algorithm

  DialSegment({
    required this.id,
    required this.kind,
    required this.start,
    required this.end,
    required this.title,
    required this.colorHex,
    this.emoji,
    this.sourceSlug,
    required this.isEditable,
    required this.isResizable,
    this.layer = 0,
  });
}

/// A point-in-time marker (no duration): mood entries.
class DialPointMarker {
  final String id;
  final DateTime timestamp;
  final String emoji;
  final String label;           // mood label, for tooltip/detail sheet
  final String? sourceSlug;     // JournalEntry slug, for tap-to-open

  DialPointMarker({
    required this.id,
    required this.timestamp,
    required this.emoji,
    required this.label,
    this.sourceSlug,
  });
}

/// Full snapshot the widget renders. Produced fresh by the aggregator
/// on every relevant provider change.
class DayDialSnapshot {
  final DateTime date;
  final List<DialSegment> segments;      // already layer-assigned
  final List<DialPointMarker> moodMarkers;
  final int maxLayer;                    // segments.map((s)=>s.layer).max, for ring sizing
  final DialSegment? nextUpcoming;       // first segment with start > now (today only)

  DayDialSnapshot({
    required this.date,
    required this.segments,
    this.moodMarkers = const [],
    required this.maxLayer,
    this.nextUpcoming,
  });
}

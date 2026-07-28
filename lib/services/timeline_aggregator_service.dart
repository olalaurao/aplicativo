// lib/services/timeline_aggregator_service.dart
import '../models/content_object.dart';
import '../models/task_model.dart';
import '../models/journal_entry.dart';
import '../models/habit_model.dart';
import '../models/goal_model.dart';
import '../models/note_model.dart';
import '../models/pillar_model.dart';
import '../models/action_menu_item_model.dart';
import '../models/event_model.dart';
import '../models/reminder_model.dart';
import '../models/people_model.dart';
import '../models/organizer_model.dart';
import '../models/system_model.dart';
import '../models/pomodoro_session.dart';
import '../models/tracker_model.dart';
import '../models/project_model.dart';
import 'scheduler_service.dart';
import 'rotation_service.dart';

class DayAggregation {
  final DateTime date;
  final List<Task> tasks; // normal + recurring
  final List<Task> rotationTasks;
  final List<Project> rotationProjects;
  final List<Habit> habits;
  final List<Event> events;
  final List<Reminder> reminders;
  final List<Organizer> timeBlocks;
  final List<JournalEntry> journalEntries;
  final List<SystemDefinition> systems;
  final List<PomodoroSession> pomodoros;
  final List<TrackingRecord> trackerRecords;
  final List<Goal> goals;
  final List<Person> peopleToContact;

  DayAggregation({
    required this.date,
    required this.tasks,
    required this.rotationTasks,
    required this.rotationProjects,
    required this.habits,
    required this.events,
    required this.reminders,
    required this.timeBlocks,
    required this.journalEntries,
    required this.systems,
    required this.pomodoros,
    required this.trackerRecords,
    required this.goals,
    required this.peopleToContact,
  });

  List<Task> get allTasks => [...tasks, ...rotationTasks];
}

enum TodayItemOrigin {
  created,  // 🕐
  edited,   // ✏️
  scheduled, // 📅
  happened,  // ⚡
}

enum TodayItemKind {
  task,
  habit,
  journalEntry,
  goal,
  note,
  pillar,
  action,
  other,
}

class TodayItem {
  final String id;
  final String title;
  final DateTime date;
  final TodayItemOrigin origin;
  final TodayItemKind kind;
  final String? objectId;  // reference to actual object
  final String? subtitle;

  TodayItem({
    required this.id,
    required this.title,
    required this.date,
    required this.origin,
    required this.kind,
    this.objectId,
    this.subtitle,
  });

  String get originGlyph {
    return switch (origin) {
      TodayItemOrigin.created => '🕐',
      TodayItemOrigin.edited => '✏️',
      TodayItemOrigin.scheduled => '📅',
      TodayItemOrigin.happened => '⚡',
    };
  }
}

class TimelineWindow {
  final DateTime start;
  final DateTime end;

  TimelineWindow({required this.start, required this.end});

  bool contains(DateTime date) {
    return date.isAfter(start) && date.isBefore(end);
  }

  static TimelineWindow today() {
    final now = DateTime.now();
    return TimelineWindow(
      start: DateTime(now.year, now.month, now.day),
      end: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
  }

  static TimelineWindow week() {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: now.weekday - 1));
    return TimelineWindow(
      start: DateTime(start.year, start.month, start.day),
      end: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
  }

  static TimelineWindow month() {
    final now = DateTime.now();
    return TimelineWindow(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
    );
  }
}

class TimelineAggregatorService {
  static DayAggregation aggregateForDate(DateTime date, List<ContentObject> allObjects) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    final visibleObjects = allObjects.where(_isVisibleForDaySurfaces).toList();
    
    final tasks = <Task>[];
    final rotationTasks = <Task>[];
    final rotationProjects = <Project>[];
    final habits = <Habit>[];
    final events = <Event>[];
    final reminders = <Reminder>[];
    final timeBlocks = <Organizer>[];
    final journalEntries = <JournalEntry>[];
    final systems = <SystemDefinition>[];
    final pomodoros = <PomodoroSession>[];
    final trackerRecords = <TrackingRecord>[];
    final goals = <Goal>[];
    final peopleToContact = <Person>[];

    final projects = visibleObjects.whereType<Project>().toList();
    final dayThemes = visibleObjects.whereType<Organizer>().where((o) => o.organizerType == OrganizerType.dayTheme).toList();
    final allTimeBlocks = visibleObjects.whereType<Organizer>().where((o) => o.organizerType == OrganizerType.timeBlock).toList();

    bool isThemeActive(String themeId, DateTime d) {
      const weekDayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final dayName = weekDayNames[d.weekday - 1];
      return dayThemes.any((theme) => theme.id == themeId && theme.daysOfWeek.contains(dayName));
    }

    bool isBlockActive(String blockId, DateTime d) {
      return allTimeBlocks.any((block) {
        if (block.id != blockId) return false;
        return dayThemes.any((theme) {
          if (!theme.organizers.any((ref) => ref.matches(block.id, block.slug, block.title))) return false;
          return isThemeActive(theme.id, d);
        });
      });
    }

    final allTasks = visibleObjects.whereType<Task>().toList();
    final allReminders = visibleObjects.whereType<Reminder>().toList();

    bool isItemScheduled(String linkedItemId, DateTime d) {
      final targetSlug = linkedItemId.replaceAll('[[', '').replaceAll(']]', '').trim().toLowerCase();

      final hasLinkedTask = allTasks.any((t) {
        final isScheduled =
            (t.startDate != null && t.startDate!.year == d.year && t.startDate!.month == d.month && t.startDate!.day == d.day) ||
            (t.deadline != null && t.deadline!.year == d.year && t.deadline!.month == d.month && t.deadline!.day == d.day) ||
            (t.scheduler != null &&
                SchedulerService.shouldFire(
                  t.scheduler!,
                  d,
                  isThemeActive: isThemeActive,
                  isBlockActive: isBlockActive,
                ));
        if (!isScheduled) return false;
        return t.id == linkedItemId ||
            t.slug == targetSlug ||
            t.organizers.any((o) => o.slug == targetSlug || o.title.toLowerCase() == targetSlug);
      });
      if (hasLinkedTask) return true;

      final hasLinkedReminder = allReminders.any((r) {
        final isScheduled =
            (r.time.year == d.year && r.time.month == d.month && r.time.day == d.day) ||
            (r.scheduler != null &&
                SchedulerService.shouldFire(
                  r.scheduler!,
                  d,
                  isThemeActive: isThemeActive,
                  isBlockActive: isBlockActive,
                ));
        if (!isScheduled) return false;
        return r.id == linkedItemId ||
            r.slug == targetSlug ||
            r.organizers.any((o) => o.slug == targetSlug || o.title.toLowerCase() == targetSlug);
      });
      return hasLinkedReminder;
    }

    for (final obj in visibleObjects) {
      if (obj is Task && obj.archived == false) {
        if (obj.scheduler != null && SchedulerService.shouldFire(obj.scheduler!, dateOnly, isThemeActive: isThemeActive, isBlockActive: isBlockActive, isItemScheduled: isItemScheduled)) {
          tasks.add(obj);
        } else {
          bool include = false;
          if (obj.startDate != null) {
            final start = DateTime(obj.startDate!.year, obj.startDate!.month, obj.startDate!.day);
            if (obj.endDate != null) {
              final end = DateTime(obj.endDate!.year, obj.endDate!.month, obj.endDate!.day);
              if (!dateOnly.isBefore(start) && !dateOnly.isAfter(end)) include = true;
            } else if (start == dateOnly) {
              include = true;
            }
          }
          if (include) tasks.add(obj);
        }
      }
      if (obj is Habit) {
        final scheduledToday = obj.schedulers.isEmpty
            ? true
            : obj.schedulers.any((s) => SchedulerService.shouldFire(s, dateOnly, isThemeActive: isThemeActive, isBlockActive: isBlockActive, isItemScheduled: isItemScheduled));
        if (scheduledToday && obj.status == HabitStatus.active && !obj.isNegative) habits.add(obj);
      }
      if (obj is Event) {
        final start = DateTime(obj.startDatetime.year, obj.startDatetime.month, obj.startDatetime.day);
        final endDt = obj.endDatetime ?? obj.startDatetime;
        final end = DateTime(endDt.year, endDt.month, endDt.day);
        if (!dateOnly.isBefore(start) && !dateOnly.isAfter(end)) events.add(obj);
      }
      if (obj is Reminder && !obj.isCompleted) {
        final rDate = DateTime(obj.time.year, obj.time.month, obj.time.day);
        if (rDate == dateOnly || rDate.isBefore(dateOnly)) reminders.add(obj);
      }
      if (obj is Organizer && obj.organizerType == OrganizerType.timeBlock) {
        bool scheduledToday = false;
        if (obj.scheduler != null) {
          scheduledToday = SchedulerService.shouldFire(obj.scheduler!, dateOnly, isThemeActive: isThemeActive, isBlockActive: isBlockActive, isItemScheduled: isItemScheduled);
        } else if (obj.startDate != null) {
          scheduledToday = obj.startDate!.year == dateOnly.year && obj.startDate!.month == dateOnly.month && obj.startDate!.day == dateOnly.day;
        } else {
          scheduledToday = isBlockActive(obj.id ?? '', dateOnly);
          if (!scheduledToday && dayThemes.isEmpty) {
            scheduledToday = true;
          }
        }
        if (scheduledToday) timeBlocks.add(obj); 
      }
      if (obj is JournalEntry) {
        if (obj.date.year == dateOnly.year && obj.date.month == dateOnly.month && obj.date.day == dateOnly.day) {
          journalEntries.add(obj);
        }
      }
      if (obj is SystemDefinition) {
        systems.add(obj);
      }
      if (obj is PomodoroSession) {
        final pDate = obj.date;
        if (pDate.year == dateOnly.year && pDate.month == dateOnly.month && pDate.day == dateOnly.day) {
          pomodoros.add(obj);
        }
      }
      if (obj is TrackingRecord) {
        if (obj.date.year == dateOnly.year && obj.date.month == dateOnly.month && obj.date.day == dateOnly.day) {
          trackerRecords.add(obj);
        }
      }
      if (obj is Goal) {
        if (obj.startDate != null && obj.startDate!.year == dateOnly.year && obj.startDate!.month == dateOnly.month && obj.startDate!.day == dateOnly.day) {
          goals.add(obj);
        } else if (obj.deadline != null && obj.deadline!.year == dateOnly.year && obj.deadline!.month == dateOnly.month && obj.deadline!.day == dateOnly.day) {
          goals.add(obj);
        }
      }
      if (obj is Person) {
        if (obj.lastContactDate != null && obj.contactFrequency != null) {
          final nextContact = obj.lastContactDate!.add(obj.contactFrequency!);
          if (nextContact.year == dateOnly.year && nextContact.month == dateOnly.month && nextContact.day == dateOnly.day) {
            peopleToContact.add(obj);
          }
        }
      }
    }

    for (final project in projects) {
      if (!project.hasRotation) continue;
      final status = RotationService.computeActiveStatus(project, now: dateOnly);
      if (status == null) continue;

      bool addedProject = false;
      final tasksInGroup = RotationService.rotationTasksForGroup(project, status.group, visibleObjects.whereType<Task>().toList());
      for (final task in tasksInGroup) {
        if (task.archived || task.stage == TaskStage.finalized) continue;
        final include = switch (task.rotationFrequencyType) {
          RotationFrequencyType.daily => true,
          RotationFrequencyType.oncePerPeriod => !RotationService.isDoneThisOccurrence(task, status),
          RotationFrequencyType.everyNRotations => RotationService.isDueNow(task, status) && !RotationService.isDoneThisOccurrence(task, status),
          RotationFrequencyType.none => false,
        };
        if (include) {
          rotationTasks.add(task);
          if (!addedProject) {
            rotationProjects.add(project);
            addedProject = true;
          }
        }
      }
    }

    return DayAggregation(
      date: dateOnly,
      tasks: tasks,
      rotationTasks: rotationTasks,
      rotationProjects: rotationProjects,
      habits: habits,
      events: events,
      reminders: reminders,
      timeBlocks: timeBlocks,
      journalEntries: journalEntries,
      systems: systems,
      pomodoros: pomodoros,
      trackerRecords: trackerRecords,
      goals: goals,
      peopleToContact: peopleToContact,
    );
  }

  static bool _isVisibleForDaySurfaces(ContentObject object) {
    if (object.archived) return false;
    final normalizedPath = object.obsidianPath.replaceAll('\\', '/');
    if (normalizedPath == '_deleted' ||
        normalizedPath.startsWith('_deleted/') ||
        normalizedPath.contains('/_deleted/')) {
      return false;
    }
    return true;
  }

  /// Build timeline items from a list of content objects within a window
  static List<TodayItem> buildTimeline(
    List<ContentObject> objects,
    TimelineWindow window, {
    String? filterByMood,
    bool filterByPhoto = false,
    DateTime? filterByDate,
    String? searchQuery,
  }) {
    final items = <TodayItem>[];

    for (final obj in objects) {
      // Apply mood filter for journal entries
      if (filterByMood != null && obj is JournalEntry) {
        if (!_entryMatchesMood(obj, filterByMood)) continue;
      }

      // Apply photo filter for journal entries
      if (filterByPhoto && obj is JournalEntry) {
        if (!obj.body.contains('![[')) continue;
      }

      // Apply date filter
      if (filterByDate != null) {
        if (obj is JournalEntry) {
          if (!_isSameDay(obj.date, filterByDate)) continue;
        }
      }

      // Apply search filter
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        final titleMatch = obj.title.toLowerCase().contains(query);
        bool bodyMatch = false;
        
        if (obj is JournalEntry) {
          final bodyText = _getPlainTextFromBody(obj.body).toLowerCase();
          bodyMatch = bodyText.contains(query);
        }
        
        if (!titleMatch && !bodyMatch) continue;
      }

      // Created event
      if (obj.createdAt != null && window.contains(obj.createdAt!)) {
        items.add(TodayItem(
          id: '${obj.id}_created',
          title: obj.title,
          date: obj.createdAt!,
          origin: TodayItemOrigin.created,
          kind: _kindForObject(obj),
          objectId: obj.id,
        ));
      }

      // Edited event
      if (obj.updatedAt != null && 
          obj.updatedAt != obj.createdAt &&
          window.contains(obj.updatedAt!)) {
        items.add(TodayItem(
          id: '${obj.id}_edited',
          title: obj.title,
          date: obj.updatedAt!,
          origin: TodayItemOrigin.edited,
          kind: _kindForObject(obj),
          objectId: obj.id,
        ));
      }

      // Type-specific events
      if (obj is Task && obj.scheduledDate != null) {
        final scheduledDate = DateTime.parse(obj.scheduledDate!);
        if (window.contains(scheduledDate)) {
          items.add(TodayItem(
            id: '${obj.id}_scheduled',
            title: obj.title,
            date: scheduledDate,
            origin: TodayItemOrigin.scheduled,
            kind: TodayItemKind.task,
            objectId: obj.id,
            subtitle: 'Scheduled',
          ));
        }
      }

      if (obj is JournalEntry && window.contains(obj.date)) {
        items.add(TodayItem(
          id: '${obj.id}_happened',
          title: obj.title.isNotEmpty ? obj.title : 'Journal Entry',
          date: obj.date,
          origin: TodayItemOrigin.happened,
          kind: TodayItemKind.journalEntry,
          objectId: obj.id,
          subtitle: obj.body.isNotEmpty ? obj.body.substring(0, 50) : null,
        ));
      }

      if (obj is Habit) {
        for (final completion in obj.completionHistory) {
          // Apply date filter for habit completions
          if (filterByDate != null) {
            if (!_isSameDay(completion.date, filterByDate)) continue;
          }
          
          if (window.contains(completion.date)) {
            items.add(TodayItem(
              id: '${obj.id}_${completion.date.toIso8601String()}',
              title: obj.title,
              date: completion.date,
              origin: TodayItemOrigin.happened,
              kind: TodayItemKind.habit,
              objectId: obj.id,
              subtitle: 'Completed (${completion.completions}/${obj.dailyGoal})',
            ));
          }
        }
      }

      if (obj is Pillar) {
        for (final touch in obj.touchLog) {
          // Apply date filter for pillar touches
          if (filterByDate != null) {
            if (!_isSameDay(touch.date, filterByDate)) continue;
          }
          
          if (window.contains(touch.date)) {
            items.add(TodayItem(
              id: '${obj.id}_${touch.date.toIso8601String()}',
              title: obj.title,
              date: touch.date,
              origin: TodayItemOrigin.happened,
              kind: TodayItemKind.pillar,
              objectId: obj.id,
              subtitle: touch.note,
            ));
          }
        }
      }
    }

    // Sort by date descending
    items.sort((a, b) => b.date.compareTo(a.date));
    return items;
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static bool _entryMatchesMood(JournalEntry entry, String moodId) {
    // Simple implementation - check if entry has mood matching the filter
    // This would need to be expanded based on actual mood matching logic
    return entry.moodSlug == moodId;
  }

  static String _getPlainTextFromBody(String body) {
    // Simple implementation - strip markdown
    return body.replaceAll(RegExp(r'!\[\[.*?\]\]'), '') // remove images
               .replaceAll(RegExp(r'\[.*?\]\(.*?\)'), '') // remove links
               .replaceAll(RegExp(r'[#*_`~]'), '') // remove markdown chars
               .trim();
  }

  static TodayItemKind _kindForObject(ContentObject obj) {
    if (obj is Task) return TodayItemKind.task;
    if (obj is Habit) return TodayItemKind.habit;
    if (obj is JournalEntry) return TodayItemKind.journalEntry;
    if (obj is Goal) return TodayItemKind.goal;
    if (obj is Note) return TodayItemKind.note;
    if (obj is Pillar) return TodayItemKind.pillar;
    if (obj is ActionMenuItem) return TodayItemKind.action;
    return TodayItemKind.other;
  }
}

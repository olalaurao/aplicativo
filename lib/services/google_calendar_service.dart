// lib/services/google_calendar_service.dart
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:googleapis_auth/googleapis_auth.dart';
import '../models/task_model.dart';
import '../models/people_model.dart';

class GoogleCalendarService {
  calendar.CalendarApi? _calendarApi;

  void init(AuthClient client) {
    _calendarApi = calendar.CalendarApi(client);
  }

  Future<String?> pushSessionToCalendar(
    Task task, {
    String calendarId = 'primary',
  }) async => pushTaskToCalendar(task, calendarId: calendarId);

  Future<String?> pushTaskToCalendar(
    Task task, {
    String calendarId = 'primary',
  }) async {
    if (_calendarApi == null) throw Exception('Calendar API not initialized');

    final eventDate = task.startDate ?? task.endDate;
    if (eventDate == null) {
      return null;
    }

    final event = calendar.Event()
      ..summary = task.title
      ..description = task.notes.join('\n');

    if (task.allDay || task.scheduledTime == null) {
      final startDate = DateTime(
        eventDate.year,
        eventDate.month,
        eventDate.day,
      );
      event
        ..start = (calendar.EventDateTime()..date = startDate)
        ..end = (calendar.EventDateTime()
          ..date = startDate.add(const Duration(days: 1)));
    } else {
      final timeParts = task.scheduledTime!.split(':');
      final hour = int.tryParse(timeParts.first) ?? 9;
      final minute = timeParts.length > 1 ? int.tryParse(timeParts[1]) ?? 0 : 0;
      final startDateTime = DateTime(
        eventDate.year,
        eventDate.month,
        eventDate.day,
        hour.clamp(0, 23),
        minute.clamp(0, 59),
      );
      final endDateTime = startDateTime.add(Duration(minutes: task.duration));
      event
        ..start = (calendar.EventDateTime()..dateTime = startDateTime)
        ..end = (calendar.EventDateTime()..dateTime = endDateTime);
    }

    if (task.exportedCalendarId != null) {
      // Update existing
      final updatedEvent = await _calendarApi!.events.update(
        event,
        calendarId,
        task.exportedCalendarId!,
      );
      return updatedEvent.id;
    } else {
      // Insert new
      final createdEvent = await _calendarApi!.events.insert(event, calendarId);
      return createdEvent.id;
    }
  }

  Future<void> deleteSessionFromCalendar(
    String exportedCalendarId, {
    String calendarId = 'primary',
  }) async {
    if (_calendarApi == null) throw Exception('Calendar API not initialized');
    await _calendarApi!.events.delete(calendarId, exportedCalendarId);
  }

  Future<List<calendar.CalendarListEntry>> fetchCalendars() async {
    if (_calendarApi == null) throw Exception('Calendar API not initialized');

    final calendars = await _calendarApi!.calendarList.list();
    return calendars.items ?? [];
  }

  Future<List<calendar.Event>> fetchEvents({
    DateTime? start,
    DateTime? end,
    List<String>? calendarIds,
  }) async {
    if (_calendarApi == null) throw Exception('Calendar API not initialized');

    final timeMin = start ?? DateTime.now().subtract(const Duration(days: 7));
    final timeMax = end ?? DateTime.now().add(const Duration(days: 30));
    final ids = calendarIds?.where((id) => id.trim().isNotEmpty).toList();
    final calendarsToFetch = ids == null || ids.isEmpty ? ['primary'] : ids;

    final eventLists = await Future.wait(
      calendarsToFetch.map((calendarId) async {
        final events = await _calendarApi!.events.list(
          calendarId,
          timeMin: timeMin.toUtc(),
          timeMax: timeMax.toUtc(),
          singleEvents: true,
          orderBy: 'startTime',
        );
        return events.items ?? <calendar.Event>[];
      }),
    );

    final merged = eventLists.expand((events) => events).toList();
    merged.sort((a, b) {
      final aStart = a.start?.dateTime ?? a.start?.date ?? DateTime(0);
      final bStart = b.start?.dateTime ?? b.start?.date ?? DateTime(0);
      return aStart.compareTo(bStart);
    });
    return merged;
  }

  Future<List<calendar.Event>> fetchEventsFromVisibleCalendars({
    DateTime? start,
    DateTime? end,
  }) async {
    final calendars = await fetchCalendars();
    final visibleCalendarIds = calendars
        .where((entry) => entry.selected != false)
        .map((entry) => entry.id)
        .whereType<String>()
        .toList();

    return fetchEvents(
      start: start,
      end: end,
      calendarIds: visibleCalendarIds.isEmpty
          ? ['primary']
          : visibleCalendarIds,
    );
  }

  Future<calendar.Event> updateEvent(calendar.Event event) async {
    if (_calendarApi == null) throw Exception('Calendar API not initialized');
    if (event.id == null) throw Exception('Event id is missing');
    return _calendarApi!.events.update(event, 'primary', event.id!);
  }

  Future<calendar.Event> createEvent({
    required String title,
    required DateTime start,
    required DateTime end,
    String? location,
    String? description,
    List<Person> participants = const [],
    String calendarId = 'primary',
  }) async {
    if (_calendarApi == null) throw Exception('Calendar API not initialized');

    final event = calendar.Event()
      ..summary = title
      ..description = description
      ..location = location
      ..start = (calendar.EventDateTime()..dateTime = start)
      ..end = (calendar.EventDateTime()..dateTime = end)
      ..attendees = participants
          .where((person) => person.email?.trim().isNotEmpty == true)
          .map(
            (person) => calendar.EventAttendee()
              ..email = person.email!.trim()
              ..displayName = person.title,
          )
          .toList();

    return _calendarApi!.events.insert(event, calendarId);
  }

  Future<calendar.Event> saveEvent({
    String? googleEventId,
    required String title,
    required DateTime start,
    required DateTime end,
    String? location,
    String? description,
    List<Person> participants = const [],
    String calendarId = 'primary',
  }) async {
    if (_calendarApi == null) throw Exception('Calendar API not initialized');

    final event = calendar.Event()
      ..id = googleEventId
      ..summary = title
      ..description = description
      ..location = location
      ..start = (calendar.EventDateTime()..dateTime = start)
      ..end = (calendar.EventDateTime()..dateTime = end)
      ..attendees = participants
          .where((person) => person.email?.trim().isNotEmpty == true)
          .map(
            (person) => calendar.EventAttendee()
              ..email = person.email!.trim()
              ..displayName = person.title,
          )
          .toList();

    if (googleEventId != null && googleEventId.isNotEmpty) {
      return _calendarApi!.events.update(event, calendarId, googleEventId);
    }
    return _calendarApi!.events.insert(event, calendarId);
  }
}

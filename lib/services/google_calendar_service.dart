// lib/services/google_calendar_service.dart
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:googleapis_auth/googleapis_auth.dart';
import '../models/task_model.dart';

class GoogleCalendarService {
  calendar.CalendarApi? _calendarApi;

  void init(AuthClient client) {
    _calendarApi = calendar.CalendarApi(client);
  }

  Future<String?> pushSessionToCalendar(Task task) async =>
      pushTaskToCalendar(task);

  Future<String?> pushTaskToCalendar(Task task) async {
    if (_calendarApi == null) throw Exception('Calendar API not initialized');

    if (task.endDate == null) {
      return null;
    }

    final startDateTime = task.scheduledTime != null
        ? DateTime(
            task.endDate!.year,
            task.endDate!.month,
            task.endDate!.day,
            int.parse(task.scheduledTime!.split(':').first),
            int.parse(task.scheduledTime!.split(':').last),
          )
        : task.endDate!;

    final endDateTime = startDateTime.add(Duration(minutes: task.duration));

    final event = calendar.Event()
      ..summary = task.title
      ..description = task.notes.join('\n')
      ..start = (calendar.EventDateTime()..dateTime = startDateTime)
      ..end = (calendar.EventDateTime()..dateTime = endDateTime);

    if (task.exportedCalendarId != null) {
      // Update existing
      final updatedEvent = await _calendarApi!.events.update(
        event,
        'primary',
        task.exportedCalendarId!,
      );
      return updatedEvent.id;
    } else {
      // Insert new
      final createdEvent = await _calendarApi!.events.insert(event, 'primary');
      return createdEvent.id;
    }
  }

  Future<void> deleteSessionFromCalendar(String exportedCalendarId) async {
    if (_calendarApi == null) throw Exception('Calendar API not initialized');
    await _calendarApi!.events.delete('primary', exportedCalendarId);
  }

  Future<List<calendar.Event>> fetchEvents({
    DateTime? start,
    DateTime? end,
  }) async {
    if (_calendarApi == null) throw Exception('Calendar API not initialized');

    final timeMin = start ?? DateTime.now().subtract(const Duration(days: 7));
    final timeMax = end ?? DateTime.now().add(const Duration(days: 30));

    final events = await _calendarApi!.events.list(
      'primary',
      timeMin: timeMin.toUtc(),
      timeMax: timeMax.toUtc(),
      singleEvents: true,
      orderBy: 'startTime',
    );

    return events.items ?? [];
  }

  Future<calendar.Event> updateEvent(calendar.Event event) async {
    if (_calendarApi == null) throw Exception('Calendar API not initialized');
    if (event.id == null) throw Exception('Event id is missing');
    return _calendarApi!.events.update(event, 'primary', event.id!);
  }
}

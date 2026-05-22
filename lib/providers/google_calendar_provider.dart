// lib/providers/google_calendar_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import '../services/google_calendar_service.dart';
import '../services/google_auth_service.dart' as auth;

final googleAuthServiceProvider =
    StateNotifierProvider<GoogleCalendarAuthNotifier, GoogleSignInAccount?>((
      ref,
    ) {
      return GoogleCalendarAuthNotifier(
        ref.watch(auth.googleAuthServiceProvider),
      );
    });

class GoogleCalendarAuthNotifier extends StateNotifier<GoogleSignInAccount?> {
  final auth.GoogleAuthService _authService;

  GoogleCalendarAuthNotifier(this._authService)
    : super(_authService.currentUser) {
    _restore();
  }

  Future<void> _restore() async {
    await _authService.ensureClient();
    state = _authService.currentUser;
  }

  Future<void> signIn() async {
    await _authService.signIn();
    state = _authService.currentUser;
  }

  Future<void> signOut() async {
    await _authService.signOut();
    state = null;
  }
}

final googleCalendarServiceProvider = Provider<GoogleCalendarService>((ref) {
  return GoogleCalendarService();
});

final googleCalendarEventsProvider =
    FutureProvider.family<List<calendar.Event>, DateTime>((ref, date) async {
      final calendarService = ref.watch(googleCalendarServiceProvider);
      ref.watch(googleAuthServiceProvider);
      final clientReady = await ref
          .watch(auth.googleAuthServiceProvider)
          .ensureClient();
      if (clientReady == null) {
        throw Exception('Google client not authenticated');
      }

      calendarService.init(clientReady);

      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      return await calendarService.fetchEvents(
        start: startOfDay,
        end: endOfDay,
      );
    });

class GoogleCalendarParams {
  final DateTime startDate;
  final int days;

  GoogleCalendarParams({required this.startDate, required this.days});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GoogleCalendarParams &&
          runtimeType == other.runtimeType &&
          startDate.year == other.startDate.year &&
          startDate.month == other.startDate.month &&
          startDate.day == other.startDate.day &&
          days == other.days;

  @override
  int get hashCode =>
      startDate.year.hashCode ^
      startDate.month.hashCode ^
      startDate.day.hashCode ^
      days.hashCode;
}

final googleCalendarRangeEventsProvider =
    FutureProvider.family<List<calendar.Event>, GoogleCalendarParams>((ref, params) async {
      final calendarService = ref.watch(googleCalendarServiceProvider);
      ref.watch(googleAuthServiceProvider);
      final clientReady = await ref
          .watch(auth.googleAuthServiceProvider)
          .ensureClient();
      if (clientReady == null) {
        throw Exception('Google client not authenticated');
      }

      calendarService.init(clientReady);

      final start = DateTime(params.startDate.year, params.startDate.month, params.startDate.day);
      final end = start.add(Duration(days: params.days));

      return await calendarService.fetchEvents(
        start: start,
        end: end,
      );
    });


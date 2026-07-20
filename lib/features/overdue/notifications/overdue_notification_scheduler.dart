// lib/features/overdue/notifications/overdue_notification_scheduler.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/overdue_provider.dart';
import '../../../services/notification_service.dart';

class OverdueNotificationScheduler {
  final NotificationService notificationService;

  OverdueNotificationScheduler({required this.notificationService});

  /// Schedule a daily notification for overdue items
  /// This should be called from a background task (workmanager or alarm manager)
  Future<void> scheduleDailyNotification(int overdueCount) async {
    if (overdueCount == 0) {
      // No notification if no overdue items
      return;
    }

    final notificationId = 'overdue_daily_${DateTime.now().day}';
    
    await notificationService.scheduleNotification(
      id: notificationId,
      title: 'Você tem $overdueCount itens atrasados',
      body: 'Toque para replanejar seus itens atrasados.',
      scheduledDate: DateTime.now().add(const Duration(minutes: 1)),
      payload: 'replanning',
    );
  }

  /// Cancel all overdue notifications
  Future<void> cancelOverdueNotifications() async {
    await notificationService.cancelNotification('overdue_daily');
  }

  /// Check if notification should be sent today (prevent spam)
  bool shouldSendNotification(DateTime lastNotificationDate) {
    final now = DateTime.now();
    final lastDate = DateTime(
      lastNotificationDate.year,
      lastNotificationDate.month,
      lastNotificationDate.day,
    );
    final today = DateTime(now.year, now.month, now.day);
    
    return !lastDate.isAtSameMomentAs(today);
  }
}

// Provider for the scheduler
final overdueNotificationSchedulerProvider = Provider<OverdueNotificationScheduler>((ref) {
  final notificationService = ref.watch(notificationServiceProvider);
  return OverdueNotificationScheduler(
    notificationService: notificationService,
  );
});

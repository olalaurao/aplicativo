import 'package:flutter/material.dart';
import '../../models/reminder_config.dart';

class NotificationTypeUtils {
  static IconData getIcon(NotificationType type) {
    switch (type) {
      case NotificationType.push:
        return Icons.notifications_active_rounded;
      case NotificationType.popup:
        return Icons.picture_in_picture_alt_rounded;
      case NotificationType.alarm:
        return Icons.alarm_rounded;
    }
  }

  static String getLabel(NotificationType type) {
    switch (type) {
      case NotificationType.push:
        return 'Push';
      case NotificationType.popup:
        return 'Popup';
      case NotificationType.alarm:
        return 'Alarm';
    }
  }
}

// lib/providers/notification_overlay_provider.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Represents a single in-app popup notification.
class PopupNotification {
  final String id;
  final String title;
  final String body;
  final PopupType type;
  final Color color;
  final String? objectId;
  final DateTime createdAt;
  final int autoDissmissSeconds;

  PopupNotification({
    required this.id,
    required this.title,
    required this.body,
    this.type = PopupType.reminder,
    this.color = const Color(0xFF9CA3AF),
    this.objectId,
    DateTime? createdAt,
    this.autoDissmissSeconds = 10,
  }) : createdAt = createdAt ?? DateTime.now();
}

enum PopupType { task, event, habit, reminder }

/// Manages the stack of in-app popup notifications.
class NotificationOverlayNotifier extends StateNotifier<List<PopupNotification>> {
  NotificationOverlayNotifier() : super([]);

  void show(PopupNotification notification) {
    // Limit stack to 5 notifications
    if (state.length >= 5) {
      state = [...state.sublist(1), notification];
    } else {
      state = [...state, notification];
    }
  }

  void dismiss(String id) {
    state = state.where((n) => n.id != id).toList();
  }

  void dismissAll() {
    state = [];
  }
}

final notificationOverlayProvider =
    StateNotifierProvider<NotificationOverlayNotifier, List<PopupNotification>>(
  (ref) => NotificationOverlayNotifier(),
);

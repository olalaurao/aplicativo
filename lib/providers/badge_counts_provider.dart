// lib/providers/badge_counts_provider.dart
// A5 — Badge counts for bottom navigation indicators.
// Derives pending task, contact, and inbox counts so the nav bar can show
// urgency badges without the user opening each screen.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'vault_provider.dart';

final badgeCountsProvider = Provider<Map<String, int>>((ref) {
  final tasks      = ref.watch(tasksProvider);
  final people     = ref.watch(peopleProvider);
  final now        = DateTime.now();

  // Overdue tasks: not finalized, past deadline
  final overdueTasks = tasks.where((t) {
    final stage = (t as dynamic).stage;
    final deadline = (t as dynamic).deadline as DateTime?;
    final stageStr = stage?.name ?? stage?.toString() ?? '';
    return stageStr != 'finalized' &&
        deadline != null &&
        deadline.isBefore(now);
  }).length;

  // People due for contact
  final pendingContacts = people.where((p) {
    try {
      return (p as dynamic).isDueForContact == true;
    } catch (_) {
      return false;
    }
  }).length;

  return {
    'planner' : overdueTasks,
    'people'  : pendingContacts,
    'total'   : overdueTasks + pendingContacts,
  };
});

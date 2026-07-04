// lib/providers/badge_counts_provider.dart
// A5 — Badge counts for bottom navigation indicators.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'overdue_provider.dart';
import 'vault_provider.dart';

final badgeCountsProvider = Provider<Map<String, int>>((ref) {
  final overdueCount = ref.watch(overdueCountProvider);
  final pendingContacts = ref.watch(peopleProvider).where((p) {
    try {
      return (p as dynamic).isDueForContact == true;
    } catch (_) {
      return false;
    }
  }).length;
  return {
    'planner': overdueCount,
    'people': pendingContacts,
    'total': overdueCount + pendingContacts,
  };
});

// lib/providers/history_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/content_object.dart';

class HistoryEntry {
  final String id;
  final String title;
  final String type;
  final DateTime timestamp;

  HistoryEntry({
    required this.id,
    required this.title,
    required this.type,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class HistoryNotifier extends Notifier<List<HistoryEntry>> {
  @override
  List<HistoryEntry> build() => [];

  void push(ContentObject object) {
    // Avoid duplicates at the top
    if (state.isNotEmpty && state.first.id == object.id) return;

    final entry = HistoryEntry(
      id: object.id,
      title: object.title,
      type: object.type,
    );

    state = [entry, ...state.where((e) => e.id != object.id)].take(20).toList();
  }

  void remove(String id) => state = state.where((e) => e.id != id).toList();

  void clear() => state = [];
}

final historyProvider = NotifierProvider<HistoryNotifier, List<HistoryEntry>>(
  () {
    return HistoryNotifier();
  },
);

// lib/models/sync_action.dart
import 'dart:convert';

enum SyncOperation { create, update, delete }

class SyncAction {
  final int? id;
  final String objectType; // e.g., 'task', 'journal_entry'
  final String objectId;
  final SyncOperation operation;
  final Map<String, dynamic> payload; // The JSON serialization of the object
  final DateTime timestamp;

  SyncAction({
    this.id,
    required this.objectType,
    required this.objectId,
    required this.operation,
    required this.payload,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'objectType': objectType,
      'objectId': objectId,
      'operation': operation.index,
      'payload': jsonEncode(payload),
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  factory SyncAction.fromMap(Map<String, dynamic> map) {
    return SyncAction(
      id: map['id'] as int?,
      objectType: map['objectType'] as String,
      objectId: map['objectId'] as String,
      operation: SyncOperation.values[map['operation'] as int],
      payload: jsonDecode(map['payload'] as String) as Map<String, dynamic>,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
}

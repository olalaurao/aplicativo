// lib/models/dashboard_block.dart

// F3.8: V5 deduplicated list retired - panel system being redesigned from blank slate
// Only core mechanics preserved until redesign is complete
enum BlockType {
  todayHabits, // Kept for migration only
  todayCompletables,
  todayTimeline,
  todayDial,
  shoppingQuickAdd,
  weekOverview,
  monthOverview,
  goalsProjectsOverview,
  pinnedObject,      // Generic pinned ContentObject (any type)
  trackerAnalysis,   // Chart/stats for a specific tracker or mood
  custom,
  // Legacy types preserved for backward compatibility during migration
  universal,
  shortcuts,
  timeline,
  tasks,
  goals,
  notes,
  calendar,
}

class DashboardBlock {
  final String id;
  final BlockType type;
  final String title;
  bool visible;
  int order;
  final Map<String, dynamic> metadata;

  DashboardBlock({
    required this.id,
    required this.type,
    required this.title,
    this.visible = true,
    this.order = 0,
    this.metadata = const {},
  });

  DashboardBlock copyWith({
    String? id,
    BlockType? type,
    String? title,
    bool? visible,
    int? order,
    Map<String, dynamic>? metadata,
  }) {
    return DashboardBlock(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      visible: visible ?? this.visible,
      order: order ?? this.order,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'title': title,
      'visible': visible,
      'order': order,
      'metadata': metadata,
    };
  }

  factory DashboardBlock.fromMap(Map<String, dynamic> map) {
    return DashboardBlock(
      id: map['id'] as String? ?? 'block-${DateTime.now().millisecondsSinceEpoch}',
      type: BlockType.values.firstWhere(
        (e) => e.name == map['type'],
        // Fallback seguro: tipos obsoletos/desconhecidos caem em custom
        orElse: () => BlockType.custom,
      ),
      title: map['title'] as String? ?? '',
      visible: map['visible'] as bool? ?? true,
      order: map['order'] as int? ?? 0,
      metadata: (map['metadata'] as Map?)?.cast<String, dynamic>() ?? {},
    );
  }
}

// lib/models/dashboard_block.dart

enum BlockType {
  universal,
  shortcuts,
  timeline,
  habits,
  tasks,
  goals,
  quotes,
  photos,
  kpi,
  dailyGoal,
  shoppingList,
  mood,
  notes,
  googleCalendar,
  trackerField,
  people,
  resources,
  timer,
  analysisTrend,
  habitTrend,
  journalQuickAdd,
  timeBlocking,
  customMarkdown,
  plannerDay,
  plannerWeek,
  plannerMonth,
  pomodoroSummary,
  organizerSummary,
  pinnedObject,
  calendar,
  systemQuickRun,
  energyMap,
  // Bloco de Pacts: lista hábitos mode==pact ativos com checkbox de hoje
  // e badge de dias restantes (endsAt - hoje)
  pactToday,
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
        // Fallback seguro: tipos obsoletos/desconhecidos caem em customMarkdown
        orElse: () => BlockType.customMarkdown,
      ),
      title: map['title'] as String? ?? '',
      visible: map['visible'] as bool? ?? true,
      order: map['order'] as int? ?? 0,
      metadata: (map['metadata'] as Map?)?.cast<String, dynamic>() ?? {},
    );
  }
}

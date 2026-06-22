// lib/models/dashboard_panel.dart
//
// DEPRECATED — este arquivo definia um segundo enum `PanelType` com apenas
// 7 valores e uma classe `DashboardPanel` paralela e incompatível com
// `DashboardBlock` (30+ tipos, a implementação real usada em todo o app).
// Mantido apenas para referência histórica; não usar em código novo.
// Use `DashboardBlock` e `BlockType` de `dashboard_block.dart`.
//
// ignore_for_file: unused_field, dead_code

@Deprecated('Use DashboardBlock e BlockType de dashboard_block.dart')
enum PanelType {
  pinnedItems,
  statistics,
  calendar,
  activeHabits,
  recentNotes,
  moodChart,
  upcomingEvents,
}

@Deprecated('Use DashboardBlock de dashboard_block.dart')
class DashboardPanel {
  final String id;
  @Deprecated('Use BlockType')
  final PanelType type;
  final String title;
  final int x;
  final int y;
  final int width;
  final int height;
  final Map<String, dynamic> config;

  DashboardPanel({
    required this.id,
    required this.type,
    required this.title,
    this.x = 0,
    this.y = 0,
    this.width = 1,
    this.height = 1,
    this.config = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'title': title,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'config': config,
    };
  }
}


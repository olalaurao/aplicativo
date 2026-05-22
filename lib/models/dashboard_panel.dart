// lib/models/dashboard_panel.dart

enum PanelType {
  pinnedItems,
  statistics,
  calendar,
  activeHabits,
  recentNotes,
  moodChart,
  upcomingEvents,
}

class DashboardPanel {
  final String id;
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

// lib/providers/navigation_provider.dart
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/navigation_item.dart';

class NavigationNotifier extends AsyncNotifier<List<NavigationItem>> {
  static const _prefKey = 'nav_items_v2';

  @override
  Future<List<NavigationItem>> build() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_prefKey);

    if (jsonStr != null) {
      try {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        final savedItems = decoded
            .map((item) => NavigationItem.fromMap(item))
            .toList();
        final migratedItems = _withMissingDefaultItems(savedItems);
        if (migratedItems.length != savedItems.length) {
          await _saveItems(prefs, migratedItems);
        }
        return migratedItems;
      } catch (e) {
        return _defaultItems;
      }
    }
    return _defaultItems;
  }

  static final List<NavigationItem> _defaultItems = [
    NavigationItem(section: NavSection.home, label: 'Home', route: '/'),
    NavigationItem(
      section: NavSection.timeline,
      label: 'Journal',
      route: '/timeline',
    ),
    NavigationItem(
      section: NavSection.planner,
      label: 'Planner',
      route: '/planner',
    ),
    NavigationItem(
      section: NavSection.organize,
      label: 'Organizers',
      route: '/organize',
    ),
    NavigationItem(
      section: NavSection.trackers,
      label: 'Trackers',
      route: '/trackers',
      inBottomBar: false,
    ),
    NavigationItem(
      section: NavSection.pomodoro,
      label: 'Pomodoro',
      route: '/pomodoro',
      inBottomBar: false,
    ),
    NavigationItem(section: NavSection.more, label: 'More', route: '/more'),
    NavigationItem(
      section: NavSection.statistics,
      label: 'Estatísticas',
      route: '/statistics',
      inBottomBar: false,
    ),
    NavigationItem(
      section: NavSection.habits,
      label: 'Habits',
      route: '/habits',
      inBottomBar: false,
    ),
    NavigationItem(
      section: NavSection.people,
      label: 'People',
      route: '/people',
      inBottomBar: false,
    ),
    NavigationItem(
      section: NavSection.resources,
      label: 'Resources',
      route: '/resources',
      inBottomBar: false,
    ),
    NavigationItem(
      section: NavSection.social,
      label: 'Social',
      route: '/social',
      inBottomBar: false,
    ),
    NavigationItem(
      section: NavSection.goals,
      label: 'Goals',
      route: '/goals',
      inBottomBar: false,
    ),
    NavigationItem(
      section: NavSection.notes,
      label: 'Notes',
      route: '/notes',
      inBottomBar: false,
    ),
    NavigationItem(
      section: NavSection.archive,
      label: 'Archive',
      route: '/archive',
      inBottomBar: false,
    ),
    NavigationItem(
      section: NavSection.map,
      label: 'Map',
      route: '/map',
      inBottomBar: false,
    ),
    NavigationItem(
      section: NavSection.reminders,
      label: 'Reminders',
      route: '/reminders',
      inBottomBar: false,
    ),
    NavigationItem(
      section: NavSection.deletedFiles,
      label: 'Trash',
      route: '/deleted_files',
      inBottomBar: false,
    ),
    NavigationItem(
      section: NavSection.inbox,
      label: 'Inbox',
      route: '/inbox',
      inBottomBar: false,
    ),
  ];

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final data = state.valueOrNull ?? [];
    await _saveItems(prefs, data);
  }

  static Future<void> _saveItems(
    SharedPreferences prefs,
    List<NavigationItem> data,
  ) async {
    await prefs.setString(
      _prefKey,
      jsonEncode(data.map((e) => e.toMap()).toList()),
    );
  }

  static List<NavigationItem> _withMissingDefaultItems(
    List<NavigationItem> savedItems,
  ) {
    final existingSections = savedItems
        .where((item) => !item.isCustom)
        .map((item) => item.section)
        .toSet();
    final missingDefaults = _defaultItems.where(
      (item) => !existingSections.contains(item.section),
    );
    return [...savedItems, ...missingDefaults];
  }

  Future<void> toggleInBottomBar(dynamic idOrSection) async {
    final current = state.valueOrNull ?? [];
    state = AsyncData([
      for (final item in current)
        if ((idOrSection is NavSection && item.section == idOrSection) ||
            (idOrSection is String && item.id == idOrSection))
          NavigationItem(
            section: item.section,
            label: item.label,
            route: item.route,
            inBottomBar: !item.inBottomBar,
            isCustom: item.isCustom,
            id: item.id,
            type: item.type,
          )
        else
          item,
    ]);
    await _save();
  }

  Future<void> addShortcut(NavigationItem shortcut) async {
    final current = state.valueOrNull ?? [];
    state = AsyncData([...current, shortcut]);
    await _save();
  }

  Future<void> removeShortcut(String id) async {
    final current = state.valueOrNull ?? [];
    state = AsyncData([
      for (final item in current)
        if (!(item.isCustom && item.id == id)) item,
    ]);
    await _save();
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final current = state.valueOrNull ?? [];
    final list = List<NavigationItem>.from(current);
    if (oldIndex < 0 || oldIndex >= list.length) return;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    state = AsyncData(list);
    await _save();
  }

  Future<void> renameShortcut(String id, String newLabel) async {
    final current = state.valueOrNull ?? [];
    state = AsyncData([
      for (final item in current)
        if (item.isCustom && item.id == id)
          NavigationItem(
            section: item.section,
            label: newLabel,
            route: item.route,
            inBottomBar: item.inBottomBar,
            isCustom: true,
            id: item.id,
            type: item.type,
          )
        else
          item,
    ]);
    await _save();
  }
}

final navigationProvider =
    AsyncNotifierProvider<NavigationNotifier, List<NavigationItem>>(() {
      return NavigationNotifier();
    });

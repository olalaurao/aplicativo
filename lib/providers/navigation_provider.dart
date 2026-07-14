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
        // Remove 'Map' items
        final filteredItems = savedItems.where((item) => item.label != 'Map').toList();
        final migratedItems = _normalizeItems(
          _withMissingDefaultItems(filteredItems),
        );
        if (jsonEncode(migratedItems.map((e) => e.toMap()).toList()) !=
            jsonEncode(savedItems.map((e) => e.toMap()).toList())) {
          await _saveItems(prefs, migratedItems);
        }
        return migratedItems;
      } catch (e) {
        return _normalizeItems(_defaultItems);
      }
    }
    return _normalizeItems(_defaultItems);
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
      label: 'Statistics',
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
    NavigationItem(
      section: NavSection.dayThemes,
      label: 'Day Themes',
      route: '/day-themes',
      inBottomBar: false,
    ),
    NavigationItem(
      section: NavSection.timeBlocks,
      label: 'Time Blocks',
      route: '/time-blocks',
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

  static List<NavigationItem> _normalizeItems(List<NavigationItem> items) {
    final normalized = [
      for (final item in items)
        if (item.section == NavSection.home || item.section == NavSection.more)
          _copyItem(item, inBottomBar: true)
        else
          item,
    ];

    final bottomItems = normalized.where((item) => item.inBottomBar).toList();
    // Allow up to 6 items (Home + up to 4 custom + More)
    if (bottomItems.length <= 6) return normalized;

    final keptKeys = <String>{};
    for (final item in normalized) {
      if (!item.inBottomBar) continue;
      if (item.section == NavSection.home || item.section == NavSection.more) {
        keptKeys.add(_itemKey(item));
      }
    }
    for (final item in normalized) {
      if (keptKeys.length >= 6) break;
      if (!item.inBottomBar ||
          item.section == NavSection.home ||
          item.section == NavSection.more) {
        continue;
      }
      keptKeys.add(_itemKey(item));
    }

    return [
      for (final item in normalized)
        _copyItem(item, inBottomBar: keptKeys.contains(_itemKey(item))),
    ];
  }

  static NavigationItem _copyItem(
    NavigationItem item, {
    bool? inBottomBar,
    String? label,
    Map<String, String>? queryParams,
  }) {
    return NavigationItem(
      section: item.section,
      label: label ?? item.label,
      route: item.route,
      inBottomBar: inBottomBar ?? item.inBottomBar,
      isCustom: item.isCustom,
      id: item.id,
      type: item.type,
      queryParams: queryParams ?? item.queryParams,
    );
  }

  static String _itemKey(NavigationItem item) {
    if (item.isCustom) {
      final queryParamsStr = item.queryParams?.entries
          .map((e) => '${e.key}=${e.value}')
          .join('&') ?? '';
      return 'custom:${item.id ?? item.route}::$queryParamsStr';
    }
    return item.section.name;
  }

  static bool _sameItem(NavigationItem a, NavigationItem b) {
    return _itemKey(a) == _itemKey(b);
  }

  Future<void> toggleInBottomBar(dynamic idOrSection) async {
    final current = state.valueOrNull ?? [];
    NavigationItem? target;
    for (final item in current) {
      if ((idOrSection is NavSection && item.section == idOrSection) ||
          (idOrSection is String && item.id == idOrSection)) {
        target = item;
        break;
      }
    }
    if (target == null ||
        target.section == NavSection.home ||
        target.section == NavSection.more) {
      return;
    }

    final targetWillBePinned = !target.inBottomBar;
    var toggled = [
      for (final item in current)
        if (_sameItem(item, target))
          _copyItem(item, inBottomBar: !item.inBottomBar)
        else
          item,
    ];

    if (targetWillBePinned &&
        toggled.where((item) => item.inBottomBar).length > 6) {
      final targetKey = _itemKey(target);
      for (var i = toggled.length - 1; i >= 0; i--) {
        final item = toggled[i];
        if (!item.inBottomBar ||
            item.section == NavSection.home ||
            item.section == NavSection.more ||
            _itemKey(item) == targetKey) {
          continue;
        }
        toggled = [
          for (var j = 0; j < toggled.length; j++)
            if (j == i)
              _copyItem(toggled[j], inBottomBar: false)
            else
              toggled[j],
        ];
        break;
      }
    }

    state = AsyncData(_normalizeItems(toggled));
    await _save();
  }

  Future<void> addShortcut(NavigationItem shortcut) async {
    final current = state.valueOrNull ?? [];
    state = AsyncData(_normalizeItems([...current, shortcut]));
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
    if (oldIndex < 0 ||
        oldIndex >= list.length ||
        newIndex < 0 ||
        newIndex > list.length) {
      return;
    }
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    state = AsyncData(_normalizeItems(list));
    await _save();
  }

  Future<void> reorderVisibleItems(
    List<NavigationItem> visibleItems,
    int oldIndex,
    int newIndex,
  ) async {
    if (newIndex > oldIndex) newIndex -= 1;
    if (oldIndex < 0 ||
        oldIndex >= visibleItems.length ||
        newIndex < 0 ||
        newIndex > visibleItems.length) {
      return;
    }

    final reorderedVisible = List<NavigationItem>.from(visibleItems);
    final moved = reorderedVisible.removeAt(oldIndex);
    reorderedVisible.insert(newIndex, moved);

    final current = List<NavigationItem>.from(state.valueOrNull ?? []);
    final movedFullIndex = current.indexWhere((item) => _sameItem(item, moved));
    if (movedFullIndex == -1) return;

    final movedFullItem = current.removeAt(movedFullIndex);
    final beforeMoved = newIndex + 1 < reorderedVisible.length
        ? reorderedVisible[newIndex + 1]
        : null;
    final insertIndex = beforeMoved == null
        ? _lastVisibleIndex(current, visibleItems) + 1
        : current.indexWhere((item) => _sameItem(item, beforeMoved));

    current.insert(
      insertIndex < 0 ? current.length : insertIndex,
      movedFullItem,
    );
    state = AsyncData(_normalizeItems(current));
    await _save();
  }

  int _lastVisibleIndex(
    List<NavigationItem> items,
    List<NavigationItem> visibleItems,
  ) {
    var lastIndex = -1;
    for (var i = 0; i < items.length; i++) {
      if (visibleItems.any((visible) => _sameItem(visible, items[i]))) {
        lastIndex = i;
      }
    }
    return lastIndex;
  }

  Future<void> renameShortcut(String id, String newLabel) async {
    final current = state.valueOrNull ?? [];
    state = AsyncData([
      for (final item in current)
        if (item.isCustom && item.id == id)
          _copyItem(item, label: newLabel)
        else
          item,
    ]);
    await _save();
  }

  Future<void> pinCurrentScreen(
    String label,
    String route,
    Map<String, String>? queryParams,
    String? type,
  ) async {
    final current = state.valueOrNull ?? [];
    
    // Generate a unique ID for this pin
    final id = 'pin_${DateTime.now().millisecondsSinceEpoch}';
    
    // Check if this exact screen is already pinned
    for (final item in current) {
      if (item.isCustom &&
          item.route == route &&
          _mapsEqual(item.queryParams, queryParams)) {
        // Already pinned, just toggle it to bottom bar
        await toggleInBottomBar(item.id);
        return;
      }
    }
    
    // Create new pinned item
    final newItem = NavigationItem(
      section: NavSection.shortcut,
      label: label,
      route: route,
      inBottomBar: true,
      isCustom: true,
      id: id,
      type: type ?? 'screen',
      queryParams: queryParams,
    );
    
    state = AsyncData(_normalizeItems([...current, newItem]));
    await _save();
  }

  Future<void> unpinScreen(String route, Map<String, String>? queryParams) async {
    final current = state.valueOrNull ?? [];
    state = AsyncData([
      for (final item in current)
        if (!(item.isCustom &&
            item.route == route &&
            _mapsEqual(item.queryParams, queryParams)))
          item,
    ]);
    await _save();
  }

  bool isScreenPinned(String route, Map<String, String>? queryParams) {
    final current = state.valueOrNull ?? [];
    return current.any((item) =>
        item.isCustom &&
        item.route == route &&
        _mapsEqual(item.queryParams, queryParams));
  }

  bool _mapsEqual(Map<String, String>? a, Map<String, String>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || b[key] != a[key]) return false;
    }
    return true;
  }
}

final navigationProvider =
    AsyncNotifierProvider<NavigationNotifier, List<NavigationItem>>(() {
      return NavigationNotifier();
    });

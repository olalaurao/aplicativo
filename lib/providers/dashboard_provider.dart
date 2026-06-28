// lib/providers/dashboard_provider.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/dashboard_block.dart';

class DashboardNotifier extends AsyncNotifier<List<DashboardBlock>> {
  static const _prefKey = 'dashboard_blocks_v3';

  @override
  Future<List<DashboardBlock>> build() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_prefKey);

    if (jsonStr != null) {
      try {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        return decoded.map((item) => DashboardBlock.fromMap(item)).toList();
      } catch (e) {
        return [];
      }
    }
    return [];
  }

  static const List<DashboardBlock> availableWidgetBlocks = [];

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final data = state.valueOrNull ?? [];
    await prefs.setString(
      _prefKey,
      jsonEncode(data.map((e) => e.toMap()).toList()),
    );
  }

  Future<void> toggleVisibility(String id) async {
    final current = state.valueOrNull ?? [];
    state = AsyncData([
      for (final block in current)
        if (block.id == id)
          DashboardBlock(
            id: block.id,
            type: block.type,
            title: block.title,
            visible: !block.visible,
            order: block.order,
            metadata: block.metadata,
          )
        else
          block,
    ]);
    await _save();
  }

  Future<void> reorderBlocks(int oldIndex, int newIndex) async {
    final current = state.valueOrNull ?? [];
    final list = List<DashboardBlock>.from(current);
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);

    // Update order values
    state = AsyncData(
      list.asMap().entries.map((entry) {
        final block = entry.value;
        return DashboardBlock(
          id: block.id,
          type: block.type,
          title: block.title,
          visible: block.visible,
          order: entry.key,
          metadata: block.metadata,
        );
      }).toList(),
    );
    await _save();
  }

  Future<void> updateBlock(DashboardBlock updated) async {
    final current = state.valueOrNull ?? [];
    state = AsyncData([
      for (final block in current)
        if (block.id == updated.id) updated else block,
    ]);
    await _save();
  }

  Future<void> addBlock(
    BlockType type,
    String title, {
    Map<String, dynamic> metadata = const {},
  }) async {
    debugPrint('Dashboard blocks are disabled; ignoring addBlock($type).');
  }

  Future<void> removeBlock(String id) async {
    final current = state.valueOrNull ?? [];
    state = AsyncData(current.where((block) => block.id != id).toList());
    await _save();
  }

  Future<void> clearAll() async {
    state = const AsyncData([]);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
  }
}

final dashboardProvider =
    AsyncNotifierProvider<DashboardNotifier, List<DashboardBlock>>(() {
      return DashboardNotifier();
    });

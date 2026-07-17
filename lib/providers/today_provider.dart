import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/today_aggregator_service.dart';
import 'vault_provider.dart';
import 'settings_provider.dart';

final todayAggregatorServiceProvider = Provider<TodayAggregatorService>((ref) {
  return TodayAggregatorService();
});

final todayItemsProvider = Provider.autoDispose.family<List<TodayItem>, DateTime>((ref, date) {
  // Selectively watch only the types that matter for Today's view
  final allObjects = ref.watch(allObjectsProvider.select((async) {
    final list = async.valueOrNull ?? [];
    return list.where((o) =>
        o.type == 'task' ||
        o.type == 'goal' ||
        o.type == 'habit' ||
        o.type == 'routine' ||
        o.type == 'note' ||
        o.type == 'reminder').toList();
  }));
  
  final settings = ref.watch(settingsProvider);
  final aggregator = ref.watch(todayAggregatorServiceProvider);
  return aggregator.buildForDate(date, allObjects: allObjects, typeSignatures: settings.typeSignatures);
});

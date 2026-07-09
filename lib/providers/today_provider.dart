import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/today_aggregator_service.dart';
import 'vault_provider.dart';

final todayAggregatorServiceProvider = Provider<TodayAggregatorService>((ref) {
  return TodayAggregatorService();
});

final todayItemsProvider = Provider.autoDispose.family<List<TodayItem>, DateTime>((ref, date) {
  final allObjectsAsync = ref.watch(allObjectsProvider);
  final allObjects = allObjectsAsync.valueOrNull ?? [];
  final aggregator = ref.watch(todayAggregatorServiceProvider);
  return aggregator.buildForDate(date, allObjects: allObjects);
});

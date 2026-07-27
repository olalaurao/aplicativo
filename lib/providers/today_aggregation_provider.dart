import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/timeline_aggregator_service.dart';
import 'vault_provider.dart';

final todayAggregationProvider = Provider.family<DayAggregation, DateTime>((ref, date) {
  final allObjects = ref.watch(allObjectsProvider).value ?? [];
  return TimelineAggregatorService.aggregateForDate(date, allObjects);
});

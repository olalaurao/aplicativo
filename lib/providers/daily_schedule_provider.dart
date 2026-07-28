import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/daily_schedule_service.dart';
import 'settings_provider.dart';
import 'vault_provider.dart';

final dailyScheduleProvider =
    Provider.autoDispose.family<DailyScheduleSnapshot, DateTime>((ref, date) {
  final allObjects = ref.watch(
    allObjectsProvider.select((async) => async.valueOrNull ?? []),
  );
  final settings = ref.watch(settingsProvider);
  return DailyScheduleAggregator.buildForDate(
    date,
    allObjects: allObjects,
    typeSignatures: settings.typeSignatures,
  );
});

final filteredDailyScheduleProvider = Provider.autoDispose
    .family<DailyScheduleSnapshot, ({DateTime date, DailyScheduleFilter filter})>(
        (ref, args) {
  return ref.watch(dailyScheduleProvider(args.date)).apply(args.filter);
});

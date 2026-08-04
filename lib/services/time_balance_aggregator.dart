import '../models/task_model.dart';
import '../models/organizer_model.dart';
import '../models/shared_types.dart';

class TimeBalanceAggregation {
  final double totalAllocated;
  final double totalWildcard;
  final double openTime;
  final Map<String, double> byGroup;
  final int totalMinutesInPeriod;

  TimeBalanceAggregation({
    required this.totalAllocated,
    required this.totalWildcard,
    required this.openTime,
    required this.byGroup,
    required this.totalMinutesInPeriod,
  });
}

class TimeBalanceAggregator {
  static TimeBalanceAggregation aggregate({
    required List<Task> tasks,
    required List<Organizer> organizers,
    required DateTime startDate,
    required DateTime endDate,
    required List<String> typeFilters,
  }) {
    double totalAllocated = 0;
    double totalWildcard = 0;
    Map<String, double> byGroup = {};

    for (final task in tasks) {
      if (task.duration == null || task.duration! <= 0) continue;
      
      final taskDate = task.startDate;
      if (taskDate == null || taskDate.isBefore(startDate) || taskDate.isAfter(endDate)) continue;

      bool isWildcard = false;
      if (task.timeBlock != null) {
        final tbObj = organizers.firstWhere(
          (o) => o.id == task.timeBlock || o.slug == task.timeBlock,
          orElse: () => Organizer(id: '', title: '', organizerType: OrganizerType.timeBlock),
        );
        if (tbObj.isWildcard) {
          isWildcard = true;
        }
      }

      if (isWildcard) {
        totalWildcard += task.duration!;
      } else {
        OrganizerReference? linkedGroup;
        for (final filter in typeFilters) {
          linkedGroup = task.organizers.firstWhere(
            (o) => o.type == filter,
            orElse: () => OrganizerReference(type: filter, slug: '', title: ''),
          );
          if (linkedGroup.slug.isNotEmpty) break; // Found a match
        }

        // Fallback to unassigned if no match found among filters
        if (linkedGroup == null || linkedGroup.slug.isEmpty) {
          linkedGroup = OrganizerReference(type: typeFilters.first, slug: 'unassigned', title: 'Unassigned');
        }
        
        final groupId = linkedGroup.slug;
        byGroup[groupId] = (byGroup[groupId] ?? 0) + task.duration!;
        totalAllocated += task.duration!;
      }
    }

    final int days = endDate.difference(startDate).inDays + 1;
    final int totalMinutesInPeriod = days * 24 * 60;
    double openTime = totalMinutesInPeriod - totalAllocated - totalWildcard;
    if (openTime < 0) openTime = 0;

    return TimeBalanceAggregation(
      totalAllocated: totalAllocated,
      totalWildcard: totalWildcard,
      openTime: openTime,
      byGroup: byGroup,
      totalMinutesInPeriod: totalMinutesInPeriod,
    );
  }
}

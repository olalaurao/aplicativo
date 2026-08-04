// lib/services/week_tag_service.dart
//
// Utility for week-based focus pin tags.
// Tags are stored in ContentObject.tags as strings of the form: "week:YYYY-Wnn"
// e.g. "week:2026-W32"

class WeekTagService {
  /// Returns the canonical week tag for the ISO week containing [date].
  /// Format: "week:YYYY-Www"
  static String tagFor(DateTime date) {
    final iso = _isoWeek(date);
    final week = iso.$2.toString().padLeft(2, '0');
    return 'week:${iso.$1}-W$week';
  }

  /// Returns the tag for the current ISO week.
  static String get currentWeekTag => tagFor(DateTime.now());

  /// Returns true if [tags] contains the tag for the current week.
  static bool isCurrentWeekPin(List<String> tags) {
    final tag = currentWeekTag;
    return tags.contains(tag);
  }

  /// Returns true if [tags] contains the tag for the given [date]'s week.
  static bool isPinForWeek(List<String> tags, DateTime date) {
    final tag = tagFor(date);
    return tags.contains(tag);
  }

  // Returns (year, weekNumber) per ISO 8601.
  static (int, int) _isoWeek(DateTime date) {
    // Thursday of the current week determines the ISO year
    final thursday = date.add(Duration(days: 4 - (date.weekday == 7 ? 0 : date.weekday)));
    final year = thursday.year;
    final startOfYear = DateTime(year, 1, 1);
    // ISO week 1 is the week with the first Thursday of the year
    final firstThursday = startOfYear.add(
      Duration(days: (4 - (startOfYear.weekday == 7 ? 0 : startOfYear.weekday)) % 7),
    );
    final firstMonday = firstThursday.subtract(const Duration(days: 3));
    final weekNumber = ((date.difference(firstMonday).inDays) ~/ 7) + 1;
    return (year, weekNumber);
  }
}

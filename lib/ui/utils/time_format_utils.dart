// lib/ui/utils/time_format_utils.dart

/// Formats a time duration in minutes to a human-readable string.
/// E.g. 45 -> "45m", 60 -> "1h", 90 -> "1h 30m".
String formatMinutesToDuration(int minutes) {
  if (minutes == 0) return '0h';
  
  if (minutes < 60) {
    return '${minutes}m';
  }
  
  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;
  
  if (remainingMinutes == 0) {
    return '${hours}h';
  }
  
  return '${hours}h ${remainingMinutes}m';
}

/// Formats a time duration in hours to a human-readable string.
/// E.g. 0.5 -> "30m", 1.0 -> "1h", 1.5 -> "1h 30m".
String formatHoursToDuration(double hours) {
  final minutes = (hours * 60).round();
  return formatMinutesToDuration(minutes);
}

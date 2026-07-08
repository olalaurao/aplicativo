// lib/ui/widgets/day_dial_widget.dart
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../models/day_dial_model.dart';
import '../theme.dart';
import 'package:intl/intl.dart';

/// A circular day dial widget showing 24-hour activity overview
class DayDialWidget extends StatefulWidget {
  final List<DayDialHourState> hourStates;
  final DateTime selectedDate;
  final Function(int)? onHourTap;
  final Function(DialActivity)? onActivityTap;
  final Function(DialActivity, DateTime)? onActivityDrag;

  const DayDialWidget({
    super.key,
    required this.hourStates,
    required this.selectedDate,
    this.onHourTap,
    this.onActivityTap,
    this.onActivityDrag,
  });

  @override
  State<DayDialWidget> createState() => _DayDialWidgetState();
}

class _DayDialWidgetState extends State<DayDialWidget> {
  DialActivity? _draggedActivity;
  DateTime? _dragStartTime;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: GestureDetector(
        onTapUp: (details) => _handleTap(details, context),
        onPanStart: (details) => _handlePanStart(details, context),
        onPanUpdate: (details) => _handlePanUpdate(details, context),
        onPanEnd: (details) => _handlePanEnd(details),
        child: CustomPaint(
          painter: _DayDialPainter(
            hourStates: widget.hourStates,
            selectedDate: widget.selectedDate,
            draggedActivity: _draggedActivity,
            dragStartTime: _dragStartTime,
          ),
          child: Center(
            child: _buildCenterReadout(context),
          ),
        ),
      ),
    );
  }

  void _handleTap(TapUpDetails details, BuildContext context) {
    if (widget.onHourTap == null && widget.onActivityTap == null) return;
    
    final RenderBox box = context.findRenderObject() as RenderBox;
    final localPosition = box.globalToLocal(details.globalPosition);
    final size = box.size;
    final center = Offset(size.width / 2, size.height / 2);
    
    // Calculate angle from center to tap position
    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;
    final angle = atan2(dy, dx);
    
    // Convert angle to hour (0 at top, clockwise)
    final adjustedAngle = angle + (pi / 2);
    final normalizedAngle = (adjustedAngle + 2 * pi) % (2 * pi);
    final hour = ((normalizedAngle / (2 * pi)) * 24).round() % 24;
    
    // Check if an activity was tapped
    final tappedActivity = _findActivityAtPosition(localPosition, size, center);
    if (tappedActivity != null && widget.onActivityTap != null) {
      widget.onActivityTap!(tappedActivity);
    } else if (widget.onHourTap != null) {
      widget.onHourTap!(hour);
    }
  }

  void _handlePanStart(DragStartDetails details, BuildContext context) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final localPosition = box.globalToLocal(details.globalPosition);
    final size = box.size;
    final center = Offset(size.width / 2, size.height / 2);
    
    final tappedActivity = _findActivityAtPosition(localPosition, size, center);
    if (tappedActivity != null && widget.onActivityDrag != null) {
      setState(() {
        _draggedActivity = tappedActivity;
        _dragStartTime = tappedActivity.startTime;
      });
    }
  }

  void _handlePanUpdate(DragUpdateDetails details, BuildContext context) {
    if (_draggedActivity == null) return;
    
    final RenderBox box = context.findRenderObject() as RenderBox;
    final localPosition = box.globalToLocal(details.globalPosition);
    final size = box.size;
    final center = Offset(size.width / 2, size.height / 2);
    
    final newTime = _positionToTime(localPosition, size, center, widget.selectedDate);
    setState(() {
      _dragStartTime = newTime;
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    if (_draggedActivity != null && _dragStartTime != null && widget.onActivityDrag != null) {
      widget.onActivityDrag!(_draggedActivity!, _dragStartTime!);
    }
    setState(() {
      _draggedActivity = null;
      _dragStartTime = null;
    });
  }

  DialActivity? _findActivityAtPosition(Offset position, Size size, Offset center) {
    // Calculate distance from center to determine ring
    final dx = position.dx - center.dx;
    final dy = position.dy - center.dy;
    final distance = sqrt(dx * dx + dy * dy);
    final radius = size.width / 2 - 16;
    
    // Determine which ring was tapped
    final innerRadius = radius * 0.4;
    final outerRadius = radius * 0.85;
    
    if (distance < innerRadius || distance > outerRadius) return null;
    
    // Calculate angle to find hour
    final angle = atan2(dy, dx);
    final adjustedAngle = angle + (pi / 2);
    final normalizedAngle = (adjustedAngle + 2 * pi) % (2 * pi);
    final hour = ((normalizedAngle / (2 * pi)) * 24).round() % 24;
    
    // Return first activity from that hour
    if (hour >= 0 && hour < widget.hourStates.length) {
      final activities = widget.hourStates[hour].activities;
      if (activities.isNotEmpty) {
        return activities.first;
      }
    }
    return null;
  }

  DateTime _positionToTime(Offset position, Size size, Offset center, DateTime date) {
    final dx = position.dx - center.dx;
    final dy = position.dy - center.dy;
    final angle = atan2(dy, dx);
    
    final adjustedAngle = angle + (pi / 2);
    final normalizedAngle = (adjustedAngle + 2 * pi) % (2 * pi);
    
    final totalMinutes = (normalizedAngle / (2 * pi)) * 24 * 60;
    final hour = (totalMinutes / 60).floor();
    final minute = (totalMinutes % 60).round();
    
    return DateTime(date.year, date.month, date.day, hour.clamp(0, 23), minute.clamp(0, 59));
  }

  Widget _buildCenterReadout(BuildContext context) {
    final now = DateTime.now();
    final isToday = _isSameDay(widget.selectedDate, now);
    
    // Calculate next activity
    final nextActivity = _findNextActivity(now);
    final timeUntilNext = nextActivity?.startTime.difference(now);
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          DateFormat('HH:mm').format(now),
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimaryColor(context),
          ),
        ),
        if (isToday && timeUntilNext != null)
          Text(
            _formatTimeUntil(timeUntilNext),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondaryColor(context),
            ),
          ),
        const SizedBox(height: 2),
        Text(
          isToday ? 'Today' : DateFormat('MMM d').format(widget.selectedDate),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondaryColor(context),
          ),
        ),
      ],
    );
  }

  DialActivity? _findNextActivity(DateTime now) {
    final allActivities = widget.hourStates
        .expand((state) => state.activities)
        .where((a) => a.startTime.isAfter(now))
        .toList();
    
    if (allActivities.isEmpty) return null;
    
    allActivities.sort((a, b) => a.startTime.compareTo(b.startTime));
    return allActivities.first;
  }

  String _formatTimeUntil(Duration duration) {
    if (duration.inMinutes < 60) {
      return '${duration.inMinutes}m';
    } else if (duration.inHours < 24) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else {
      return '${duration.inDays}d';
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _DayDialPainter extends CustomPainter {
  final List<DayDialHourState> hourStates;
  final DateTime selectedDate;
  final DialActivity? draggedActivity;
  final DateTime? dragStartTime;

  _DayDialPainter({
    required this.hourStates,
    required this.selectedDate,
    this.draggedActivity,
    this.dragStartTime,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 16; // Padding
    final innerRadius = radius * 0.4; // Center hole
    
    // Ring radii for multi-ring rendering
    final outerRingRadius = radius * 0.85; // Habits, reminders, moods
    
    // Draw background circle
    final backgroundPaint = Paint()
      ..color = const Color(0xFFF1F3F5) // surfaceVariant color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, backgroundPaint);

    // Draw activities using multi-ring rendering
    for (final state in hourStates) {
      // Draw legacy habit icons (for backward compatibility)
      if (state.habitIconName != null) {
        final angle = _hourToAngle(state.hour) + (pi / 24);
        final iconX = center.dx + outerRingRadius * cos(angle);
        final iconY = center.dy + outerRingRadius * sin(angle);
        _drawIcon(canvas, state.habitIconName!, iconX, iconY, 14);
      }
      
      // Draw new activity-based rendering
      for (final activity in state.activities) {
        _drawActivitySegment(canvas, activity, center, innerRadius, radius);
      }
      
      // Draw legacy hour-based arcs (for backward compatibility)
      if (state.fillFraction > 0) {
        final startAngle = _hourToAngle(state.hour);
        final sweepAngle = (2 * pi / 24) * state.fillFraction;
        final arcRadius = innerRadius + (radius - innerRadius) * 0.5;

        final paint = Paint()
          ..color = _getColorForKind(state.kind).withValues(alpha: 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = (radius - innerRadius) * 0.5
          ..strokeCap = StrokeCap.round;

        canvas.drawArc(
          Rect.fromCircle(center: center, radius: arcRadius),
          startAngle,
          sweepAngle,
          false,
          paint,
        );
      }
    }
    
    // Draw drag preview
    if (draggedActivity != null && dragStartTime != null) {
      final previewAngle = _timeToAngle(dragStartTime!);
      _drawDragPreview(canvas, previewAngle, center, radius);
    }

    // Draw current time indicator if today
    final now = DateTime.now();
    if (_isSameDay(selectedDate, now)) {
      final currentAngle = _timeToAngle(now);
      final markerRadius = radius + 8;
      
      final markerX = center.dx + markerRadius * cos(currentAngle);
      final markerY = center.dy + markerRadius * sin(currentAngle);

      final markerPaint = Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(Offset(markerX, markerY), 6, markerPaint);
    }

    // Draw hour labels (12, 3, 6, 9)
    final labelRadius = radius + 24;
    final labelPaint = TextPainter(
      textAlign: TextAlign.center,
      textDirection: ui.TextDirection.ltr,
    );

    final labels = {
      0: '12',
      6: '3',
      12: '6',
      18: '9',
    };

    for (final entry in labels.entries) {
      final angle = _hourToAngle(entry.key);
      final labelX = center.dx + labelRadius * cos(angle);
      final labelY = center.dy + labelRadius * sin(angle);

      labelPaint.text = TextSpan(
        text: entry.value,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textMuted,
        ),
      );
      labelPaint.layout();
      labelPaint.paint(canvas, Offset(labelX - labelPaint.width / 2, labelY - labelPaint.height / 2));
    }
  }

  double _hourToAngle(int hour) {
    // Convert hour to angle (0 at top, clockwise)
    // 0 hours = -pi/2 (top)
    // 6 hours = 0 (right)
    // 12 hours = pi/2 (bottom)
    // 18 hours = pi (left)
    return (hour / 24) * 2 * pi - (pi / 2);
  }

  double _timeToAngle(DateTime time) {
    final totalMinutes = time.hour * 60 + time.minute;
    return (totalMinutes / (24 * 60)) * 2 * pi - (pi / 2);
  }

  void _drawActivitySegment(Canvas canvas, DialActivity activity, Offset center, double innerRadius, double outerRadius) {
    final startAngle = _timeToAngle(activity.startTime);
    final endAngle = _timeToAngle(activity.endTime);
    final sweepAngle = endAngle - startAngle;
    
    // Determine ring based on activity type
    double ringRadius;
    double ringWidth;
    
    switch (activity.type) {
      case DialActivityType.timeBlock:
        ringRadius = innerRadius + (outerRadius - innerRadius) * 0.35;
        ringWidth = (outerRadius - innerRadius) * 0.15;
        break;
      case DialActivityType.event:
      case DialActivityType.pomodoroCompleted:
      case DialActivityType.pomodoroPlanned:
      case DialActivityType.task:
        ringRadius = innerRadius + (outerRadius - innerRadius) * 0.55;
        ringWidth = (outerRadius - innerRadius) * 0.12;
        break;
      case DialActivityType.habit:
      case DialActivityType.reminder:
      case DialActivityType.mood:
        ringRadius = innerRadius + (outerRadius - innerRadius) * 0.75;
        ringWidth = (outerRadius - innerRadius) * 0.10;
        break;
    }
    
    final paint = Paint()
      ..color = activity.color.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth
      ..strokeCap = StrokeCap.round;
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: ringRadius),
      startAngle,
      sweepAngle,
      false,
      paint,
    );
    
    // Draw emoji for activities that have one
    if (activity.emoji != null) {
      _drawEmojiForActivity(canvas, activity, center, ringRadius);
    }
  }
  
  void _drawEmojiForActivity(Canvas canvas, DialActivity activity, Offset center, double ringRadius) {
    if (activity.emoji == null) return;
    
    final midAngle = (_timeToAngle(activity.startTime) + _timeToAngle(activity.endTime)) / 2;
    final emojiX = center.dx + ringRadius * cos(midAngle);
    final emojiY = center.dy + ringRadius * sin(midAngle);
    
    _drawIcon(canvas, activity.emoji!, emojiX, emojiY, 12);
  }
  
  void _drawDragPreview(Canvas canvas, double angle, Offset center, double radius) {
    final paint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(
      Offset(
        center.dx + radius * 0.7 * cos(angle),
        center.dy + radius * 0.7 * sin(angle),
      ),
      12,
      paint,
    );
  }

  Color _getColorForKind(DialHourKind kind) {
    switch (kind) {
      case DialHourKind.idle:
        return AppColors.textMuted.withValues(alpha: 0.2);
      case DialHourKind.sleep:
        return AppColors.textMuted.withValues(alpha: 0.3);
      case DialHourKind.pomodoroCompleted:
        return AppColors.success;
      case DialHourKind.pomodoroPlanned:
        return AppColors.primary.withValues(alpha: 0.6);
      case DialHourKind.event:
        return AppColors.info;
      case DialHourKind.timeBlock:
        return AppColors.warning;
    }
  }

  void _drawIcon(Canvas canvas, String iconName, double x, double y, double size) {
    // Simple emoji/icon rendering
    final textPainter = TextPainter(
      text: TextSpan(
        text: iconName,
        style: TextStyle(
          fontSize: size,
          color: AppColors.textPrimary,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(x - textPainter.width / 2, y - textPainter.height / 2));
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  bool shouldRepaint(_DayDialPainter oldDelegate) {
    return oldDelegate.hourStates != hourStates ||
        !_isSameDay(oldDelegate.selectedDate, selectedDate) ||
        oldDelegate.draggedActivity != draggedActivity ||
        oldDelegate.dragStartTime != dragStartTime;
  }
}

// lib/ui/widgets/compact_day_dial_widget.dart
import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/day_dial_model.dart';
import '../theme.dart';
import 'package:intl/intl.dart';

/// A compact circular day dial widget for use on home screen or other widgets
/// Smaller version of DayDialWidget with minimal UI
class CompactDayDialWidget extends StatelessWidget {
  final List<DayDialHourState> hourStates;
  final DateTime selectedDate;
  final Function()? onTap;
  final double size;

  const CompactDayDialWidget({
    super.key,
    required this.hourStates,
    required this.selectedDate,
    this.onTap,
    this.size = 120,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _CompactDayDialPainter(
            hourStates: hourStates,
            selectedDate: selectedDate,
          ),
          child: Center(
            child: _buildCenterReadout(context),
          ),
        ),
      ),
    );
  }

  Widget _buildCenterReadout(BuildContext context) {
    final now = DateTime.now();
    final isToday = _isSameDay(selectedDate, now);
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          DateFormat('HH:mm').format(now),
          style: TextStyle(
            fontSize: size * 0.18,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimaryColor(context),
          ),
        ),
        if (size > 100)
          Text(
            isToday ? 'Today' : DateFormat('MMM d').format(selectedDate),
            style: TextStyle(
              fontSize: size * 0.08,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondaryColor(context),
            ),
          ),
      ],
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _CompactDayDialPainter extends CustomPainter {
  final List<DayDialHourState> hourStates;
  final DateTime selectedDate;

  _CompactDayDialPainter({
    required this.hourStates,
    required this.selectedDate,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4; // Minimal padding
    final innerRadius = radius * 0.5; // Center hole

    // Draw background circle
    final backgroundPaint = Paint()
      ..color = const Color(0xFFF1F3F5)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, backgroundPaint);

    // Draw hour arcs
    for (final state in hourStates) {
      if (state.fillFraction <= 0) continue;

      final startAngle = _hourToAngle(state.hour);
      final sweepAngle = (2 * pi / 24) * state.fillFraction;
      final arcRadius = innerRadius + (radius - innerRadius) * 0.5;

      final paint = Paint()
        ..color = _getColorForKind(state.kind)
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

    // Draw current time indicator if today
    final now = DateTime.now();
    if (_isSameDay(selectedDate, now)) {
      final currentAngle = _timeToAngle(now);
      final markerRadius = radius + 4;
      
      final markerX = center.dx + markerRadius * cos(currentAngle);
      final markerY = center.dy + markerRadius * sin(currentAngle);

      final markerPaint = Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(Offset(markerX, markerY), 4, markerPaint);
    }
  }

  double _hourToAngle(int hour) {
    return (hour / 24) * 2 * pi - (pi / 2);
  }

  double _timeToAngle(DateTime time) {
    final totalMinutes = time.hour * 60 + time.minute;
    return (totalMinutes / (24 * 60)) * 2 * pi - (pi / 2);
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
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  bool shouldRepaint(_CompactDayDialPainter oldDelegate) {
    return oldDelegate.hourStates != hourStates ||
        !_isSameDay(oldDelegate.selectedDate, selectedDate);
  }
}

// lib/ui/widgets/day_dial_widget.dart
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../models/day_dial_model.dart';
import '../theme.dart';
import 'package:intl/intl.dart';

/// A circular day dial widget showing 24-hour activity overview
class DayDialWidget extends StatelessWidget {
  final List<DayDialHourState> hourStates;
  final DateTime selectedDate;
  final Function(int)? onHourTap;

  const DayDialWidget({
    super.key,
    required this.hourStates,
    required this.selectedDate,
    this.onHourTap,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: GestureDetector(
        onTapUp: (details) {
          if (onHourTap == null) return;
          
          final RenderBox box = context.findRenderObject() as RenderBox;
          final localPosition = box.globalToLocal(details.globalPosition);
          final size = box.size;
          final center = Offset(size.width / 2, size.height / 2);
          
          // Calculate angle from center to tap position
          final dx = localPosition.dx - center.dx;
          final dy = localPosition.dy - center.dy;
          final angle = atan2(dy, dx);
          
          // Convert angle to hour (0 at top, clockwise)
          // atan2 returns -pi to pi, with 0 at 3 o'clock
          // We need 0 at 12 o'clock (top)
          final adjustedAngle = angle + (pi / 2); // Rotate so 0 is at top
          final normalizedAngle = (adjustedAngle + 2 * pi) % (2 * pi); // Normalize to 0-2pi
          final hour = ((normalizedAngle / (2 * pi)) * 24).round() % 24;
          
          onHourTap!(hour);
        },
        child: CustomPaint(
          painter: _DayDialPainter(
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
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimaryColor(context),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          isToday ? 'Today' : DateFormat('MMM d').format(selectedDate),
          style: TextStyle(
            fontSize: 12,
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

class _DayDialPainter extends CustomPainter {
  final List<DayDialHourState> hourStates;
  final DateTime selectedDate;

  _DayDialPainter({
    required this.hourStates,
    required this.selectedDate,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 16; // Padding
    final innerRadius = radius * 0.4; // Center hole
    final iconRingRadius = radius * 0.7; // Ring for habit icons

    // Draw background circle
    final backgroundPaint = Paint()
      ..color = const Color(0xFFF1F3F5) // surfaceVariant color
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
        ..strokeWidth = (radius - innerRadius) * 0.6
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: arcRadius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }

    // Draw habit icons on icon ring
    for (final state in hourStates) {
      if (state.habitIconName == null) continue;

      final angle = _hourToAngle(state.hour) + (pi / 24); // Center of hour
      final iconX = center.dx + iconRingRadius * cos(angle);
      final iconY = center.dy + iconRingRadius * sin(angle);

      _drawIcon(canvas, state.habitIconName!, iconX, iconY, 16);
    }

    // Draw current time indicator if today
    final now = DateTime.now();
    if (_isSameDay(selectedDate, now)) {
      final currentAngle = _timeToAngle(now);
      final markerRadius = radius + 8;
      
      final markerX = center.dx + markerRadius * cos(currentAngle);
      final markerY = center.dy + markerRadius * sin(currentAngle);

      final markerPaint = Paint()
        ..color = AppColors.accent
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
        style: TextStyle(
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

  Color _getColorForKind(DialHourKind kind) {
    switch (kind) {
      case DialHourKind.idle:
        return AppColors.textMuted.withValues(alpha: 0.2);
      case DialHourKind.sleep:
        return AppColors.textMuted.withValues(alpha: 0.3);
      case DialHourKind.pomodoroCompleted:
        return AppColors.success;
      case DialHourKind.pomodoroPlanned:
        return AppColors.accent.withValues(alpha: 0.6);
      case DialHourKind.event:
        return AppColors.info;
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
        !_isSameDay(oldDelegate.selectedDate, selectedDate);
  }
}

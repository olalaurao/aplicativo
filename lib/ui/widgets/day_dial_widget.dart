// lib/ui/widgets/day_dial_widget.dart
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../models/day_dial_model.dart';
import '../theme.dart';
import 'package:intl/intl.dart';

class DayDialWidget extends StatefulWidget {
  final DayDialSnapshot snapshot;
  final DateTime selectedDate;
  final void Function(DialSegment segment)? onSegmentTap;
  final void Function(int hour)? onHourTap;
  final void Function(DialSegment segment, DateTime newStart)? onSegmentMove;
  final void Function(DialSegment segment, DateTime newEnd)? onSegmentResize;

  const DayDialWidget({
    super.key,
    required this.snapshot,
    required this.selectedDate,
    this.onSegmentTap,
    this.onHourTap,
    this.onSegmentMove,
    this.onSegmentResize,
  });

  @override
  State<DayDialWidget> createState() => _DayDialWidgetState();
}

class _DayDialWidgetState extends State<DayDialWidget> {
  DialSegment? _draggedSegment;
  bool _isResizingEnd = false;
  bool _isResizingStart = false;
  DateTime? _dragPreviewStart;
  DateTime? _dragPreviewEnd;
  Offset? _dragPreviewTooltipPos;

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
            snapshot: widget.snapshot,
            selectedDate: widget.selectedDate,
            draggedSegment: _draggedSegment,
            dragPreviewStart: _dragPreviewStart,
            dragPreviewEnd: _dragPreviewEnd,
          ),
          child: Stack(
            children: [
              Center(child: _buildCenterReadout(context)),
              if (_draggedSegment != null && _dragPreviewStart != null && _dragPreviewEnd != null && _dragPreviewTooltipPos != null)
                Positioned(
                  left: _dragPreviewTooltipPos!.dx - 40,
                  top: _dragPreviewTooltipPos!.dy - 30,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _isResizingEnd || _isResizingStart
                          ? '${DateFormat('HH:mm').format(_dragPreviewStart!)}–${DateFormat('HH:mm').format(_dragPreviewEnd!)}'
                          : DateFormat('HH:mm').format(_dragPreviewStart!),
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleTap(TapUpDetails details, BuildContext context) {
    if (widget.onSegmentTap == null && widget.onHourTap == null) return;
    
    final RenderBox box = context.findRenderObject() as RenderBox;
    final localPosition = box.globalToLocal(details.globalPosition);
    final size = box.size;
    final center = Offset(size.width / 2, size.height / 2);
    
    bool isResizeStart = false;
    bool isResizeEnd = false;
    final tapped = _hitTestSegment(localPosition, size, center, (rs) => isResizeStart = rs, (re) => isResizeEnd = re);
    
    if (tapped != null && widget.onSegmentTap != null) {
      widget.onSegmentTap!(tapped);
    } else if (widget.onHourTap != null) {
      final angle = atan2(localPosition.dy - center.dy, localPosition.dx - center.dx);
      final adjusted = angle + (pi / 2);
      final normalized = (adjusted + 2 * pi) % (2 * pi);
      final hour = ((normalized / (2 * pi)) * 24).round() % 24;
      widget.onHourTap!(hour);
    }
  }

  void _handlePanStart(DragStartDetails details, BuildContext context) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final localPosition = box.globalToLocal(details.globalPosition);
    final size = box.size;
    final center = Offset(size.width / 2, size.height / 2);
    
    bool isResizeStart = false;
    bool isResizeEnd = false;
    final tapped = _hitTestSegment(localPosition, size, center, (rs) => isResizeStart = rs, (re) => isResizeEnd = re);
    
    if (tapped != null && tapped.isEditable) {
      setState(() {
        _draggedSegment = tapped;
        _isResizingStart = isResizeStart;
        _isResizingEnd = isResizeEnd;
        _dragPreviewStart = tapped.start;
        _dragPreviewEnd = tapped.end;
        _dragPreviewTooltipPos = localPosition;
      });
    }
  }

  void _handlePanUpdate(DragUpdateDetails details, BuildContext context) {
    if (_draggedSegment == null) return;
    
    final RenderBox box = context.findRenderObject() as RenderBox;
    final localPosition = box.globalToLocal(details.globalPosition);
    final size = box.size;
    final center = Offset(size.width / 2, size.height / 2);
    
    final newTime = _positionToTime(localPosition, size, center, widget.selectedDate);
    
    // Snap to 5 minutes
    final snappedMinute = (newTime.minute / 5).round() * 5;
    var snappedTime = DateTime(newTime.year, newTime.month, newTime.day, newTime.hour, snappedMinute);
    
    setState(() {
      _dragPreviewTooltipPos = localPosition;
      
      final dur = _draggedSegment!.end.difference(_draggedSegment!.start);
      if (_isResizingStart) {
        if (_draggedSegment!.end.difference(snappedTime).inMinutes >= 5) {
          _dragPreviewStart = snappedTime;
        }
      } else if (_isResizingEnd) {
        if (snappedTime.difference(_draggedSegment!.start).inMinutes >= 5) {
          _dragPreviewEnd = snappedTime;
        }
      } else {
        _dragPreviewStart = snappedTime;
        _dragPreviewEnd = snappedTime.add(dur);
      }
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    if (_draggedSegment != null && _dragPreviewStart != null) {
      if (_isResizingEnd && widget.onSegmentResize != null) {
        widget.onSegmentResize!(_draggedSegment!, _dragPreviewEnd!);
      } else if (_isResizingStart && widget.onSegmentResize != null) {
        widget.onSegmentResize!(_draggedSegment!, _dragPreviewEnd!);
        if (widget.onSegmentMove != null) {
          widget.onSegmentMove!(_draggedSegment!, _dragPreviewStart!);
        }
      } else if (widget.onSegmentMove != null) {
        widget.onSegmentMove!(_draggedSegment!, _dragPreviewStart!);
      }
    }
    setState(() {
      _draggedSegment = null;
      _dragPreviewStart = null;
      _dragPreviewEnd = null;
      _dragPreviewTooltipPos = null;
    });
  }

  DialSegment? _hitTestSegment(Offset position, Size size, Offset center, void Function(bool) setResizeStart, void Function(bool) setResizeEnd) {
    final dx = position.dx - center.dx;
    final dy = position.dy - center.dy;
    final distance = sqrt(dx * dx + dy * dy);
    final radius = size.width / 2 - 16;
    final innerRadius = radius * 0.4;
    final ringWidth = (radius - innerRadius) / 5;
    
    final angle = atan2(dy, dx);
    final adjustedAngle = angle + (pi / 2);
    final normalizedAngle = (adjustedAngle + 2 * pi) % (2 * pi);
    
    for (final s in widget.snapshot.segments.reversed) {
      double sRingStart = innerRadius + (s.layer + 1) * ringWidth;
      double sRingEnd = sRingStart + ringWidth;
      if (s.layer == -1) {
        sRingStart = innerRadius;
        sRingEnd = innerRadius + ringWidth;
      }
      
      if (distance >= sRingStart && distance <= sRingEnd) {
        double startAngle = _dateTimeToAngle(s.start);
        double endAngle = startAngle + _sweepAngle(s);
        
        startAngle = (startAngle + 2*pi) % (2*pi);
        endAngle = (endAngle + 2*pi) % (2*pi);
        
        bool inAngle = false;
        if (startAngle <= endAngle) {
          inAngle = normalizedAngle >= startAngle && normalizedAngle <= endAngle;
        } else {
          inAngle = normalizedAngle >= startAngle || normalizedAngle <= endAngle;
        }
        
        if (inAngle) {
          double dur = s.end.difference(s.start).inMinutes.toDouble();
          if (dur <= 0) dur += 24*60;
          
          double minDiff = 0;
          if (startAngle <= endAngle) {
            minDiff = (normalizedAngle - startAngle) / (2*pi) * 24 * 60;
          } else {
            if (normalizedAngle >= startAngle) {
              minDiff = (normalizedAngle - startAngle) / (2*pi) * 24 * 60;
            } else {
              minDiff = ((normalizedAngle + 2*pi) - startAngle) / (2*pi) * 24 * 60;
            }
          }
          
          if (s.isResizable && s.kind != DialSegmentKind.habitSlot && s.kind != DialSegmentKind.reminder) {
            if (minDiff < dur * 0.15) {
              setResizeStart(true);
            } else if (minDiff > dur * 0.85) {
              setResizeEnd(true);
            }
          }
          return s;
        }
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

  String _formatCountdown(DialSegment next, DateTime now) {
    final diff = next.start.difference(now);
    if (diff.isNegative) return 'Now — ${next.title}';
    if (diff.inMinutes < 60) return 'in ${diff.inMinutes}m — ${next.title}';
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    return 'in ${h}h ${m}m — ${next.title}';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _DayDialPainter extends CustomPainter {
  final DayDialSnapshot snapshot;
  final DateTime selectedDate;
  final DialSegment? draggedSegment;
  final DateTime? dragPreviewStart;
  final DateTime? dragPreviewEnd;

  _DayDialPainter({
    required this.snapshot,
    required this.selectedDate,
    this.draggedSegment,
    this.dragPreviewStart,
    this.dragPreviewEnd,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 16;
    final innerRadius = radius * 0.4;
    final ringWidth = (radius - innerRadius) / 5;
    
    // Background
    final backgroundPaint = Paint()
      ..color = const Color(0xFFF1F3F5)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, backgroundPaint);

    // Draw Segments
    for (final s in snapshot.segments) {
      if (s == draggedSegment) continue;
      _drawSegment(canvas, s, center, innerRadius, ringWidth);
    }
    
    // Draw Drag Preview
    if (draggedSegment != null && dragPreviewStart != null && dragPreviewEnd != null) {
      final previewSegment = DialSegment(
        id: draggedSegment!.id,
        kind: draggedSegment!.kind,
        start: dragPreviewStart!,
        end: dragPreviewEnd!,
        title: draggedSegment!.title,
        colorHex: draggedSegment!.colorHex,
        emoji: draggedSegment!.emoji,
        isEditable: draggedSegment!.isEditable,
        isResizable: draggedSegment!.isResizable,
        layer: draggedSegment!.layer,
      );
      _drawSegment(canvas, previewSegment, center, innerRadius, ringWidth, isDragging: true);
    }
    
    // Draw Mood Markers
    for (final m in snapshot.moodMarkers) {
      final angle = _dateTimeToAngle(m.timestamp);
      final mRadius = radius - 8;
      final x = center.dx + mRadius * cos(angle);
      final y = center.dy + mRadius * sin(angle);
      _drawIcon(canvas, m.emoji, x, y, 12);
    }

    // Current time indicator
    final now = DateTime.now();
    if (_isSameDay(selectedDate, now)) {
      final currentAngle = _timeToAngle(now);
      final markerRadius = radius + 8;
      final markerX = center.dx + markerRadius * cos(currentAngle);
      final markerY = center.dy + markerRadius * sin(currentAngle);

      final markerPaint = Paint()
        ..color = const Color(0xFFFF3B30) // AppColors.error / bright red
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(markerX, markerY), 4, markerPaint);
    }

    // Labels
    final labelRadius = radius + 24;
    final labelPaint = TextPainter(
      textAlign: TextAlign.center,
      textDirection: ui.TextDirection.ltr,
    );
    final labels = {0: '12', 6: '3', 12: '6', 18: '9'};
    for (final entry in labels.entries) {
      final angle = _hourToAngle(entry.key);
      final labelX = center.dx + labelRadius * cos(angle);
      final labelY = center.dy + labelRadius * sin(angle);

      labelPaint.text = TextSpan(
        text: entry.value,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
      );
      labelPaint.layout();
      labelPaint.paint(canvas, Offset(labelX - labelPaint.width / 2, labelY - labelPaint.height / 2));
    }
  }

  void _drawSegment(Canvas canvas, DialSegment s, Offset center, double innerRadius, double ringWidth, {bool isDragging = false}) {
    double ringRadius = innerRadius + (s.layer + 1) * ringWidth + ringWidth/2;
    if (s.layer == -1) {
      ringRadius = innerRadius + ringWidth/2;
    }
    
    final startAngle = _dateTimeToAngle(s.start);
    var sweep = _sweepAngle(s);
    
    // Min 3 degrees for visibility
    if (sweep < 3 * pi / 180 && s.kind != DialSegmentKind.habitSlot && s.kind != DialSegmentKind.reminder) {
      sweep = 3 * pi / 180;
    }
    
    final paint = Paint()
      ..color = _parseColor(s.colorHex).withValues(alpha: isDragging ? 0.9 : (s.layer == -1 ? 0.3 : 0.8))
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth * 0.5
      ..strokeCap = StrokeCap.butt;
      
    if (isDragging) {
      paint.color = paint.color.withValues(alpha: 1.0);
      paint.strokeWidth = ringWidth * 0.9;
    }

    if (s.kind == DialSegmentKind.habitSlot || s.kind == DialSegmentKind.reminder) {
      // Draw as a point
      if (s.emoji != null) {
        final x = center.dx + ringRadius * cos(startAngle);
        final y = center.dy + ringRadius * sin(startAngle);
        _drawIcon(canvas, s.emoji!, x, y, 14);
      }
    } else {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: ringRadius),
        startAngle,
        sweep,
        false,
        paint,
      );
    }
  }

  void _drawIcon(Canvas canvas, String iconName, double x, double y, double size) {
    final textPainter = TextPainter(
      text: TextSpan(text: iconName, style: TextStyle(fontSize: size)),
      textDirection: ui.TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(x - textPainter.width / 2, y - textPainter.height / 2));
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Color _parseColor(String colorString) {
    if (colorString.startsWith('#')) {
      return Color(int.parse(colorString.replaceFirst('#', '0xFF')));
    }
    return Colors.grey;
  }

  double _hourToAngle(int hour) {
    return (hour / 24) * 2 * pi - (pi / 2);
  }

  double _timeToAngle(DateTime time) {
    final totalMinutes = time.hour * 60 + time.minute;
    return (totalMinutes / (24 * 60)) * 2 * pi - (pi / 2);
  }

  @override
  bool shouldRepaint(covariant _DayDialPainter oldDelegate) {
    return oldDelegate.snapshot != snapshot ||
        oldDelegate.selectedDate != selectedDate ||
        oldDelegate.draggedSegment != draggedSegment ||
        oldDelegate.dragPreviewStart != dragPreviewStart ||
        oldDelegate.dragPreviewEnd != dragPreviewEnd;
  }
}

double _dateTimeToAngle(DateTime dt) {
  final minutesFromMidnight = dt.hour * 60 + dt.minute + dt.second / 60.0;
  return (minutesFromMidnight / (24 * 60)) * 2 * pi - (pi / 2);
}

double _sweepAngle(DialSegment s) {
  var minutes = s.end.difference(s.start).inMinutes.toDouble();
  if (minutes <= 0) minutes += 24 * 60;
  return (minutes / (24 * 60)) * 2 * pi;
}

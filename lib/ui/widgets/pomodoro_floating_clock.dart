import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/pomodoro_session.dart';
import '../../providers/pomodoro_provider.dart';
import '../theme.dart';

class PomodoroFloatingClock extends ConsumerStatefulWidget {
  final Widget child;

  const PomodoroFloatingClock({super.key, required this.child});

  @override
  ConsumerState<PomodoroFloatingClock> createState() => _PomodoroFloatingClockState();
}

class _PomodoroFloatingClockState extends ConsumerState<PomodoroFloatingClock> {
  Offset? _offset;
  bool _isDragging = false;
  bool _showDismissZone = false;
  bool _wasInitialized = false;

  @override
  Widget build(BuildContext context) {
    final pomodoro = ref.watch(pomodoroProvider);
    final showClock = pomodoro.isRunning;

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final screenHeight = constraints.maxHeight;

        // Initialize position on first run or layout size change
        if (!_wasInitialized && screenWidth > 0 && screenHeight > 0) {
          _offset = Offset(screenWidth - 88, screenHeight - 180);
          _wasInitialized = true;
        }

        // Clamp offset to keep inside screen bounds
        if (_offset != null) {
          _offset = Offset(
            _offset!.dx.clamp(16.0, max(16.0, screenWidth - 88)),
            _offset!.dy.clamp(16.0, max(16.0, screenHeight - 160)),
          );
        }

        final isOverDismissZone = _isDragging &&
            _offset != null &&
            _offset!.dy > screenHeight - 140;

        return Stack(
          children: [
            widget.child,
            if (showClock && _offset != null) ...[
              // ─── Bottom Dismiss/Trash Zone ───
              if (_showDismissZone)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 30,
                  child: Center(
                    child: AnimatedScale(
                      scale: isOverDismissZone ? 1.15 : 1.0,
                      duration: const Duration(milliseconds: 150),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        decoration: BoxDecoration(
                          color: isOverDismissZone
                              ? AppColors.error.withValues(alpha: 0.9)
                              : Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: (isOverDismissZone ? AppColors.error : Colors.black)
                                  .withValues(alpha: 0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isOverDismissZone
                                  ? Icons.delete_forever_rounded
                                  : Icons.delete_outline_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              isOverDismissZone
                                  ? 'Solte para fechar'
                                  : 'Arraste até aqui para fechar',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // ─── Floating Clock Circle ───
              Positioned(
                left: _offset!.dx,
                top: _offset!.dy,
                child: GestureDetector(
                  onPanStart: (_) {
                    setState(() {
                      _isDragging = true;
                      _showDismissZone = true;
                    });
                    HapticFeedback.selectionClick();
                  },
                  onPanUpdate: (details) {
                    setState(() {
                      _offset = _offset! + details.delta;
                    });
                  },
                  onPanEnd: (_) {
                    setState(() {
                      _isDragging = false;
                      _showDismissZone = false;
                    });
                    if (isOverDismissZone) {
                      HapticFeedback.mediumImpact();
                      ref.read(pomodoroProvider.notifier).stop();
                    } else {
                      HapticFeedback.lightImpact();
                    }
                  },
                  child: AnimatedOpacity(
                    opacity: _isDragging ? 0.6 : 0.85,
                    duration: const Duration(milliseconds: 100),
                    child: _ClockWidget(
                      remainingSeconds: pomodoro.remainingSeconds,
                      totalSeconds: pomodoro.totalSeconds,
                      type: pomodoro.currentType,
                      onTap: () {
                        if (!_isDragging) {
                          context.push('/pomodoro');
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ClockWidget extends StatelessWidget {
  final int remainingSeconds;
  final int totalSeconds;
  final PomodoroType type;
  final VoidCallback onTap;

  const _ClockWidget({
    required this.remainingSeconds,
    required this.totalSeconds,
    required this.type,
    required this.onTap,
  });

  Color _phaseColor(PomodoroType type) {
    switch (type) {
      case PomodoroType.work:
        return AppColors.error;
      case PomodoroType.shortBreak:
        return AppColors.habitGreen;
      case PomodoroType.longBreak:
        return AppColors.primary;
      default:
        return AppColors.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    final label =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    final progress = totalSeconds <= 0 ? 0.0 : remainingSeconds / totalSeconds;
    final activeColor = _phaseColor(type);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(36),
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.82),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: CustomPaint(
            painter: CircularTimerPainter(
              progress: progress,
              color: activeColor,
            ),
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Courier', // Monospaced font
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CircularTimerPainter extends CustomPainter {
  final double progress;
  final Color color;

  CircularTimerPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 3;

    final paint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, radius, paint);

    final activePaint = Paint()
      ..color = color
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(rect, -pi / 2, 2 * pi * progress, false, activePaint);
  }

  @override
  bool shouldRepaint(covariant CircularTimerPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

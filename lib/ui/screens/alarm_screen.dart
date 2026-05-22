// lib/ui/screens/alarm_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/notification_service.dart';
import '../../providers/vault_provider.dart';
import '../../models/reminder_config.dart';
import '../../models/task_model.dart';

/// The type of alarm, each with its own color/icon.
enum AlarmType { alarm, task, event, reminder }

/// Data passed to the alarm screen via route extra or static setter.
class AlarmData {
  final String title;
  final String body;
  final AlarmType type;
  final String? objectId;
  final int? notificationId;
  final Color? customColor;

  const AlarmData({
    required this.title,
    required this.body,
    this.type = AlarmType.alarm,
    this.objectId,
    this.notificationId,
    this.customColor,
  });
}

class AlarmScreen extends ConsumerStatefulWidget {
  final AlarmData data;
  const AlarmScreen({super.key, required this.data});

  @override
  ConsumerState<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends ConsumerState<AlarmScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  late final Timer _elapsedTimer;
  int _elapsedSeconds = 0;
  int _repeatCount = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });

    // Vibrate on open
    HapticFeedback.heavyImpact();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _elapsedTimer.cancel();
    super.dispose();
  }

  Color get _primaryColor {
    if (widget.data.customColor != null) return widget.data.customColor!;
    switch (widget.data.type) {
      case AlarmType.alarm:
        return const Color(0xFFEF4444); // Red
      case AlarmType.task:
        return const Color(0xFF3B82F6); // Blue
      case AlarmType.event:
        return const Color(0xFF8B5CF6); // Purple
      case AlarmType.reminder:
        return const Color(0xFFF97316); // Orange
    }
  }

  Color get _primaryColorDark {
    final hsl = HSLColor.fromColor(_primaryColor);
    return hsl.withLightness((hsl.lightness - 0.15).clamp(0.0, 1.0)).toColor();
  }

  IconData get _typeIcon {
    switch (widget.data.type) {
      case AlarmType.alarm:
        return Icons.alarm_rounded;
      case AlarmType.task:
        return Icons.check_box_rounded;
      case AlarmType.event:
        return Icons.event_rounded;
      case AlarmType.reminder:
        return Icons.notifications_active_rounded;
    }
  }

  String get _elapsedFormatted {
    final m = _elapsedSeconds ~/ 60;
    final s = _elapsedSeconds % 60;
    return '${m.toString().padLeft(1, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _snooze(int minutes) {
    HapticFeedback.mediumImpact();
    setState(() => _repeatCount++);

    NotificationService().scheduleReminder(
      id: DateTime.now().millisecondsSinceEpoch % 100000,
      title: widget.data.title,
      config: ReminderConfig(
        id: '${widget.data.notificationId ?? DateTime.now().millisecondsSinceEpoch}_snooze',
        triggerTime: DateTime.now().add(Duration(minutes: minutes)),
        type: widget.data.type == AlarmType.alarm
            ? NotificationType.alarm
            : NotificationType.popup,
        notificationBody: widget.data.body,
        snoozeMinutes: minutes,
      ),
      payload: widget.data.objectId,
    );

    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      SystemNavigator.pop();
    }
  }

  Future<void> _markDone() async {
    HapticFeedback.mediumImpact();

    if (widget.data.objectId != null) {
      try {
        final allObjects =
            ref.read(allObjectsProvider).valueOrNull ?? [];
        final obj = allObjects.firstWhere(
          (o) => o.id == widget.data.objectId,
          orElse: () => allObjects.first,
        );
        if (obj is Task) {
          final updated = obj.copyWith(stage: TaskStage.finalized);
          await ref.read(tasksProvider.notifier).updateTask(updated);
        }
      } catch (e) {
        debugPrint('AlarmScreen: Failed to mark done: $e');
      }
    }

    if (widget.data.notificationId != null) {
      await NotificationService().cancelNotification(widget.data.notificationId!);
    }

    if (mounted) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        SystemNavigator.pop();
      }
    }
  }

  void _dismiss() {
    HapticFeedback.lightImpact();

    if (widget.data.notificationId != null) {
      NotificationService().cancelNotification(widget.data.notificationId!);
    }

    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    // Day of week + date
    const weekdays = [
      'segunda',
      'terça',
      'quarta',
      'quinta',
      'sexta',
      'sábado',
      'domingo'
    ];
    const months = [
      'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
      'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro'
    ];
    final dateStr =
        '${weekdays[now.weekday - 1]}, ${now.day} de ${months[now.month - 1]}';

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_primaryColor, _primaryColorDark],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 2),

                // Animated icon
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Icon(
                    _typeIcon,
                    size: 72,
                    color: Colors.white.withValues(alpha: 0.95),
                  ),
                ),

                const SizedBox(height: 24),

                // Time
                Text(
                  timeStr,
                  style: const TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),

                // Date
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),

                const SizedBox(height: 24),

                // Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    widget.data.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),

                if (widget.data.body.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      widget.data.body,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Repeat count badge
                if (_repeatCount > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.repeat_rounded,
                            size: 14, color: Colors.white.withValues(alpha: 0.9)),
                        const SizedBox(width: 6),
                        Text(
                          'Repetindo ${_repeatCount}x',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 12),

                // Elapsed timer
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.timer_outlined,
                        size: 16, color: Colors.white.withValues(alpha: 0.7)),
                    const SizedBox(width: 6),
                    Text(
                      'Tocando há $_elapsedFormatted',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),

                const Spacer(flex: 2),

                // Action: Mark as done (only for tasks)
                if (widget.data.type == AlarmType.task) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: _markDone,
                        icon: const Icon(Icons.check_rounded, size: 20),
                        label: const Text(
                          'Marcar como Concluído',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: _primaryColor,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Snooze buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Row(
                    children: [
                      _snoozeButton(5),
                      const SizedBox(width: 10),
                      _snoozeButton(10),
                      const SizedBox(width: 10),
                      _snoozeButton(15),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Dismiss button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: _dismiss,
                      icon: Icon(Icons.close_rounded,
                          size: 18, color: Colors.white.withValues(alpha: 0.9)),
                      label: Text(
                        'Dispensar',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.15),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ),

                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _snoozeButton(int minutes) {
    return Expanded(
      child: SizedBox(
        height: 48,
        child: OutlinedButton(
          onPressed: () => _snooze(minutes),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            foregroundColor: Colors.white,
          ),
          child: Text(
            '${minutes}min',
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

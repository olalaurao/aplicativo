// lib/ui/screens/popup_notification_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';
import '../../services/notification_service.dart';
import '../../models/reminder_config.dart';
import '../../models/reminder_model.dart';
import '../../models/habit_model.dart';
import '../../models/task_model.dart';
import '../../providers/vault_provider.dart';

/// Data passed to the popup screen via notification fullScreenIntent.
class PopupScreenData {
  final String title;
  final String body;
  final PopupScreenType type;
  final String? objectId;
  final int? notificationId;
  final Color? customColor;

  const PopupScreenData({
    required this.title,
    required this.body,
    this.type = PopupScreenType.reminder,
    this.objectId,
    this.notificationId,
    this.customColor,
  });
}

enum PopupScreenType { task, event, habit, reminder }

/// Full-screen popup notification that appears even on lock screen / screen off.
/// Uses a semi-transparent background with a centered banner card.
class PopupNotificationScreen extends ConsumerStatefulWidget {
  final PopupScreenData data;
  const PopupNotificationScreen({super.key, required this.data});

  @override
  ConsumerState<PopupNotificationScreen> createState() =>
      _PopupNotificationScreenState();
}

class _PopupNotificationScreenState
    extends ConsumerState<PopupNotificationScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;
  Timer? _autoTimer;
  double _progress = 1.0;
  late final Timer _progressTimer;

  static const _autoDismissMs = 10000;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOut),
    );
    _slideController.forward();

    HapticFeedback.mediumImpact();

    _autoTimer = Timer(
      const Duration(milliseconds: _autoDismissMs),
      _dismiss,
    );

    _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) {
        setState(() {
          _progress -= 100 / _autoDismissMs;
          if (_progress < 0) _progress = 0;
        });
      }
    });
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _progressTimer.cancel();
    _slideController.dispose();
    super.dispose();
  }

  Color get _accentColor {
    if (widget.data.customColor != null) return widget.data.customColor!;
    switch (widget.data.type) {
      case PopupScreenType.task:
        return const Color(0xFF3B82F6);
      case PopupScreenType.event:
        return const Color(0xFF8B5CF6);
      case PopupScreenType.habit:
        return const Color(0xFF22C55E);
      case PopupScreenType.reminder:
        return const Color(0xFF9CA3AF);
    }
  }

  IconData get _typeIcon {
    switch (widget.data.type) {
      case PopupScreenType.task:
        return Icons.check_box_outlined;
      case PopupScreenType.event:
        return Icons.event_rounded;
      case PopupScreenType.habit:
        return Icons.spa_rounded;
      case PopupScreenType.reminder:
        return Icons.notifications_outlined;
    }
  }

  void _dismiss() {
    _autoTimer?.cancel();
    _progressTimer.cancel();
    if (widget.data.notificationId != null) {
      NotificationService().cancelNotification(widget.data.notificationId!);
    }
    _pop();
  }

  void _snooze(int minutes) {
    HapticFeedback.mediumImpact();
    _autoTimer?.cancel();
    _progressTimer.cancel();

    NotificationService().scheduleReminder(
      id: DateTime.now().millisecondsSinceEpoch % 100000,
      title: widget.data.title,
      config: ReminderConfig(
        id: '${widget.data.notificationId ?? DateTime.now().millisecondsSinceEpoch}_snooze',
        triggerTime: DateTime.now().add(Duration(minutes: minutes)),
        type: NotificationType.popup,
        notificationBody: widget.data.body,
        snoozeMinutes: minutes,
      ),
      payload: widget.data.objectId,
    );

    _pop();
  }

  Future<void> _markDone() async {
    HapticFeedback.mediumImpact();
    _autoTimer?.cancel();
    _progressTimer.cancel();

    if (widget.data.objectId != null) {
      try {
        final allObjects = ref.read(allObjectsProvider).valueOrNull ?? [];
        final obj = allObjects.where(
          (o) => o.id == widget.data.objectId,
        ).firstOrNull;

        if (obj is Task) {
          final updated = obj.copyWith(stage: TaskStage.finalized);
          await ref.read(tasksProvider.notifier).updateTask(updated);
        } else if (obj is Reminder) {
          obj.isCompleted = true;
          await ref.read(remindersProvider.notifier).updateReminder(obj);
        } else if (obj is Habit) {
          await ref.read(habitsProvider.notifier).toggleHabit(obj, DateTime.now());
        } else if (obj == null) {
          debugPrint('PopupScreen: object ${widget.data.objectId} not found');
        }
      } catch (e) {
        debugPrint('PopupScreen: Failed to mark done: $e');
      }
    }

    if (widget.data.notificationId != null) {
      await NotificationService()
          .cancelNotification(widget.data.notificationId!);
    }

    _pop();
  }

  void _pop() {
    if (mounted) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        SystemNavigator.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: Colors.black.withValues(alpha: 0.6),
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: GestureDetector(
            onTap: _dismiss,
            behavior: HitTestBehavior.opaque,
            child: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  // Popup card
                  SlideTransition(
                    position: _slideAnimation,
                    child: GestureDetector(
                      onTap: () {}, // Prevent tap-through
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 30,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Progress bar
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(20)),
                                child: LinearProgressIndicator(
                                  value: _progress.clamp(0.0, 1.0),
                                  minHeight: 3,
                                  backgroundColor: Colors.transparent,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    _accentColor.withValues(alpha: 0.7),
                                  ),
                                ),
                              ),

                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 14, 16, 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Icon
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: _accentColor.withValues(alpha: 0.12),
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                      child: Icon(_typeIcon,
                                          size: 24, color: _accentColor),
                                    ),
                                    const SizedBox(width: 14),
                                    // Content
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // App name + time
                                          Row(
                                            children: [
                                              Text(
                                                'CITRINE',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w800,
                                                  color: _accentColor,
                                                  letterSpacing: 1,
                                                ),
                                              ),
                                              const Spacer(),
                                              Text(
                                                timeStr,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Theme.of(context).brightness == Brightness.dark
                                                      ? AppColors.darkTextSecondary
                                                      : AppColors.textMuted,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            widget.data.title,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          if (widget.data.body.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              widget.data.body,
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Theme.of(context).brightness == Brightness.dark
                                                    ? AppColors.darkTextSecondary
                                                    : AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Action buttons
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 4, 16, 14),
                                child: Row(
                                  children: [
                                    _actionButton(
                                      'Adiar 10min',
                                      Icons.snooze_rounded,
                                      onTap: () => _snooze(10),
                                    ),
                                    const SizedBox(width: 8),
                                    if (widget.data.type == PopupScreenType.task ||
                                        widget.data.type == PopupScreenType.reminder ||
                                        widget.data.type == PopupScreenType.habit) ...[
                                      _actionButton(
                                        'Concluído',
                                        Icons.check_rounded,
                                        onTap: _markDone,
                                        filled: true,
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    _actionButton(
                                      'OK',
                                      Icons.close_rounded,
                                      onTap: _dismiss,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
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
      ),
    );
  }

  Widget _actionButton(
    String label,
    IconData icon, {
    required VoidCallback onTap,
    bool filled = false,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: filled
                ? _accentColor
                : _accentColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: filled ? Colors.white : _accentColor,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: filled ? Colors.white : _accentColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

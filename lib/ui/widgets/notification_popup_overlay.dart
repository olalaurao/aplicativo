// lib/ui/widgets/notification_popup_overlay.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/notification_overlay_provider.dart';
import '../../services/notification_service.dart';
import '../../models/reminder_config.dart';
import '../theme.dart';

/// Wraps the app shell to display popup notifications at the top of the screen.
/// Place this as a parent of the main app content inside the MaterialApp.
class NotificationPopupOverlay extends ConsumerWidget {
  final Widget child;
  const NotificationPopupOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final popups = ref.watch(notificationOverlayProvider);

    return Stack(
      children: [
        child,
        // Popup stack
        if (popups.isNotEmpty)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            right: 12,
            child: Column(
              children: popups.map((popup) {
                return _PopupBanner(
                  key: ValueKey(popup.id),
                  notification: popup,
                  onDismiss: () {
                    ref
                        .read(notificationOverlayProvider.notifier)
                        .dismiss(popup.id);
                  },
                  onSnooze: (minutes) {
                    ref
                        .read(notificationOverlayProvider.notifier)
                        .dismiss(popup.id);
                    NotificationService().scheduleReminder(
                      id: DateTime.now().millisecondsSinceEpoch % 100000,
                      title: popup.title,
                      config: ReminderConfig(
                        id: '${popup.id}_snooze',
                        triggerTime:
                            DateTime.now().add(Duration(minutes: minutes)),
                        type: NotificationType.popup,
                        notificationBody: popup.body,
                        snoozeMinutes: minutes,
                      ),
                    );
                  },
                  onDone: popup.objectId != null
                      ? () {
                          ref
                              .read(notificationOverlayProvider.notifier)
                              .dismiss(popup.id);
                          // Mark done handled at higher level
                        }
                      : null,
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

class _PopupBanner extends StatefulWidget {
  final PopupNotification notification;
  final VoidCallback onDismiss;
  final void Function(int minutes) onSnooze;
  final VoidCallback? onDone;

  const _PopupBanner({
    super.key,
    required this.notification,
    required this.onDismiss,
    required this.onSnooze,
    this.onDone,
  });

  @override
  State<_PopupBanner> createState() => _PopupBannerState();
}

class _PopupBannerState extends State<_PopupBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnimation;
  Timer? _autoTimer;
  double _progress = 1.0;
  late final Timer _progressTimer;

  static const _autoDismissMs = 10000;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));
    _slideController.forward();

    HapticFeedback.lightImpact();

    // Auto-dismiss timer
    _autoTimer = Timer(
      const Duration(milliseconds: _autoDismissMs),
      _animateOut,
    );

    // Progress bar timer (update every 100ms)
    _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) {
        setState(() {
          _progress -= 100 / _autoDismissMs;
          if (_progress < 0) _progress = 0;
        });
      }
    });
  }

  void _animateOut() {
    _autoTimer?.cancel();
    _progressTimer.cancel();
    _slideController.reverse().then((_) {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _progressTimer.cancel();
    _slideController.dispose();
    super.dispose();
  }

  Color get _accentColor => widget.notification.color;

  IconData get _typeIcon {
    switch (widget.notification.type) {
      case PopupType.task:
        return Icons.check_box_outlined;
      case PopupType.event:
        return Icons.event_rounded;
      case PopupType.habit:
        return Icons.spa_rounded;
      case PopupType.reminder:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkCardFill : AppColors.surface;

    return SlideTransition(
      position: _slideAnimation,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Progress bar at top
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  child: LinearProgressIndicator(
                    value: _progress.clamp(0.0, 1.0),
                    minHeight: 3,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        _accentColor.withValues(alpha: 0.7)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 10, 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icon
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(_typeIcon, size: 20, color: _accentColor),
                      ),
                      const SizedBox(width: 12),
                      // Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.notification.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimaryColor(context),
                              ),
                            ),
                            if (widget.notification.body.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                widget.notification.body,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondaryColor(context),
                                ),
                              ),
                            ],
                            const SizedBox(height: 4),
                            // Time
                            Row(
                              children: [
                                Icon(Icons.access_time_rounded,
                                    size: 12,
                                    color: AppTheme.textMutedColor(context)),
                                const SizedBox(width: 4),
                                Text(
                                  _formatTime(widget.notification.createdAt),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textMutedColor(context),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Close button
                      GestureDetector(
                        onTap: _animateOut,
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(Icons.close_rounded,
                              size: 18, color: AppTheme.textMutedColor(context)),
                        ),
                      ),
                    ],
                  ),
                ),
                // Action buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                  child: Row(
                    children: [
                      _actionButton(
                        'Adiar 10min',
                        onTap: () {
                          widget.onSnooze(10);
                        },
                        outlined: true,
                      ),
                      if (widget.notification.type == PopupType.task &&
                          widget.onDone != null) ...[
                        const SizedBox(width: 8),
                        _actionButton(
                          'Marcar como feito',
                          onTap: widget.onDone!,
                          filled: true,
                        ),
                      ],
                      const Spacer(),
                      _actionButton(
                        'OK',
                        onTap: _animateOut,
                        outlined: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionButton(
    String label, {
    required VoidCallback onTap,
    bool outlined = false,
    bool filled = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: filled ? _accentColor : null,
          border: outlined
              ? Border.all(color: AppTheme.dividerColor(context))
              : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: filled ? Colors.white : AppTheme.textPrimaryColor(context),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

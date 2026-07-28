import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/content_object.dart' as models;
import '../../models/task_model.dart';
import '../../models/habit_model.dart';
import '../../models/pomodoro_session.dart';
import '../../models/reminder_model.dart';
import '../../models/event_model.dart';
import '../../models/goal_model.dart';
import '../../models/note_model.dart';
import '../../models/idea_model.dart';
import '../../models/journal_entry.dart';
import '../../providers/vault_provider.dart';
import '../../providers/pomodoro_provider.dart';
import '../theme.dart';
import '../utils/object_icons.dart';
import '../../models/shared_types.dart';
import '../../models/scheduler.dart';

class ObjectActionSheet extends ConsumerWidget {
  final models.ContentObject object;
  final VoidCallback? onEdit;
  final VoidCallback? onChangeDateTime;
  final VoidCallback? onToggleComplete;
  final VoidCallback? onStartPomodoro;
  final VoidCallback? onDelete;
  final VoidCallback? onArchive;

  const ObjectActionSheet({
    super.key,
    required this.object,
    this.onEdit,
    this.onChangeDateTime,
    this.onToggleComplete,
    this.onStartPomodoro,
    this.onDelete,
    this.onArchive,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = _buildActions(context, ref);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.dividerColor(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    ObjectIcons.iconDataForType(object.type, ref),
                    size: 24,
                    color: AppTheme.accentColor(context),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      object.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ...actions.map((action) => _buildActionItem(context, action)),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  List<_ActionItem> _buildActions(BuildContext context, WidgetRef ref) {
    final actions = <_ActionItem>[];

    // Edit
    actions.add(_ActionItem(
      icon: Icons.edit_rounded,
      label: 'Edit',
      onTap: () {
        Navigator.pop(context);
        onEdit?.call();
      },
    ));

    // Change date/time
    if (onChangeDateTime != null) {
      actions.add(_ActionItem(
        icon: Icons.schedule_rounded,
        label: 'Change date/time',
        onTap: () {
          Navigator.pop(context);
          onChangeDateTime!.call();
        },
      ));
    }

    // Complete/Mark open
    if (onToggleComplete != null) {
      final isCompleted = _isObjectCompleted(object);
      actions.add(_ActionItem(
        icon: isCompleted ? Icons.radio_button_unchecked_rounded : Icons.check_circle_rounded,
        label: isCompleted ? 'Mark open' : 'Complete',
        onTap: () {
          Navigator.pop(context);
          onToggleComplete!.call();
        },
      ));
    }

    // Start Pomodoro
    if (onStartPomodoro != null && _isPomodoroPlayable(object)) {
      actions.add(_ActionItem(
        icon: Icons.play_circle_rounded,
        label: 'Start Pomodoro',
        onTap: () {
          Navigator.pop(context);
          onStartPomodoro!.call();
        },
      ));
    }

    // Delete
    if (onDelete != null) {
      actions.add(_ActionItem(
        icon: Icons.delete_rounded,
        label: 'Delete',
        isDestructive: true,
        onTap: () {
          Navigator.pop(context);
          onDelete!.call();
        },
      ));
    }

    // Archive
    if (onArchive != null) {
      actions.add(_ActionItem(
        icon: Icons.archive_rounded,
        label: 'Archive',
        onTap: () {
          Navigator.pop(context);
          onArchive!.call();
        },
      ));
    }

    return actions;
  }

  Widget _buildActionItem(BuildContext context, _ActionItem action) {
    return InkWell(
      onTap: action.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(
              action.icon,
              size: 22,
              color: action.isDestructive
                  ? AppColors.error
                  : AppTheme.textPrimaryColor(context),
            ),
            const SizedBox(width: 16),
            Text(
              action.label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: action.isDestructive
                    ? AppColors.error
                    : AppTheme.textPrimaryColor(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isObjectCompleted(models.ContentObject object) {
    if (object is Task) return object.isCompleted;
    if (object is Habit) return false; // Habits have per-slot completion
    if (object is PomodoroSession) return object.state == PomodoroSessionState.completed;
    return false;
  }

  bool _isPomodoroPlayable(models.ContentObject object) {
    if (object is Task && !object.isCompleted) return true;
    if (object is Event && object.pomodoro != null) return true;
    return false;
  }

  static void show(
    BuildContext context, {
    required models.ContentObject object,
    VoidCallback? onEdit,
    VoidCallback? onChangeDateTime,
    VoidCallback? onToggleComplete,
    VoidCallback? onStartPomodoro,
    VoidCallback? onDelete,
    VoidCallback? onArchive,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ObjectActionSheet(
        object: object,
        onEdit: onEdit,
        onChangeDateTime: onChangeDateTime,
        onToggleComplete: onToggleComplete,
        onStartPomodoro: onStartPomodoro,
        onDelete: onDelete,
        onArchive: onArchive,
      ),
    );
  }
}

class _ActionItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  _ActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });
}

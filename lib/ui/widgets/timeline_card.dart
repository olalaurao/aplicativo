// lib/ui/widgets/timeline_card.dart
import 'package:flutter/material.dart';
import '../theme.dart';
import '../../services/markdown_parser.dart';
import 'journal_body_view.dart';

/// A card for journal entries on the timeline
class JournalEntryCard extends StatelessWidget {
  final String? title;
  final String body;
  final String time;
  final String? moodEmoji;
  final String? moodLabel;
  final List<Widget> moodChips;
  final String? location;
  final List<Widget> chips;
  final List<String> photoUrls;
  final VoidCallback? onTap;

  const JournalEntryCard({
    super.key,
    this.title,
    required this.body,
    required this.time,
    this.moodEmoji,
    this.moodLabel,
    this.moodChips = const [],
    this.location,
    this.chips = const [],
    this.photoUrls = const [],
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Material(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: AppTheme.cardDecoration(context),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title row + mood emoji
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title ??
                            MarkdownParser.getPlainTextFromBody(
                              body,
                            ).split('\n').first,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimaryColor(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (moodEmoji != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: _MoodFlag(emoji: moodEmoji!, label: moodLabel),
                      ),
                  ],
                ),

                if (moodChips.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: moodChips),
                ],

                const SizedBox(height: 6),

                // Body preview
                JournalBodyView(
                  body: body,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondaryColor(context),
                    height: 1.4,
                  ),
                  maxLines: 3,
                ),

                // Photo strip
                if (photoUrls.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 56,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: photoUrls.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 6),
                      itemBuilder: (context, index) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 56,
                            height: 56,
                            color: AppColors.surfaceVariant,
                            child: const Icon(
                              Icons.image,
                              color: AppColors.textMuted,
                              size: 20,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],

                const SizedBox(height: 10),

                // Metadata row
                Row(
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      time,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    if (location != null) ...[
                      const SizedBox(width: 12),
                      const Icon(
                        Icons.place_outlined,
                        size: 14,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        location!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),

                // Organizer chips
                if (chips.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 4, children: chips),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MoodFlag extends StatelessWidget {
  final String emoji;
  final String? label;

  const _MoodFlag({required this.emoji, this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 12)),
          if (label != null && label!.isNotEmpty) ...[
            const SizedBox(width: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 96),
              child: Text(
                label!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A card for tasks on the timeline
class TaskCard extends StatelessWidget {
  final String title;
  final String? priority;
  final String? stage;
  final String? dueDate;
  final bool completed;
  final int subtasksCount;
  final int completedSubtasksCount;
  final bool isBlocked;
  final VoidCallback? onTap;
  final VoidCallback? onToggle;

  const TaskCard({
    super.key,
    required this.title,
    this.priority,
    this.stage,
    this.dueDate,
    this.completed = false,
    this.isBlocked = false,
    this.subtasksCount = 0,
    this.completedSubtasksCount = 0,
    this.onTap,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkCardFill
                : AppColors.cardFill,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkDivider
                  : AppColors.divider,
            ),
          ),
          child: Row(
            children: [
              // Checkbox circle
              GestureDetector(
                onTap: isBlocked
                    ? () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Esta tarefa está bloqueada por dependências incompletas.',
                            ),
                          ),
                        );
                      }
                    : onToggle,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: completed
                          ? AppColors.success
                          : isBlocked
                          ? AppColors.error
                          : AppColors.textMuted,
                      width: 2,
                    ),
                    color: completed
                        ? AppColors.success
                        : (isBlocked
                              ? AppColors.error.withValues(alpha: 0.1)
                              : Colors.transparent),
                  ),
                  child: completed
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : isBlocked
                      ? const Icon(
                          Icons.lock_rounded,
                          size: 12,
                          color: AppColors.error,
                        )
                      : null,
                ),
              ),

              const SizedBox(width: 12),

              // Title
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: completed
                        ? AppTheme.textMutedColor(context)
                        : AppTheme.textPrimaryColor(context),
                    decoration: completed ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),

              // Priority badge
              if (priority != null && priority != 'none') ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: AppTheme.badgeDecoration(
                    _priorityColor(priority!),
                  ),
                  child: Text(
                    priority!,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _priorityColor(priority!),
                    ),
                  ),
                ),
              ],

              // Stage badge
              if (stage != null) ...[
                const SizedBox(width: 6),
                Text(
                  stage!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],

              // Subtasks progress
              if (subtasksCount > 0) ...[
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.account_tree_outlined,
                      size: 12,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '$completedSubtasksCount/$subtasksCount',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],

              // Due date
              if (dueDate != null) ...[
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.event_outlined,
                      size: 12,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      dueDate!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _priorityColor(String p) {
    switch (p) {
      case 'high':
        return AppColors.priorityHigh;
      case 'medium':
        return AppColors.priorityMedium;
      case 'low':
        return AppColors.priorityLow;
      default:
        return AppColors.textMuted;
    }
  }
}

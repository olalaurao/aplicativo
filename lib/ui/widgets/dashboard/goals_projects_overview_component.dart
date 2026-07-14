import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../models/content_object.dart';
import '../../../models/dashboard_block.dart';
import '../../../models/goal_model.dart';
import '../../../models/project_model.dart';
import '../../../models/shared_types.dart';
import '../../../providers/vault_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../services/project_progress_resolver.dart';
import '../../theme.dart';
import '../../navigation/object_navigation.dart';
import '../../utils/object_icons.dart';

class _ProgressItem {
  final ContentObject source;
  final String title;
  final String emoji;
  final double? progress;
  final bool isGoal;

  _ProgressItem({
    required this.source,
    required this.title,
    required this.emoji,
    required this.progress,
    required this.isGoal,
  });
}

class GoalsProjectsOverviewComponent extends ConsumerWidget {
  final DashboardBlock block;

  const GoalsProjectsOverviewComponent({super.key, required this.block});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allObjects = ref.watch(allObjectsProvider).valueOrNull ?? [];
    final settings = ref.watch(settingsProvider);

    final maxItems = block.metadata['maxItems'] as int? ?? 5;
    final sortMode = block.metadata['sortMode'] as String? ?? 'progress_asc';
    final typeFilter = block.metadata['typeFilter'] as String? ?? 'all';
    final includeCompleted = block.metadata['includeCompleted'] as bool? ?? false;

    List<_ProgressItem> items = [];

    if (typeFilter == 'all' || typeFilter == 'goals_only') {
      final goals = allObjects.whereType<Goal>().where((g) {
        if (!includeCompleted && (g.state == GoalStatus.completed || g.state == GoalStatus.cancelled)) return false;
        return true;
      });
      for (final g in goals) {
        items.add(_ProgressItem(
          source: g,
          title: g.title,
          emoji: g.icon ?? ObjectIcons.emojiForTypeWithSignatures(ObjectTypes.goal, settings.typeSignatures),
          progress: g.progress,
          isGoal: true,
        ));
      }
    }

    if (typeFilter == 'all' || typeFilter == 'projects_only') {
      final projects = allObjects.whereType<Project>().where((p) {
        if (!includeCompleted && p.archived) return false;
        return true;
      });
      for (final p in projects) {
        final prog = ProjectProgressResolver.resolve(p, allObjects);
        items.add(_ProgressItem(
          source: p,
          title: p.title,
          emoji: p.icon ?? ObjectIcons.emojiForTypeWithSignatures(ObjectTypes.project, settings.typeSignatures),
          progress: prog,
          isGoal: false,
        ));
      }
    }

    // Sort items
    if (sortMode == 'progress_asc') {
      items.sort((a, b) => (a.progress ?? 0).compareTo(b.progress ?? 0));
    } else if (sortMode == 'progress_desc') {
      items.sort((a, b) => (b.progress ?? 0).compareTo(a.progress ?? 0));
    }
    // else manual is ignored for now since we don't have a manual order field on goals/projects universally

    final visibleItems = items.take(maxItems).toList();

    return Container(
      decoration: AppTheme.cardDecoration(context),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(Icons.flag_rounded, color: AppColors.textMuted, size: 20),
                const SizedBox(width: 8),
                Text(
                  block.title.isNotEmpty ? block.title : 'Goals & Projects',
                  style: Theme.of(context).textTheme.titleMedium!.copyWith(fontSize: 16),
                ),
              ],
            ),
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.flag_outlined, size: 48, color: AppColors.textMuted.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text('No active goals or projects yet', style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: AppColors.textMuted)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () => context.push('/planner'),
                        child: const Text('Plan Goal'),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => context.push('/organize'),
                        child: const Text('Organize Project'),
                      ),
                    ],
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: visibleItems.map((item) {
                  final progressText = item.progress != null ? '${(item.progress! * 100).round()}%' : '—';
                  
                  return InkWell(
                    onTap: () => navigateToObject(context, item.source),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Text(item.emoji, style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.title,
                                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.w500),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: item.isGoal 
                                          ? Colors.purple.withValues(alpha: 0.1) 
                                          : (item.source as Project).color != null
                                            ? _parseColor((item.source as Project).color!).withValues(alpha: 0.1)
                                            : AppColors.accent.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        item.isGoal ? 'Goal' : 'Project',
                                        style: Theme.of(context).textTheme.bodySmall!.copyWith(
                                          fontSize: 10,
                                          color: item.isGoal 
                                            ? Colors.purple 
                                            : (item.source as Project).color != null
                                              ? _parseColor((item.source as Project).color!)
                                              : AppColors.accent,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      progressText,
                                      style: Theme.of(context).textTheme.bodySmall!.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                if (item.progress != null)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(2),
                                    child: LinearProgressIndicator(
                                      value: item.progress,
                                      minHeight: 4,
                                      backgroundColor: AppColors.surfaceVariant,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        item.isGoal ? Colors.purple : AppColors.accent,
                                      ),
                                    ),
                                  )
                                else
                                  Container(
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Color _parseColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    return Color(int.tryParse(hex, radix: 16) ?? 0xFF888888);
  }
}

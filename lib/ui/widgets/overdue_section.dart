import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/task_model.dart';
import '../../providers/overdue_provider.dart';
import '../../providers/vault_provider.dart';
import '../screens/universal_detail_view.dart';
import '../theme.dart';

class OverdueSection extends ConsumerWidget {
  final List<String>? filterTypes;

  const OverdueSection({super.key, this.filterTypes});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var items = ref.watch(overdueProvider);
    if (filterTypes != null) {
      items = items.where((i) => filterTypes!.contains(i.itemType)).toList();
    }
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 10),
          child: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.error,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                'Atrasados (${items.length})',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
        ),
        ...items.map((item) => _OverdueCard(item: item)),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _OverdueCard extends ConsumerWidget {
  final OverdueItem item;

  const _OverdueCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daysText = item.daysLate == 1
        ? '1 dia atrasado'
        : '${item.daysLate} dias atrasado';
    final (icon, color) = switch (item.itemType) {
      'task' => (
          Icons.check_box_outline_blank_rounded,
          AppColors.error,
        ),
      'goal' => (Icons.flag_outlined, AppColors.warning),
      'project' => (Icons.folder_outlined, AppColors.info),
      'idea' => (Icons.lightbulb_outline_rounded, AppTheme.accentColor(context)),
      _ => (Icons.circle_outlined, AppColors.textMuted),
    };

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => UniversalDetailView(object: item.object),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: AppTheme.cardDecoration(context).copyWith(
          border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.object.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    daysText,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.error,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (item.itemType == 'task')
              GestureDetector(
                onTap: () {
                  final task = item.object as Task;
                  ref.read(tasksProvider.notifier).updateTask(
                        task.copyWith(stage: TaskStage.finalized),
                      );
                },
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.check_circle_outline_rounded,
                    color: AppColors.textMuted,
                    size: 22,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

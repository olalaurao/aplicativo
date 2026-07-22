import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/dashboard_block.dart';
import '../../../models/content_object.dart';
import '../../../providers/vault_provider.dart';
import '../../theme.dart';
import '../../screens/universal_detail_view.dart';

class PinnedObjectComponent extends ConsumerWidget {
  final DashboardBlock block;
  const PinnedObjectComponent({super.key, required this.block});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final objectId = block.metadata['objectId'] as String?;
    final objectTitle = block.metadata['objectTitle'] as String? ?? 'Pinned Item';

    if (objectId == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: AppTheme.cardDecoration(context),
        child: Row(
          children: [
            const Icon(Icons.push_pin_outlined, color: AppColors.textMuted),
            const SizedBox(width: 12),
            Text(
              'No item selected — configure this block',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ],
        ),
      );
    }

    final allObjects = ref.watch(allObjectsProvider).valueOrNull ?? [];
    final obj = allObjects.cast<ContentObject?>().firstWhere(
      (o) => o?.id == objectId,
      orElse: () => null,
    );

    if (obj == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: AppTheme.cardDecoration(context),
        child: Text(
          'Item "$objectTitle" not found',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      );
    }

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => UniversalDetailView(object: obj)),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.cardDecoration(context),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.accentColor(context).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.push_pin_rounded,
                color: AppTheme.accentColor(context),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    obj.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    obj.type.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 18),
          ],
        ),
      ),
    );
  }
}

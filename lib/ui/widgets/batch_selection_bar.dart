import 'package:flutter/material.dart';
import '../theme.dart';

class BatchSelectionBar extends StatelessWidget implements PreferredSizeWidget {
  final int selectedCount;
  final String title;
  final VoidCallback onCancel;
  final List<Widget> actions;

  const BatchSelectionBar({
    super.key,
    required this.selectedCount,
    this.title = 'selected',
    required this.onCancel,
    this.actions = const [],
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppTheme.surfaceVariantColor(context),
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.close_rounded),
        onPressed: onCancel,
        tooltip: 'Cancel selection',
      ),
      title: Text(
        '$selectedCount $title',
        style: const TextStyle(
          fontSize: AppTextSize.lg,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        ...actions,
        const SizedBox(width: AppSpacing.sm),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../theme.dart';

/// Shows a delete confirmation dialog with soft-delete and undo support.
/// 
/// Returns true if the user confirms deletion, false otherwise.
/// If [onUndo] is provided, an undo action button will be shown in the snackbar.
Future<bool> confirmAndDelete(
  BuildContext context, {
  String? title,
  VoidCallback? onUndo,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title ?? 'Delete this item?'),
      content: const Text('This action can be undone.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          child: const Text('Delete'),
        ),
      ],
    ),
  );

  if (confirmed == true && onUndo != null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Item deleted'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: onUndo,
          ),
        ),
      );
    }
  }

  return confirmed ?? false;
}

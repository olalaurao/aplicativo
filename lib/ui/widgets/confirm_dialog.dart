// lib/ui/widgets/confirm_dialog.dart
import 'package:flutter/material.dart';
import '../theme.dart';

class ConfirmDialog extends StatelessWidget {
  final String title;
  final String? content;
  final String confirmText;
  final String cancelText;
  final bool isDestructive;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;

  const ConfirmDialog({
    super.key,
    required this.title,
    this.content,
    this.confirmText = 'Confirm',
    this.cancelText = 'Cancel',
    this.isDestructive = false,
    this.onConfirm,
    this.onCancel,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String title,
    String? content,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => ConfirmDialog(
        title: title,
        content: content,
        confirmText: confirmText,
        cancelText: cancelText,
        isDestructive: isDestructive,
        onConfirm: () => Navigator.of(context).pop(true),
        onCancel: () => Navigator.of(context).pop(false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        title,
        style: const TextStyle(
          fontSize: AppTextSize.lg,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: content != null
          ? Text(
              content!,
              style: TextStyle(
                fontSize: AppTextSize.md,
                color: AppTheme.textSecondaryColor(context),
              ),
            )
          : null,
      actions: [
        TextButton(
          onPressed: onCancel ?? () => Navigator.of(context).pop(),
          child: Text(
            cancelText,
            style: const TextStyle(
              fontSize: AppTextSize.md,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        TextButton(
          onPressed: onConfirm ?? () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor: isDestructive ? AppColors.error : Theme.of(context).colorScheme.primary,
          ),
          child: Text(
            confirmText,
            style: const TextStyle(
              fontSize: AppTextSize.md,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

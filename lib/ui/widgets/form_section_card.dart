import 'package:flutter/material.dart';
import '../theme.dart';

class FormSectionCard extends StatelessWidget {
  final String? title;                 // omit for cards with no header (e.g. Connections card in create_task_form.dart:1367)
  final Widget? trailing;               // e.g. the "+" IconButton seen on Subtasks/Actions/Depends-On cards
  final Widget child;
  final EdgeInsets padding;             // default EdgeInsets.all(16)
  final EdgeInsets? contentPadding;     // override for horizontal-only padding cases (e.g. OrganizerSelectorField card uses symmetric(horizontal:16))
  final bool noBottomPaddingOnTitle;    // when true, title sits flush above child with no extra gap (rare case)

  const FormSectionCard({
    super.key,
    this.title,
    this.trailing,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.contentPadding,
    this.noBottomPaddingOnTitle = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecoration(context),
      padding: contentPadding ?? padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                Text(
                  title!,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                if (trailing != null) trailing!,
              ],
            ),
            SizedBox(height: noBottomPaddingOnTitle ? 0 : 8),
          ],
          child,
        ],
      ),
    );
  }
}

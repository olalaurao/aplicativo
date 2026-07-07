// lib/ui/widgets/form_section.dart
import 'package:flutter/material.dart';
import '../theme.dart';

class FormSection extends StatelessWidget {
  final String? title;
  final String? description;
  final List<Widget> children;
  final EdgeInsets? padding;
  final bool showDivider;

  const FormSection({
    super.key,
    this.title,
    this.description,
    required this.children,
    this.padding,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Text(
            title!,
            style: TextStyle(
              fontSize: AppTextSize.lg,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimaryColor(context),
            ),
          ),
          if (description != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              description!,
              style: TextStyle(
                fontSize: AppTextSize.sm,
                color: AppTheme.textMutedColor(context),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
        ],
        ...children,
        if (showDivider) const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}

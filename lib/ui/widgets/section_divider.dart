import 'package:flutter/material.dart';
import '../theme.dart';

class SectionDivider extends StatelessWidget {
  final String? label;
  final double height;

  const SectionDivider({
    super.key,
    this.label,
    this.height = 24,
  });

  @override
  Widget build(BuildContext context) {
    if (label == null) {
      return Divider(
        height: height,
        color: AppColors.divider,
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: height / 2),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: AppColors.divider,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Divider(
              color: AppColors.divider,
            ),
          ),
        ],
      ),
    );
  }
}

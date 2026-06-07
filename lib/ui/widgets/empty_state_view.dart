import 'package:flutter/material.dart';
import '../theme.dart';

class EmptyStateView extends StatelessWidget {
  final IconData icon;
  final String headline;
  final String? subhead;
  final Widget? actionButton;
  final bool isSmall;

  const EmptyStateView({
    super.key,
    required this.icon,
    required this.headline,
    this.subhead,
    this.actionButton,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(isSmall ? 16.0 : 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(isSmall ? 12 : 20),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: isSmall ? 32 : 48,
                color: AppColors.textMuted,
              ),
            ),
            SizedBox(height: isSmall ? 12 : 24),
            Text(
              headline,
              style: TextStyle(
                fontSize: isSmall ? 15 : 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            if (subhead != null) ...[
              const SizedBox(height: 8),
              Text(
                subhead!,
                style: TextStyle(
                  fontSize: isSmall ? 13 : 14,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionButton != null) ...[
              SizedBox(height: isSmall ? 16 : 24),
              actionButton!,
            ],
          ],
        ),
      ),
    );
  }
}

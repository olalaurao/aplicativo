// lib/features/overdue/widgets/overdue_nav_badge.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../ui/theme.dart';
import '../../../providers/overdue_provider.dart';

class OverdueNavBadge extends ConsumerWidget {
  final Widget child;

  const OverdueNavBadge({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overdueCount = ref.watch(overdueCountProvider);

    if (overdueCount == 0) {
      return child;
    }

    final displayCount = overdueCount > 9 ? '9+' : overdueCount.toString();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: -6,
          top: -6,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: AppColors.error,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.surface,
                width: 2,
              ),
            ),
            constraints: const BoxConstraints(
              minWidth: 18,
              minHeight: 18,
            ),
            child: Text(
              displayCount,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}

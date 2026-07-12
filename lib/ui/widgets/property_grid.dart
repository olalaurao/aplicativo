import 'package:flutter/material.dart';

import '../theme.dart';

enum PropertyCardState {
  normal,
  empty,
  overdue,
  dueToday,
  streakActive,
  complete,
}

class PropertyCard {
  final IconData icon;
  final String label;
  final String? value;
  final PropertyCardState state;
  final Color? leftBorderColor;
  final VoidCallback? onTap;
  final Widget? customChild;

  const PropertyCard({
    required this.icon,
    required this.label,
    this.value,
    this.state = PropertyCardState.normal,
    this.leftBorderColor,
    this.onTap,
    this.customChild,
  });
}

class PropertyGridItem {
  final String label;
  final String value;
  final VoidCallback? onTap;
  final IconData? icon;

  const PropertyGridItem({
    required this.label,
    required this.value,
    this.onTap,
    this.icon,
  });
}

class PropertyGrid extends StatelessWidget {
  final List<PropertyGridItem>? items;
  final List<PropertyCard>? cards;

  const PropertyGrid({super.key, this.items, this.cards})
    : assert(items != null || cards != null);

  @override
  Widget build(BuildContext context) {
    final resolvedCards =
        cards ??
        items!
            .map(
              (item) => PropertyCard(
                icon:
                    item.icon ??
                    (item.onTap == null
                        ? Icons.info_outline_rounded
                        : Icons.chevron_right_rounded),
                label: item.label,
                value: item.value,
                onTap: item.onTap,
                state: item.value.trim().isEmpty
                    ? PropertyCardState.empty
                    : PropertyCardState.normal,
              ),
            )
            .toList();

    if (resolvedCards.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = 2;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: resolvedCards.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 102,
          ),
          itemBuilder: (context, index) {
            return _PropertyCardWidget(card: resolvedCards[index]);
          },
        );
      },
    );
  }
}

class _PropertyCardWidget extends StatelessWidget {
  final PropertyCard card;

  const _PropertyCardWidget({required this.card});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final contentColor = _contentColor(context, cs);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: card.onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: _backgroundColor(cs, isDark),
            borderRadius: BorderRadius.circular(12),
            border: card.leftBorderColor == null
                ? null
                : Border(
                    left: BorderSide(
                      color: card.leftBorderColor!,
                      width: 3,
                    ),
                  ),
          ),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    card.icon,
                    size: 13,
                    color: contentColor.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      card.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.1,
                        fontWeight: FontWeight.w700,
                        color: contentColor.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  if (card.state == PropertyCardState.empty)
                    Icon(
                      Icons.add_rounded,
                      size: 13,
                      color: contentColor.withValues(alpha: 0.5),
                    ),
                ],
              ),
              const Spacer(),
              if (card.customChild != null)
                card.customChild!
              else
                Text(
                  card.value?.isNotEmpty == true ? card.value! : '-',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.1,
                    fontWeight: card.state == PropertyCardState.empty
                        ? FontWeight.w400
                        : FontWeight.w600,
                    color: contentColor,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _backgroundColor(ColorScheme cs, bool isDark) {
    return switch (card.state) {
      PropertyCardState.empty => cs.onSurface.withValues(
        alpha: isDark ? 0.06 : 0.04,
      ),
      PropertyCardState.overdue => AppColors.error.withValues(
        alpha: isDark ? 0.18 : 0.10,
      ),
      PropertyCardState.dueToday => AppColors.warning.withValues(
        alpha: isDark ? 0.18 : 0.10,
      ),
      PropertyCardState.streakActive => AppColors.success.withValues(
        alpha: isDark ? 0.18 : 0.10,
      ),
      PropertyCardState.complete => cs.primary.withValues(alpha: 0.08),
      PropertyCardState.normal => cs.surface,
    };
  }

  Color _contentColor(BuildContext context, ColorScheme cs) {
    return switch (card.state) {
      PropertyCardState.empty => cs.onSurface.withValues(alpha: 0.35),
      PropertyCardState.overdue => AppColors.error,
      PropertyCardState.dueToday => AppColors.warning,
      PropertyCardState.streakActive => AppColors.success,
      _ => card.onTap == null ? cs.onSurface : cs.primary,
    };
  }
}

class StarRating extends StatelessWidget {
  final double rating;

  const StarRating({super.key, required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final value = index + 1;
        final icon = rating >= value
            ? Icons.star_rounded
            : rating >= value - 0.5
            ? Icons.star_half_rounded
            : Icons.star_border_rounded;
        return Icon(
          icon,
          size: 14,
          color: Theme.of(context).colorScheme.primary,
        );
      }),
    );
  }
}

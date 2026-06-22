// lib/ui/widgets/skeleton_list.dart
// B2 — Animated skeleton loading list.
// Replaces blank screens with animated shimmer cards while providers load.

import 'package:flutter/material.dart';
import '../../ui/theme.dart';

class SkeletonList extends StatelessWidget {
  final int itemCount;
  final double itemHeight;
  final EdgeInsets padding;

  const SkeletonList({
    super.key,
    this.itemCount = 5,
    this.itemHeight = 72,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 100),
  });

  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: padding,
    itemCount: itemCount,
    separatorBuilder: (context, sep) => const SizedBox(height: 10),
    itemBuilder: (ctx, i) => _SkeletonCard(height: itemHeight),
  );
}

// ---------------------------------------------------------------------------
// Compact card variant (horizontal strip, e.g. dashboard)
// ---------------------------------------------------------------------------
class SkeletonCard extends StatelessWidget {
  final double width;
  final double height;

  const SkeletonCard({super.key, this.width = 160, this.height = 80});

  @override
  Widget build(BuildContext context) => _SkeletonCard(
    height: height,
    width: width,
  );
}

// ---------------------------------------------------------------------------
// Internal animated card
// ---------------------------------------------------------------------------
class _SkeletonCard extends StatefulWidget {
  final double height;
  final double? width;

  const _SkeletonCard({required this.height, this.width});

  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = Tween(begin: 0.35, end: 0.85)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (context, b) => Container(
      height: widget.height,
      width: widget.width,
      decoration: AppTheme.cardDecoration(context),
      padding: const EdgeInsets.all(16),
      child: Opacity(
        opacity: _anim.value,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _line(context, 140, 13),
            const SizedBox(height: 12),
            _line(context, double.infinity, 11),
            const SizedBox(height: 8),
            _line(context, 180, 11),
          ],
        ),
      ),
    ),
  );

  Widget _line(BuildContext context, double width, double height) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: AppTheme.surfaceVariantColor(context),
      borderRadius: BorderRadius.circular(6),
    ),
  );
}

// ---------------------------------------------------------------------------
// Usage helper pattern (for documentation):
// ---------------------------------------------------------------------------
// return asyncValue.when(
//   data:    (items) => _buildList(items),
//   loading: ()      => const SkeletonList(),
//   error:   (e, _)  => Center(child: Text('Erro: $e')),
// );

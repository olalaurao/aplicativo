import 'package:flutter/material.dart';
import '../theme.dart';

class CountBadge extends StatelessWidget {
  final int count;
  final Color? color;
  final double? size;

  const CountBadge({
    super.key,
    required this.count,
    this.color,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: size != null ? size! * 0.4 : 4,
        vertical: size != null ? size! * 0.2 : 2,
      ),
      decoration: BoxDecoration(
        color: color ?? AppColors.error,
        borderRadius: BorderRadius.circular(10),
      ),
      constraints: BoxConstraints(
        minWidth: size ?? 18,
        minHeight: size ?? 18,
      ),
      child: Text(
        count > 99 ? '99+' : count.toString(),
        style: TextStyle(
          color: Colors.white,
          fontSize: size != null ? size! * 0.6 : 11,
          fontWeight: FontWeight.w700,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

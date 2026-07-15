import 'package:flutter/material.dart';
import '../theme.dart';

class NumberStepper extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  final int step;

  const NumberStepper({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildButton(
          icon: Icons.remove_rounded,
          onPressed: value > min ? () => onChanged(value - step) : null,
          context: context,
        ),
        SizedBox(
          width: 48,
          child: Text(
            value.toString(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        _buildButton(
          icon: Icons.add_rounded,
          onPressed: value < max ? () => onChanged(value + step) : null,
          context: context,
        ),
      ],
    );
  }

  Widget _buildButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required BuildContext context,
  }) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: onPressed != null
            ? AppTheme.accentColor(context).withValues(alpha: 0.1)
            : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        icon: Icon(icon, size: 18),
        onPressed: onPressed,
        color: onPressed != null
            ? AppTheme.accentColor(context)
            : AppColors.textMuted,
        padding: EdgeInsets.zero,
      ),
    );
  }
}

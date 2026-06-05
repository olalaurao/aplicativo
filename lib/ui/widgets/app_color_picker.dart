import 'package:flutter/material.dart';

import '../theme.dart';

class AppColorPicker extends StatelessWidget {
  const AppColorPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'Cor',
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String label;

  static const List<String> swatches = [
    '#FFB000',
    '#F97316',
    '#EF4444',
    '#EC4899',
    '#8B5CF6',
    '#3B82F6',
    '#0EA5E9',
    '#14B8A6',
    '#22C55E',
    '#84CC16',
    '#F59E0B',
    '#64748B',
  ];

  static String normalizeHex(String input, {String fallback = '#FFB000'}) {
    final cleaned = input.trim().replaceFirst('#', '').toUpperCase();
    if (!RegExp(r'^[0-9A-F]{6}$').hasMatch(cleaned)) return fallback;
    return '#$cleaned';
  }

  static Color parseHex(String input, {Color fallback = AppColors.accent}) {
    final normalized = normalizeHex(input, fallback: '');
    if (normalized.isEmpty) return fallback;
    return Color(int.parse('FF${normalized.substring(1)}', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final normalized = normalizeHex(value);
    final selectedColor = parseHex(normalized);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondaryColor(context),
              ),
            ),
            const Spacer(),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: selectedColor,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.dividerColor(context)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: swatches.map((hex) {
            final selected = normalized == hex;
            final color = parseHex(hex);
            return Semantics(
              label: 'Selecionar cor $hex',
              button: true,
              selected: selected,
              child: InkWell(
                onTap: () => onChanged(hex),
                customBorder: const CircleBorder(),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected
                          ? AppTheme.textPrimaryColor(context)
                          : AppTheme.dividerColor(context),
                      width: selected ? 3 : 1,
                    ),
                  ),
                  child: selected
                      ? const Icon(
                          Icons.check_rounded,
                          color: AppColors.textOnPrimary,
                          size: 18,
                        )
                      : null,
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: ValueKey(normalized),
          initialValue: normalized,
          decoration: const InputDecoration(
            labelText: 'HEX personalizado',
            hintText: '#FFB000',
          ),
          textCapitalization: TextCapitalization.characters,
          onChanged: (text) {
            final cleaned = text.trim().replaceFirst('#', '');
            if (RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(cleaned)) {
              onChanged('#${cleaned.toUpperCase()}');
            }
          },
        ),
      ],
    );
  }
}

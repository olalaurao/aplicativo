// lib/ui/widgets/app_color_picker.dart
import 'package:flutter/material.dart';
import '../theme.dart';

class AppColorPicker extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const AppColorPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  static const List<Map<String, String>> defaultColors = [
    {'name': 'Amber', 'hex': '#FFB000'},
    {'name': 'Sky', 'hex': '#0EA5E9'},
    {'name': 'Green', 'hex': '#22C55E'},
    {'name': 'Orange', 'hex': '#F97316'},
    {'name': 'Purple', 'hex': '#8B5CF6'},
    {'name': 'Pink', 'hex': '#EC4899'},
    {'name': 'Red', 'hex': '#EF4444'},
    {'name': 'Blue', 'hex': '#3B82F6'},
    {'name': 'Teal', 'hex': '#14B8A6'},
    {'name': 'Indigo', 'hex': '#6366F1'},
    {'name': 'Grey', 'hex': '#9CA3AF'},
    {'name': 'Slate', 'hex': '#475569'},
  ];

  static String normalizeHex(String hex) {
    var val = hex.trim().replaceAll('#', '');
    if (val.length == 3) {
      val = val.split('').map((c) => '$c$c').join();
    }
    if (val.length != 6) {
      return '#9CA3AF'; // fallback gray
    }
    return '#${val.toUpperCase()}';
  }

  static Color parseHex(String hex, {Color fallback = const Color(0xFF9CA3AF)}) {
    final clean = hex.trim().replaceAll('#', '');
    if (clean.length != 6) return fallback;
    try {
      return Color(int.parse('0xFF$clean'));
    } catch (_) {
      return fallback;
    }
  }

  @override
  Widget build(BuildContext context) {
    final normalizedSelected = normalizeHex(value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Selecione uma Cor:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: defaultColors.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 6,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemBuilder: (context, index) {
            final colorInfo = defaultColors[index];
            final hex = colorInfo['hex']!;
            final color = parseHex(hex);
            final isSelected = normalizedSelected.toUpperCase() == hex.toUpperCase();

            return GestureDetector(
              onTap: () => onChanged(hex),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? (Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black)
                        : Colors.transparent,
                    width: 3,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.4),
                            blurRadius: 8,
                            spreadRadius: 2,
                          )
                        ]
                      : [],
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 20,
                      )
                    : null,
              ),
            );
          },
        ),
      ],
    );
  }
}

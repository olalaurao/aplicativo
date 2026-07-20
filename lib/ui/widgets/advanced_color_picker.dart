import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';

/// Advanced color picker with HSV color wheel and HEX input
class AdvancedColorPicker extends ConsumerStatefulWidget {
  final String initialColor;
  final ValueChanged<String> onColorChanged;
  final bool showAlpha;
  final bool enablePaletteSave;

  const AdvancedColorPicker({
    super.key,
    required this.initialColor,
    required this.onColorChanged,
    this.showAlpha = false,
    this.enablePaletteSave = false,
  });

  @override
  ConsumerState<AdvancedColorPicker> createState() => _AdvancedColorPickerState();
}

class _AdvancedColorPickerState extends ConsumerState<AdvancedColorPicker> {
  late HSVColor _hsvColor;
  late TextEditingController _hexController;

  @override
  void initState() {
    super.initState();
    final initialColor = _parseColor(widget.initialColor);
    _hsvColor = HSVColor.fromColor(initialColor);
    _hexController = TextEditingController(text: _colorToHex(initialColor));
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  Color _parseColor(String hex) {
    final clean = hex.trim().replaceAll('#', '');
    if (clean.length == 6) {
      try {
        return Color(int.parse('0xFF$clean'));
      } catch (_) {
        return const Color(0xFFF97316);
      }
    }
    return const Color(0xFFF97316);
  }

  String _colorToHex(Color color) {
    final value = color.toARGB32().toRadixString(16).toUpperCase();
    return '#${value.substring(2)}';
  }

  void _updateFromHSV(HSVColor hsv) {
    setState(() {
      _hsvColor = hsv;
      final color = hsv.toColor();
      _hexController.text = _colorToHex(color);
      widget.onColorChanged(_hexController.text);
    });
  }

  void _updateFromHex(String hex) {
    final clean = hex.trim().replaceAll('#', '');
    if (clean.length == 6) {
      try {
        final color = Color(int.parse('0xFF$clean'));
        setState(() {
          _hsvColor = HSVColor.fromColor(color);
          widget.onColorChanged(_hexController.text);
        });
      } catch (_) {
        // Invalid hex, don't update
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _hsvColor.toColor();

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Color preview
          Container(
            width: double.infinity,
            height: 80,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).dividerColor,
                width: 1,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // HSV Color Wheel
          _ColorWheel(
            hsvColor: _hsvColor,
            onColorChanged: _updateFromHSV,
          ),
          const SizedBox(height: 24),

          // Saturation slider
          _SliderRow(
            label: 'Saturation',
            value: _hsvColor.saturation,
            color: HSLColor.fromAHSL(1.0, _hsvColor.hue, 0.5, 0.5).toColor(),
            onChanged: (value) {
              _updateFromHSV(_hsvColor.withSaturation(value));
            },
          ),
          const SizedBox(height: 16),

          // Value/Brightness slider
          _SliderRow(
            label: 'Brightness',
            value: _hsvColor.value,
            color: _hsvColor.toColor(),
            onChanged: (value) {
              _updateFromHSV(_hsvColor.withValue(value));
            },
          ),
          const SizedBox(height: 24),

          // HEX input
          TextField(
            controller: _hexController,
            decoration: InputDecoration(
              labelText: 'HEX Code',
              hintText: '#RRGGBB',
              prefixText: '#',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
            ),
            textCapitalization: TextCapitalization.characters,
            maxLength: 7,
            onChanged: _updateFromHex,
          ),
          const SizedBox(height: 24),

          // Preset colors
          _PresetColors(
            onColorSelected: (hex) {
              _updateFromHex(hex);
            },
          ),
        ],
      ),
    );
  }
}

/// HSV Color Wheel widget
class _ColorWheel extends StatelessWidget {
  final HSVColor hsvColor;
  final ValueChanged<HSVColor> onColorChanged;

  const _ColorWheel({
    required this.hsvColor,
    required this.onColorChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (details) => _updateColor(context, details.localPosition),
      onPanUpdate: (details) => _updateColor(context, details.localPosition),
      child: CustomPaint(
        size: const Size(280, 280),
        painter: _ColorWheelPainter(hsvColor: hsvColor),
      ),
    );
  }

  void _updateColor(BuildContext context, Offset localPosition) {
    final size = const Size(280, 280);
    final center = Offset(size.width / 2, size.height / 2);
    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;
    
    // Calculate hue from angle
    double angle = (atan2(dy, dx) * 180 / 3.14159265359);
    if (angle < 0) angle += 360;
    
    // Calculate saturation from distance
    final distance = sqrt(dx * dx + dy * dy);
    final maxDistance = size.width / 2;
    final saturation = (distance / maxDistance).clamp(0.0, 1.0);
    
    onColorChanged(hsvColor.withHue(angle).withSaturation(saturation));
  }
}

class _ColorWheelPainter extends CustomPainter {
  final HSVColor hsvColor;

  _ColorWheelPainter({required this.hsvColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw color wheel
    for (double angle = 0; angle < 360; angle += 1) {
      final hue = angle;
      for (double sat = 0; sat <= 1; sat += 0.01) {
        final color = HSVColor.fromAHSV(1.0, hue, sat, 1.0).toColor();
        final paint = Paint()..color = color;
        final x = center.dx + radius * sat * cos(angle * 3.14159265359 / 180);
        final y = center.dy + radius * sat * sin(angle * 3.14159265359 / 180);
        canvas.drawCircle(Offset(x, y), 1.5, paint);
      }
    }

    // Draw selection indicator
    final selectionAngle = hsvColor.hue * 3.14159265359 / 180;
    final selectionSat = hsvColor.saturation;
    final selectionX = center.dx + radius * selectionSat * cos(selectionAngle);
    final selectionY = center.dy + radius * selectionSat * sin(selectionAngle);

    canvas.drawCircle(
      Offset(selectionX, selectionY),
      12,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawCircle(
      Offset(selectionX, selectionY),
      8,
      Paint()..color = hsvColor.toColor(),
    );
  }

  @override
  bool shouldRepaint(_ColorWheelPainter oldDelegate) {
    return oldDelegate.hsvColor != hsvColor;
  }
}

/// Slider row for saturation and value
class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            Text(
              '${(value * 100).toInt()}%',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: value,
          onChanged: onChanged,
          activeColor: color,
          min: 0,
          max: 1,
        ),
      ],
    );
  }
}

/// Preset colors for quick selection
class _PresetColors extends StatelessWidget {
  final ValueChanged<String> onColorSelected;

  const _PresetColors({required this.onColorSelected});

  static const List<String> presets = [
    '#DC2626', // Red
    '#F97316', // Orange
    '#F59E0B', // Amber
    '#10B981', // Green
    '#06B6D4', // Cyan
    '#3B82F6', // Blue
    '#8B5CF6', // Purple
    '#EC4899', // Pink
    '#6B7280', // Gray
    '#000000', // Black
    '#FFFFFF', // White
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Colors',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: presets.map((hex) {
            final color = _parseColor(hex);
            return GestureDetector(
              onTap: () => onColorSelected(hex),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Theme.of(context).dividerColor,
                    width: 1,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Color _parseColor(String hex) {
    final clean = hex.trim().replaceAll('#', '');
    if (clean.length == 6) {
      try {
        return Color(int.parse('0xFF$clean'));
      } catch (_) {
        return Colors.grey;
      }
    }
    return Colors.grey;
  }
}

import 'package:flutter/material.dart';

class AppThemeConfig {
  final String id;
  final String label;
  final Color accentColor;
  final Color? backgroundColor;
  final IconData icon;
  final String description;
  final String? fontFamily;

  const AppThemeConfig({
    required this.id,
    required this.label,
    required this.accentColor,
    this.backgroundColor,
    required this.icon,
    required this.description,
    this.fontFamily,
  });

  String get accentHex {
    final value = accentColor.toARGB32().toRadixString(16).toUpperCase();
    return '#${value.substring(2)}';
  }

  static Color colorFromHex(String hex) {
    final clean = hex.replaceAll('#', '').trim();
    final normalized = clean.length == 6 ? 'FF$clean' : clean;
    return Color(int.parse(normalized, radix: 16));
  }

  static const List<AppThemeConfig> presets = [
    AppThemeConfig(
      id: 'citrine',
      label: 'Citrine',
      accentColor: Color(0xFFF97316),
      backgroundColor: Color(0xFFF8F9FB),
      icon: Icons.wb_sunny_outlined,
      description: 'Vibrant orange for the default app theme.',
      fontFamily: 'Inter',
    ),
    AppThemeConfig(
      id: 'amber',
      label: 'Amber',
      accentColor: Color(0xFFFFB000),
      backgroundColor: Color(0xFFFFFBF0),
      icon: Icons.light_mode_outlined,
      description: 'Warm amber with high contrast.',
      fontFamily: 'Inter',
    ),
    AppThemeConfig(
      id: 'ocean',
      label: 'Ocean',
      accentColor: Color(0xFF3B82F6),
      backgroundColor: Color(0xFFF0F9FF),
      icon: Icons.water_drop_outlined,
      description: 'Clean blue for navigation and focus.',
      fontFamily: 'Inter',
    ),
    AppThemeConfig(
      id: 'forest',
      label: 'Forest',
      accentColor: Color(0xFF22C55E),
      backgroundColor: Color(0xFFF0FDF4),
      icon: Icons.park_outlined,
      description: 'Balanced green for a calmer interface.',
      fontFamily: 'Inter',
    ),
    AppThemeConfig(
      id: 'berry',
      label: 'Berry',
      accentColor: Color(0xFFEC4899),
      backgroundColor: Color(0xFFFDF2F8),
      icon: Icons.local_florist_outlined,
      description: 'Pink tone for a more expressive look.',
      fontFamily: 'Inter',
    ),
    AppThemeConfig(
      id: 'violet',
      label: 'Violet',
      accentColor: Color(0xFF8B5CF6),
      backgroundColor: Color(0xFFF5F3FF),
      icon: Icons.auto_awesome_outlined,
      description: 'Soft violet for a modern appearance.',
      fontFamily: 'Inter',
    ),
  ];
}

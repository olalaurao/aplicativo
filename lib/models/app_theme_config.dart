import 'package:flutter/material.dart';

class AppThemeConfig {
  final String id;
  final String label;
  final Color accentColor;
  final Color? backgroundColor;
  final Color? darkBackgroundColor;
  final IconData icon;
  final String description;
  final String? fontFamily;
  
  // Themeable UI properties
  final double borderRadius;
  final double spacingScale;
  final double fontScale;
  final double cardElevation;
  final bool useShadows;
  final Map<String, Color>? habitColors;
  final Map<String, Color>? statusColors;
  final Map<String, Color>? priorityColors;

  const AppThemeConfig({
    required this.id,
    required this.label,
    required this.accentColor,
    this.backgroundColor,
    this.darkBackgroundColor,
    required this.icon,
    required this.description,
    this.fontFamily,
    this.borderRadius = 16.0,
    this.spacingScale = 1.0,
    this.fontScale = 1.0,
    this.cardElevation = 0.0,
    this.useShadows = true,
    this.habitColors,
    this.statusColors,
    this.priorityColors,
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
      id: 'Quartzo',
      label: 'Quartzo',
      accentColor: Color(0xFFF97316),
      backgroundColor: Color(0xFFF8F9FB),
      darkBackgroundColor: Color(0xFF0F1117),
      icon: Icons.wb_sunny_outlined,
      description: 'Vibrant orange for the default app theme.',
      fontFamily: 'Inter',
      borderRadius: 16.0,
      spacingScale: 1.0,
      fontScale: 1.0,
      cardElevation: 0.0,
      useShadows: true,
    ),
    AppThemeConfig(
      id: 'amber',
      label: 'Amber',
      accentColor: Color(0xFFFFB000),
      backgroundColor: Color(0xFFFFFBF0),
      darkBackgroundColor: Color(0xFF110E00),
      icon: Icons.light_mode_outlined,
      description: 'Warm amber with high contrast.',
      fontFamily: 'Inter',
      borderRadius: 16.0,
      spacingScale: 1.0,
      fontScale: 1.0,
      cardElevation: 0.0,
      useShadows: true,
    ),
    AppThemeConfig(
      id: 'ocean',
      label: 'Ocean',
      accentColor: Color(0xFF3B82F6),
      backgroundColor: Color(0xFFF0F9FF),
      darkBackgroundColor: Color(0xFF060B14),
      icon: Icons.water_drop_outlined,
      description: 'Clean blue for navigation and focus.',
      fontFamily: 'Inter',
      borderRadius: 16.0,
      spacingScale: 1.0,
      fontScale: 1.0,
      cardElevation: 0.0,
      useShadows: true,
    ),
    AppThemeConfig(
      id: 'forest',
      label: 'Forest',
      accentColor: Color(0xFF22C55E),
      backgroundColor: Color(0xFFF0FDF4),
      darkBackgroundColor: Color(0xFF060F08),
      icon: Icons.park_outlined,
      description: 'Balanced green for a calmer interface.',
      fontFamily: 'Inter',
      borderRadius: 16.0,
      spacingScale: 1.0,
      fontScale: 1.0,
      cardElevation: 0.0,
      useShadows: true,
    ),
    AppThemeConfig(
      id: 'berry',
      label: 'Berry',
      accentColor: Color(0xFFEC4899),
      backgroundColor: Color(0xFFFDF2F8),
      darkBackgroundColor: Color(0xFF130610),
      icon: Icons.local_florist_outlined,
      description: 'Pink tone for a more expressive look.',
      fontFamily: 'Inter',
      borderRadius: 16.0,
      spacingScale: 1.0,
      fontScale: 1.0,
      cardElevation: 0.0,
      useShadows: true,
    ),
    AppThemeConfig(
      id: 'violet',
      label: 'Violet',
      accentColor: Color(0xFF8B5CF6),
      backgroundColor: Color(0xFFF5F3FF),
      darkBackgroundColor: Color(0xFF0A0814),
      icon: Icons.auto_awesome_outlined,
      description: 'Soft violet for a modern appearance.',
      fontFamily: 'Inter',
      borderRadius: 16.0,
      spacingScale: 1.0,
      fontScale: 1.0,
      cardElevation: 0.0,
      useShadows: true,
    ),
  ];
}

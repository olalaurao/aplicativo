import 'package:flutter/material.dart';

class AppThemeConfig {
  final String id;
  final String label;
  final Color accentColor;
  final IconData icon;
  final String description;

  const AppThemeConfig({
    required this.id,
    required this.label,
    required this.accentColor,
    required this.icon,
    required this.description,
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
      icon: Icons.wb_sunny_outlined,
      description: 'Laranja vibrante para o tema padrão do app.',
    ),
    AppThemeConfig(
      id: 'amber',
      label: 'Amber',
      accentColor: Color(0xFFFFB000),
      icon: Icons.light_mode_outlined,
      description: 'Âmbar quente com contraste alto.',
    ),
    AppThemeConfig(
      id: 'ocean',
      label: 'Ocean',
      accentColor: Color(0xFF3B82F6),
      icon: Icons.water_drop_outlined,
      description: 'Azul limpo para navegação e foco.',
    ),
    AppThemeConfig(
      id: 'forest',
      label: 'Forest',
      accentColor: Color(0xFF22C55E),
      icon: Icons.park_outlined,
      description: 'Verde equilibrado para uma interface mais calma.',
    ),
    AppThemeConfig(
      id: 'berry',
      label: 'Berry',
      accentColor: Color(0xFFEC4899),
      icon: Icons.local_florist_outlined,
      description: 'Tom rosado para uma aparência mais expressiva.',
    ),
    AppThemeConfig(
      id: 'violet',
      label: 'Violet',
      accentColor: Color(0xFF8B5CF6),
      icon: Icons.auto_awesome_outlined,
      description: 'Violeta suave para uma aparência moderna.',
    ),
  ];
}

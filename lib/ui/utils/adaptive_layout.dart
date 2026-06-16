// lib/ui/utils/adaptive_layout.dart
import 'package:flutter/material.dart';

/// Helper para adaptar tamanhos de UI a telas pequenas.
/// Telas < 380px (alguns Androids entry-level) precisam de ajustes.
class AdaptiveLayout {
  /// Retorna fontSize reduzido em telas < 380px de largura.
  static double fontSize(BuildContext context, double base) {
    final w = MediaQuery.of(context).size.width;
    if (w < 340) return base * 0.82;
    if (w < 380) return base * 0.91;
    return base;
  }

  /// Retorna padding horizontal reduzido em telas pequenas.
  static EdgeInsets hPadding(BuildContext context, {double normal = 16}) {
    final w = MediaQuery.of(context).size.width;
    final p = w < 360 ? normal * 0.75 : normal;
    return EdgeInsets.symmetric(horizontal: p);
  }

  /// True se a tela é estreita (< 380px).
  static bool isNarrow(BuildContext context) =>
      MediaQuery.of(context).size.width < 380;

  /// Padding de campo de texto adaptativo.
  static EdgeInsets fieldPadding(BuildContext context) =>
      isNarrow(context)
          ? const EdgeInsets.symmetric(horizontal: 10, vertical: 10)
          : const EdgeInsets.symmetric(horizontal: 14, vertical: 14);

  /// Padding horizontal de botão adaptativo.
  static EdgeInsets buttonPadding(BuildContext context) =>
      isNarrow(context)
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 12)
          : const EdgeInsets.symmetric(horizontal: 20, vertical: 12);
}

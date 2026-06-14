import 'package:flutter/material.dart';

class AdaptiveLayout {
  /// Reduz fontSize proporcionalmente em telas estreitas
  static double fontSize(BuildContext context, double base) {
    final w = MediaQuery.of(context).size.width;
    if (w < 340) return base * 0.82;
    if (w < 380) return base * 0.91;
    return base;
  }

  /// Reduz padding horizontal em telas < 360px
  static double hPad(BuildContext context, {double normal = 16}) {
    return MediaQuery.of(context).size.width < 360 ? normal * 0.75 : normal;
  }

  /// true se tela menor que 380px
  static bool isNarrow(BuildContext context) =>
      MediaQuery.of(context).size.width < 380;

  /// contentPadding adaptativo para TextField
  static EdgeInsets fieldPadding(BuildContext context) {
    return isNarrow(context)
        ? const EdgeInsets.symmetric(horizontal: 10, vertical: 10)
        : const EdgeInsets.symmetric(horizontal: 14, vertical: 14);
  }
}

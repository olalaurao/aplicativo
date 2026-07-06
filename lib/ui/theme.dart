// lib/ui/theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/task_model.dart';

class AppColors {
  // Brand
  static const Color primary = Color(0xFFFFB000); // Vibrant Gold/Amber
  static const Color primaryLight = Color(0xFFFFD54F);
  static const Color primaryDark = Color(0xFFE65100);
  static const Color accent = Color(0xFFFFB000);
  static const Color secondary = Color(0xFF0EA5E9); // Vibrant Sky Blue
  static const Color secondaryLight = Color(0xFF7DD3FC);

  // Surfaces ââââ‚¬Å¡Ã‚Â¬âââ€šÂ¬Ã‚Â Light
  static const Color background = Color(0xFFF8F9FB);
  static const Color surface = Colors.white;
  static const Color cardFill = Colors.white;
  static const Color surfaceVariant = Color(0xFFF1F3F5);

  // Surfaces ââââ‚¬Å¡Ã‚Â¬âââ€šÂ¬Ã‚Â Dark
  static const Color darkBackground = Color(0xFF0F1117);
  static const Color darkSurface = Color(0xFF1A1C25);
  static const Color darkCardFill = Color(0xFF22252F);

  // Text ââââ‚¬Å¡Ã‚Â¬âââ€šÂ¬Ã‚Â Light
  static const Color textPrimary = Color(0xFF1A1D26);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);
  static const Color textOnPrimary = Colors.white;

  // Text ââââ‚¬Å¡Ã‚Â¬âââ€šÂ¬Ã‚Â Dark
  static const Color darkTextPrimary = Color(0xFFF3F4F6);
  static const Color darkTextSecondary = Color(0xFF9CA3AF);

  // Status
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Priority
  static const Color priorityHigh = Color(0xFFEF4444);
  static const Color priorityMedium = Color(0xFFF59E0B);
  static const Color priorityLow = Color(0xFF3B82F6);

  // Habits
  static const Color habitGreen = Color(0xFF22C55E);
  static const Color habitBlue = Color(0xFF3B82F6);
  static const Color habitPurple = Color(0xFF8B5CF6);
  static const Color habitOrange = Color(0xFFF97316);
  static const Color habitPink = Color(0xFFEC4899);

  // Divider
  static const Color divider = Color(0xFFE5E7EB);
  static const Color darkDivider = Color(0xFF2D3040);

  // Bottom Nav
  static const Color navInactive = Color(0xFF9CA3AF);
}

class AppTheme {
  static const Gradient primaryGradient = LinearGradient(
    colors: [AppColors.primary, AppColors.primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ââââ€šÂ¬Ã‚Ââââ‚¬Å¡Ã‚Â¬ââââ€šÂ¬Ã‚Ââââ‚¬Å¡Ã‚Â¬ââââ€šÂ¬Ã‚Ââââ‚¬Å¡Ã‚Â¬ Card Decoration ââââ€šÂ¬Ã‚Ââââ‚¬Å¡Ã‚Â¬ââââ€šÂ¬Ã‚Ââââ‚¬Å¡Ã‚Â¬ââââ€šÂ¬Ã‚Ââââ‚¬Å¡Ã‚Â¬
  static BoxDecoration cardDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark ? AppColors.darkCardFill : AppColors.cardFill,
      borderRadius: BorderRadius.circular(20), // More rounded
      border: Border.all(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.03),
        width: 1,
      ),
      boxShadow: isDark
          ? []
          : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
    );
  }

  static BoxDecoration cardDecorationFlat(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark ? AppColors.darkCardFill : AppColors.cardFill,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: isDark ? AppColors.darkDivider : AppColors.divider,
        width: 1,
      ),
    );
  }

  // ââââ€šÂ¬Ã‚Ââââ‚¬Å¡Ã‚Â¬ââââ€šÂ¬Ã‚Ââââ‚¬Å¡Ã‚Â¬ââââ€šÂ¬Ã‚Ââââ‚¬Å¡Ã‚Â¬ Chip Style ââââ€šÂ¬Ã‚Ââââ‚¬Å¡Ã‚Â¬ââââ€šÂ¬Ã‚Ââââ‚¬Å¡Ã‚Â¬ââââ€šÂ¬Ã‚Ââââ‚¬Å¡Ã‚Â¬
  static BoxDecoration chipDecoration(Color color) {
    return BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
    );
  }

  // ââââ€šÂ¬Ã‚Ââââ‚¬Å¡Ã‚Â¬ââââ€šÂ¬Ã‚Ââââ‚¬Å¡Ã‚Â¬ââââ€šÂ¬Ã‚Ââââ‚¬Å¡Ã‚Â¬ Badge Style ââââ€šÂ¬Ã‚Ââââ‚¬Å¡Ã‚Â¬ââââ€šÂ¬Ã‚Ââââ‚¬Å¡Ã‚Â¬ââââ€šÂ¬Ã‚Ââââ‚¬Å¡Ã‚Â¬
  static BoxDecoration badgeDecoration(Color color) {
    return BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(6),
    );
  }

  // ââââ€šÂ¬Ã‚Ââââ‚¬Å¡Ã‚Â¬ââââ€šÂ¬Ã‚Ââââ‚¬Å¡Ã‚Â¬ââââ€šÂ¬Ã‚Ââââ‚¬Å¡Ã‚Â¬ Section Header Style ââââ€šÂ¬Ã‚Ââââ‚¬Å¡Ã‚Â¬ââââ€šÂ¬Ã‚Ââââ‚¬Å¡Ã‚Â¬ââââ€šÂ¬Ã‚Ââââ‚¬Å¡Ã‚Â¬
  static TextStyle sectionHeaderStyle(BuildContext context) {
    return TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w700,
      color: Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkTextPrimary
          : AppColors.textPrimary,
      letterSpacing: -0.3,
    );
  }

  static Color backgroundColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? AppColors.darkBackground
      : AppColors.background;

  static Color surfaceColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? AppColors.darkSurface
      : AppColors.surface;

  static Color cardFillColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? AppColors.darkCardFill
      : AppColors.cardFill;

  static Color surfaceVariantColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? AppColors.darkCardFill
      : AppColors.surfaceVariant;

  static Color textPrimaryColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? AppColors.darkTextPrimary
      : AppColors.textPrimary;

  static Color textSecondaryColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? AppColors.darkTextSecondary
      : AppColors.textSecondary;

  static Color textMutedColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? AppColors.darkTextSecondary.withValues(alpha: 0.7)
      : AppColors.textMuted;

  static Color dividerColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? AppColors.darkDivider
      : AppColors.divider;

  static BoxDecoration sheetDecoration(BuildContext context) {
    return BoxDecoration(
      color: surfaceColor(context),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
    );
  }

  static Color priorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high:
        return AppColors.priorityHigh;
      case TaskPriority.medium:
        return AppColors.priorityMedium;
      case TaskPriority.low:
        return AppColors.priorityLow;
      case TaskPriority.none:
        return AppColors.textMuted;
    }
  }

  // ââââ€šÂ¬Ã‚Ââââ‚¬Å¡Ã‚Â¬ââââ€šÂ¬Ã‚Ââââ‚¬Å¡Ã‚Â¬ââââ€šÂ¬Ã‚Ââââ‚¬Å¡Ã‚Â¬ Button Styles ââââ€šÂ¬Ã‚Ââââ‚¬Å¡Ã‚Â¬ââââ€šÂ¬Ã‚Ââââ‚¬Å¡Ã‚Â¬ââââ€šÂ¬Ã‚Ââââ‚¬Å¡Ã‚Â¬
  static ButtonStyle get primaryButtonStyle {
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.accent,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0,
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    );
  }

  static ButtonStyle get secondaryButtonStyle {
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.surfaceVariant,
      foregroundColor: AppColors.textPrimary,
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0,
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    );
  }

  // ââââ€šÂ¬Ã‚Ââââ‚¬Å¡Ã‚Â¬ââââ€šÂ¬Ã‚Ââââ‚¬Å¡Ã‚Â¬ââââ€šÂ¬Ã‚Ââââ‚¬Å¡Ã‚Â¬ Themes ââââ€šÂ¬Ã‚Ââââ‚¬Å¡Ã‚Â¬ââââ€šÂ¬Ã‚Ââââ‚¬Å¡Ã‚Â¬ââââ€šÂ¬Ã‚Ââââ‚¬Å¡Ã‚Â¬
  static ThemeData getLightTheme(
    Color accentColor, {
    Color? backgroundColor,
    String? fontFamily,
  }) {
    final base = ThemeData(brightness: Brightness.light, useMaterial3: true);
    final textTheme = fontFamily != null
        ? GoogleFonts.getTextTheme(fontFamily, base.textTheme)
        : GoogleFonts.interTextTheme(base.textTheme);

    return base.copyWith(
      
      scaffoldBackgroundColor: backgroundColor ?? AppColors.background,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
        },
      ),
      textTheme: textTheme.copyWith(
        headlineLarge: textTheme.headlineLarge?.copyWith(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          letterSpacing: -0.5,
        ),
        headlineMedium: textTheme.headlineMedium?.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          letterSpacing: -0.3,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        titleMedium: textTheme.titleMedium?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(
          fontSize: 16,
          color: AppColors.textPrimary,
          height: 1.5,
        ),
        bodyMedium: textTheme.bodyMedium?.copyWith(
          fontSize: 14,
          color: AppColors.textSecondary,
          height: 1.4,
        ),
        bodySmall: textTheme.bodySmall?.copyWith(
          fontSize: 12,
          color: AppColors.textMuted,
        ),
        labelSmall: textTheme.labelSmall?.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textMuted,
          letterSpacing: 0.5,
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        titleTextStyle: textTheme.headlineMedium?.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.surface,
        selectedItemColor: accentColor,
        unselectedItemColor: AppColors.navInactive,
        selectedLabelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 0,
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardFill,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceVariant,
        labelStyle: textTheme.bodySmall?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: const CircleBorder(),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accentColor, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 15),
      ),
    );
  }

  static ThemeData getDarkTheme(
    Color accentColor, {
    String? fontFamily,
  }) {
    final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
    final textTheme = (fontFamily != null
        ? GoogleFonts.getTextTheme(fontFamily, base.textTheme)
        : GoogleFonts.interTextTheme(base.textTheme)).apply(
      bodyColor: AppColors.darkTextPrimary,
      displayColor: AppColors.darkTextPrimary,
    );

    return base.copyWith(
      
      scaffoldBackgroundColor: AppColors.darkBackground,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
        },
      ),
      textTheme: textTheme.copyWith(
        headlineLarge: textTheme.headlineLarge?.copyWith(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        headlineMedium: textTheme.headlineMedium?.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: textTheme.titleMedium?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(fontSize: 16, height: 1.5),
        bodyMedium: textTheme.bodyMedium?.copyWith(
          fontSize: 14,
          color: AppColors.darkTextSecondary,
          height: 1.4,
        ),
        bodySmall: textTheme.bodySmall?.copyWith(
          fontSize: 12,
          color: AppColors.darkTextSecondary,
        ),
        labelSmall: textTheme.labelSmall?.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.darkBackground,
        foregroundColor: AppColors.darkTextPrimary,
        titleTextStyle: textTheme.headlineMedium?.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.darkSurface,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: AppColors.navInactive,
        selectedLabelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.darkDivider,
        thickness: 1,
        space: 0,
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkCardFill,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryLight,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: CircleBorder(),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.primaryLight,
            width: 1.5,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: const TextStyle(
          color: AppColors.darkTextSecondary,
          fontSize: 15,
        ),
      ),
    );
  }
}

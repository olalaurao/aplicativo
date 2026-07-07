// lib/ui/theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/task_model.dart';

class AppBorderRadius {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
}

class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
}

class AppTextSize {
  static const double xs = 10.0;
  static const double sm = 12.0;
  static const double md = 14.0;
  static const double lg = 16.0;
  static const double xl = 18.0;
  static const double xxl = 20.0;
  static const double display = 28.0;
}

class AppBorder {
  static const double thin = 1.0;
  static const double normal = 1.5;
  static const double thick = 2.0;
  static const double extraThick = 3.0;
}

class AppIconSize {
  static const double xs = 12.0;
  static const double sm = 16.0;
  static const double md = 20.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
  static const double display = 56.0;
}

class AppColors {
  // Brand — default fallback (orange). Use AppTheme.accentColor(context) for dynamic accent.
  static const Color primary = Color(0xFFF97316);
  static const Color primaryLight = Color(0xFFFFD54F);
  static const Color primaryDark = Color(0xFFE65100);
  static const Color accent = Color(0xFFF97316);
  static const Color secondary = Color(0xFF0EA5E9);
  static const Color secondaryLight = Color(0xFF7DD3FC);

  // Surfaces — Light
  static const Color background = Color(0xFFF8F9FB);
  static const Color surface = Colors.white;
  static const Color cardFill = Colors.white;
  static const Color surfaceVariant = Color(0xFFF1F3F5);

  // Surfaces — Dark
  static const Color darkBackground = Color(0xFF0F1117);
  static const Color darkSurface = Color(0xFF1A1C25);
  static const Color darkCardFill = Color(0xFF22252F);

  // Text — Light
  static const Color textPrimary = Color(0xFF1A1D26);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);
  static const Color textOnPrimary = Colors.white;

  // Text — Dark
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
  /// Dynamic accent color — reads from the active ThemeData's colorScheme.
  /// Use this instead of AppColors.primary whenever you have a BuildContext.
  static Color accentColor(BuildContext context) =>
      Theme.of(context).colorScheme.primary;

  static Gradient primaryGradient(BuildContext context) => LinearGradient(
    colors: [accentColor(context), accentColor(context).withValues(alpha: 0.7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ─── Card Decoration ───────────────────────────────────────────────────────
  static BoxDecoration cardDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark ? AppColors.darkCardFill : AppColors.cardFill,
      borderRadius: BorderRadius.circular(AppBorderRadius.xl),
      border: Border.all(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.03),
        width: AppBorder.thin,
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
      borderRadius: BorderRadius.circular(AppBorderRadius.lg),
      border: Border.all(
        color: isDark ? AppColors.darkDivider : AppColors.divider,
        width: AppBorder.thin,
      ),
    );
  }

  // ─── Chip Style ────────────────────────────────────────────────────────────
  static BoxDecoration chipDecoration(Color color) {
    return BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(AppBorderRadius.xl),
    );
  }

  // ─── Badge Style ───────────────────────────────────────────────────────────
  static BoxDecoration badgeDecoration(Color color) {
    return BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(AppBorderRadius.sm),
    );
  }

  // ─── Section Header Style ──────────────────────────────────────────────────
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
      Theme.of(context).scaffoldBackgroundColor;

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
      borderRadius: const BorderRadius.vertical(top: Radius.circular(AppBorderRadius.xxl)),
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

  // ─── Button Styles ─────────────────────────────────────────────────────────
  static ButtonStyle primaryButtonStyle(Color accentColor) {
    return ElevatedButton.styleFrom(
      backgroundColor: accentColor,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppBorderRadius.md)),
      elevation: 0,
      textStyle: const TextStyle(fontSize: AppTextSize.lg, fontWeight: FontWeight.w700),
    );
  }

  static ButtonStyle get secondaryButtonStyle {
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.surfaceVariant,
      foregroundColor: AppColors.textPrimary,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppBorderRadius.md)),
      elevation: 0,
      textStyle: const TextStyle(fontSize: AppTextSize.lg, fontWeight: FontWeight.w600),
    );
  }

  // ─── Themes ────────────────────────────────────────────────────────────────
  static ThemeData getLightTheme(
    Color accentColor, {
    Color? backgroundColor,
    String? fontFamily,
  }) {
    final base = ThemeData(brightness: Brightness.light, useMaterial3: true);
    final textTheme = fontFamily != null
        ? GoogleFonts.getTextTheme(fontFamily, base.textTheme)
        : GoogleFonts.interTextTheme(base.textTheme);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: accentColor,
      brightness: Brightness.light,
    ).copyWith(
      primary: accentColor,
      secondary: accentColor,
      surface: AppColors.surface,
    );

    return base.copyWith(
      colorScheme: colorScheme,
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
          fontSize: AppTextSize.display,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          letterSpacing: -0.5,
        ),
        headlineMedium: textTheme.headlineMedium?.copyWith(
          fontSize: AppTextSize.xxl,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          letterSpacing: -0.3,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          fontSize: AppTextSize.xl,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        titleMedium: textTheme.titleMedium?.copyWith(
          fontSize: AppTextSize.lg,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(
          fontSize: AppTextSize.lg,
          color: AppColors.textPrimary,
          height: 1.5,
        ),
        bodyMedium: textTheme.bodyMedium?.copyWith(
          fontSize: AppTextSize.md,
          color: AppColors.textSecondary,
          height: 1.4,
        ),
        bodySmall: textTheme.bodySmall?.copyWith(
          fontSize: AppTextSize.sm,
          color: AppColors.textMuted,
        ),
        labelSmall: textTheme.labelSmall?.copyWith(
          fontSize: AppTextSize.xs,
          fontWeight: FontWeight.w600,
          color: AppColors.textMuted,
          letterSpacing: 0.5,
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: backgroundColor ?? AppColors.background,
        foregroundColor: AppColors.textPrimary,
        titleTextStyle: textTheme.headlineMedium?.copyWith(
          fontSize: AppTextSize.xxl,
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
          fontSize: AppTextSize.xs,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: AppTextSize.xs,
          fontWeight: FontWeight.w500,
        ),
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: AppBorder.thin,
        space: 0,
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardFill,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppBorderRadius.lg)),
        margin: EdgeInsets.zero,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceVariant,
        labelStyle: textTheme.bodySmall?.copyWith(
          fontSize: AppTextSize.sm,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppBorderRadius.xl)),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
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
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
          borderSide: BorderSide(color: accentColor, width: AppBorder.normal),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: AppTextSize.lg),
      ),
    );
  }

  static ThemeData getDarkTheme(
    Color accentColor, {
    String? fontFamily,
    Color? backgroundColor,
  }) {
    final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
    final textTheme = (fontFamily != null
        ? GoogleFonts.getTextTheme(fontFamily, base.textTheme)
        : GoogleFonts.interTextTheme(base.textTheme)).apply(
      bodyColor: AppColors.darkTextPrimary,
      displayColor: AppColors.darkTextPrimary,
    );
    final effectiveBg = backgroundColor ?? AppColors.darkBackground;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: accentColor,
      brightness: Brightness.dark,
    ).copyWith(
      primary: accentColor,
      secondary: accentColor,
      surface: AppColors.darkSurface,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: effectiveBg,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
        },
      ),
      textTheme: textTheme.copyWith(
        headlineLarge: textTheme.headlineLarge?.copyWith(
          fontSize: AppTextSize.display,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        headlineMedium: textTheme.headlineMedium?.copyWith(
          fontSize: AppTextSize.xxl,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          fontSize: AppTextSize.xl,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: textTheme.titleMedium?.copyWith(
          fontSize: AppTextSize.lg,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(fontSize: AppTextSize.lg, height: 1.5),
        bodyMedium: textTheme.bodyMedium?.copyWith(
          fontSize: AppTextSize.md,
          color: AppColors.darkTextSecondary,
          height: 1.4,
        ),
        bodySmall: textTheme.bodySmall?.copyWith(
          fontSize: AppTextSize.sm,
          color: AppColors.darkTextSecondary,
        ),
        labelSmall: textTheme.labelSmall?.copyWith(
          fontSize: AppTextSize.xs,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: effectiveBg,
        foregroundColor: AppColors.darkTextPrimary,
        titleTextStyle: textTheme.headlineMedium?.copyWith(
          fontSize: AppTextSize.xxl,
          fontWeight: FontWeight.w700,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.darkSurface,
        selectedItemColor: accentColor,
        unselectedItemColor: AppColors.navInactive,
        selectedLabelStyle: const TextStyle(
          fontSize: AppTextSize.xs,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: AppTextSize.xs,
          fontWeight: FontWeight.w500,
        ),
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.darkDivider,
        thickness: AppBorder.thin,
        space: 0,
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkCardFill,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppBorderRadius.lg)),
        margin: EdgeInsets.zero,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: const CircleBorder(),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
          borderSide: BorderSide(color: accentColor, width: AppBorder.normal),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        hintStyle: const TextStyle(
          color: AppColors.darkTextSecondary,
          fontSize: AppTextSize.lg,
        ),
      ),
    );
  }
}

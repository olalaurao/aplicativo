$content = Get-Content 'lib/ui/theme.dart' -Raw

# Fix the method signature
$content = $content -replace 'static ThemeData getLightTheme\\\(\\n    Color accentColor, \{\\n    Color\? backgroundColor,\\n    String\? fontFamily,\\n  \}\) \{', 'static ThemeData getLightTheme(`n    Color accentColor, {`n    Color? backgroundColor,`n    String? fontFamily,`n  }) {'

# Fix the textTheme assignment
$content = $content -replace 'final textTheme = GoogleFonts\.interTextTheme\(base\.textTheme\);', 'final textTheme = fontFamily != null`n        ? GoogleFonts.getTextTheme(fontFamily, base.textTheme)`n        : GoogleFonts.interTextTheme(base.textTheme);'

# Fix the scaffoldBackgroundColor
$content = $content -replace 'scaffoldBackgroundColor: AppColors\.background,', 'scaffoldBackgroundColor: backgroundColor ?? AppColors.background,'

Set-Content 'lib/ui/theme.dart' -Value $content -NoNewline

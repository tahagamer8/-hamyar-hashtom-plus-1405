import 'package:flutter/material.dart';
import 'package:hamyar_hashtom_plus/core/theme/app_colors.dart';

/// Design language inspired by Samsung One UI:
/// calm surfaces, generous touch targets, rounded geometry and clear hierarchy.
abstract final class AppTheme {
  static const String fontFamily = 'Vazirmatn';

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      secondary: AppColors.secondary,
      brightness: brightness,
      surface: isLight ? const Color(0xFFFCFCFF) : const Color(0xFF171B2A),
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: fontFamily,
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
    );
    final surface = isLight ? const Color(0xFFFCFCFF) : AppColors.darkSurface;

    return base.copyWith(
      scaffoldBackgroundColor:
          isLight ? const Color(0xFFF3F5FA) : AppColors.darkBackground,
      textTheme: _textTheme(
        base.textTheme.apply(
          bodyColor: scheme.onSurface,
          displayColor: scheme.onSurface,
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        titleSpacing: 24,
        toolbarHeight: 64,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 21,
          fontWeight: FontWeight.w800,
          color: scheme.onSurface,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 76,
        elevation: 0,
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withAlpha(isLight ? 22 : 48),
        indicatorShape: const StadiumBorder(),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: fontFamily,
            fontSize: 11,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
          );
        }),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: scheme.outlineVariant.withAlpha(isLight ? 100 : 65),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? const Color(0xFFF0F2F8) : const Color(0xFF22283A),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withAlpha(110),
        thickness: 1,
        space: 1,
      ),
    );
  }

  static TextTheme _textTheme(TextTheme t) {
    return t.copyWith(
      headlineMedium: t.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
        height: 1.35,
      ),
      headlineSmall: t.headlineSmall?.copyWith(
        fontWeight: FontWeight.w800,
        height: 1.4,
      ),
      titleLarge: t.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
        height: 1.45,
      ),
      titleMedium: t.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        height: 1.5,
      ),
      titleSmall: t.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
        height: 1.5,
      ),
      bodyLarge: t.bodyLarge?.copyWith(height: 1.75),
      bodyMedium: t.bodyMedium?.copyWith(height: 1.65),
      bodySmall: t.bodySmall?.copyWith(height: 1.55),
      labelLarge: t.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

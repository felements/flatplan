import 'package:flutter/material.dart';

/// Centralized theme configuration for FlatPlan.
///
/// Inspired by a dark premium dashboard aesthetic with warm gold accents,
/// muted teal secondary tones, and generous spacing.
abstract final class AppTheme {
  // ─── Core palette ─────────────────────────────────────────────────────

  static const Color _gold = Color(0xFFD4A84B);
  static const Color _goldLight = Color(0xFFE5BF6A);
  static const Color _teal = Color(0xFF5A8F7B);
  static const Color _coral = Color(0xFFE07A5F);

  // Dark surface ramp
  static const Color _scaffoldDark = Color(0xFF121218);
  static const Color _surfaceDark = Color(0xFF1A1A24);
  static const Color _surfaceContainerDark = Color(0xFF1E1E2E);
  static const Color _surfaceContainerHighDark = Color(0xFF252532);
  static const Color _surfaceBrightDark = Color(0xFF2C2C3A);

  static const Color _onSurfaceDark = Color(0xFFE8E6F0);
  static const Color _onSurfaceVariantDark = Color(0xFF9D9BAA);

  // Card tint palette (used for summary cards)
  static const Color cardGold = Color(0xFF3D351F);
  static const Color cardTeal = Color(0xFF1D3129);
  static const Color cardGreen = Color(0xFF1F3325);
  static const Color cardCoral = Color(0xFF3D2420);

  // ─── Typography ───────────────────────────────────────────────────────

  static TextTheme _buildTextTheme(Brightness brightness) {
    final base = brightness == Brightness.dark
        ? ThemeData.dark().textTheme
        : ThemeData.light().textTheme;
    return base.apply(fontFamily: 'Outfit');
  }

  // ─── Dark Theme ───────────────────────────────────────────────────────

  static ThemeData get darkTheme {
    final textTheme = _buildTextTheme(Brightness.dark);

    final colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: _gold,
      onPrimary: const Color(0xFF1A1400),
      primaryContainer: const Color(0xFF3D351F),
      onPrimaryContainer: _goldLight,
      secondary: _teal,
      onSecondary: const Color(0xFF0D1F18),
      secondaryContainer: const Color(0xFF1D3129),
      onSecondaryContainer: const Color(0xFFA8D5C0),
      tertiary: const Color(0xFF8B9FD4),
      onTertiary: const Color(0xFF141929),
      tertiaryContainer: const Color(0xFF232840),
      onTertiaryContainer: const Color(0xFFC5D0ED),
      error: _coral,
      onError: const Color(0xFF1F0D08),
      errorContainer: cardCoral,
      onErrorContainer: const Color(0xFFF0B8A6),
      surface: _surfaceDark,
      onSurface: _onSurfaceDark,
      onSurfaceVariant: _onSurfaceVariantDark,
      outline: const Color(0xFF3A3A4A),
      outlineVariant: const Color(0xFF2A2A38),
      surfaceContainerLowest: _scaffoldDark,
      surfaceContainerLow: _surfaceContainerDark,
      surfaceContainer: _surfaceContainerDark,
      surfaceContainerHigh: _surfaceContainerHighDark,
      surfaceContainerHighest: _surfaceBrightDark,
      inverseSurface: const Color(0xFFE8E6F0),
      onInverseSurface: const Color(0xFF1A1A24),
      shadow: Colors.black,
      scrim: Colors.black,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _scaffoldDark,
      textTheme: textTheme,

      // App bar
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: _onSurfaceDark,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: _onSurfaceDark),
      ),

      // Card
      cardTheme: CardThemeData(
        elevation: 0,
        color: _surfaceContainerDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(vertical: 6),
      ),

      // Elevated button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _gold,
          foregroundColor: const Color(0xFF1A1400),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Text button
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: _gold),
      ),

      // Floating action button
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _gold,
        foregroundColor: const Color(0xFF1A1400),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),

      // Navigation rail
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: _surfaceDark,
        selectedIconTheme: const IconThemeData(color: _gold, size: 22),
        unselectedIconTheme: const IconThemeData(
          color: _onSurfaceVariantDark,
          size: 22,
        ),
        selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: _gold,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: _onSurfaceVariantDark,
        ),
        indicatorColor: _gold.withValues(alpha: 0.15),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      // Input decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surfaceContainerHighDark,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _gold, width: 1.5),
        ),
        labelStyle: TextStyle(color: _onSurfaceVariantDark),
        hintStyle: TextStyle(
          color: _onSurfaceVariantDark.withValues(alpha: 0.6),
        ),
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: _surfaceContainerDark,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: textTheme.headlineSmall?.copyWith(
          color: _onSurfaceDark,
          fontWeight: FontWeight.w600,
        ),
      ),

      // Divider
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 0.5,
        space: 0.5,
      ),

      // Checkbox
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return _gold;
          return Colors.transparent;
        }),
        checkColor: WidgetStatePropertyAll(const Color(0xFF1A1400)),
        side: BorderSide(color: _onSurfaceVariantDark, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _surfaceBrightDark,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: _onSurfaceDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),

      // Progress indicator
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: _gold,
        linearTrackColor: _surfaceContainerHighDark,
      ),

      // ListTile
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        textColor: _onSurfaceDark,
        iconColor: _onSurfaceVariantDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  // ─── Light Theme ──────────────────────────────────────────────────────

  static ThemeData get lightTheme {
    final textTheme = _buildTextTheme(Brightness.light);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _gold,
        brightness: Brightness.light,
      ),
      textTheme: textTheme,
      cardTheme: CardThemeData(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}

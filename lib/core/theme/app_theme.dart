import 'package:flutter/material.dart';

/// IPOSB Material 3 theme — logistics brand: deep blue + amber accent.
abstract final class AppTheme {
  static const Color _seedColor = Color(0xFF1565C0); // Logistics blue
  static const Color _accentColor = Color(0xFFFF8F00); // Amber accent

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.light,
    ).copyWith(
      secondary: _accentColor,
      tertiary: const Color(0xFF2E7D32),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          // Height only — infinite min-width crashes FilledButton inside Rows
          // (Track order, Scan CN, dialogs). Full-width screens still stretch
          // via Column crossAxisAlignment: stretch.
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorColor: colorScheme.primaryContainer,
      ),
    );
  }

  static ThemeData get dark {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.dark,
    ).copyWith(
      secondary: _accentColor,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
    );
  }
}

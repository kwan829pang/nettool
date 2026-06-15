import 'package:flutter/material.dart';

class AppTheme {
  static const Color accentBlue = Color(0xFF0078D4);
  static const Color sidebarBg = Color(0xFFF3F3F3);
  static const Color panelBorder = Color(0xFFE0E0E0);
  static const Color statusBarBg = Color(0xFF0078D4);

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: accentBlue,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFFFAFAFA),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: sidebarBg,
        indicatorColor: Color(0xFFD6EAF8),
        selectedIconTheme: IconThemeData(color: accentBlue),
        selectedLabelTextStyle: TextStyle(
          color: accentBlue,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: panelBorder),
        ),
        color: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: panelBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: panelBorder),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accentBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
      dividerTheme: const DividerThemeData(color: panelBorder, thickness: 1),
    );
  }
}

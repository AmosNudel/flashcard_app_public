import 'package:flutter/material.dart';

abstract class AppColors {
  // Accents
  static const Color teal = Color(0xFF00ADB5);
  static const Color tealLight = Color(0xFF02BFC9);
  static const Color tealDark = Color(0xFF01939B);
  static const Color green = Color(0xFF287A4C);

  // Light Mode Palette
  static const Color lightBg = Color(0xFFEEEEEE);
  static const Color lightCard = Color(0xFFF5F5F5);
  static const Color lightBorder = Color(0xFFD3D3D3);
  static const Color lightText = Color(0xFF393E46);
  static const Color lightTextDark = Color(0xFF222831);
  static const Color lightTextDarkest = Color(0xFF15181C);

  // Dark Mode Palette
  static const Color darkBg = Color(0xFF15181C);
  static const Color darkCard = Color(0xFF222831);
  static const Color darkDarker = Color(0xFF0D0F11);
  static const Color darkText = Color(0xFFF5F5F5);
  static const Color darkTextLight = Color(0xFFEEEEEE);
  static const Color darkTextMuted = Color(0xFFB3B3B3);
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBg,
      cardColor: AppColors.lightCard,
      colorScheme: const ColorScheme.light(
        primary: AppColors.teal,
        secondary: AppColors.green,
        surface: AppColors.lightCard,
        onSurface: AppColors.lightText,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        outline: AppColors.lightBorder,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.lightBg,
        foregroundColor: AppColors.lightTextDarkest,
        elevation: 0,
        centerTitle: true,
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.teal,
        unselectedLabelColor: AppColors.lightText,
        indicatorColor: AppColors.teal,
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightCard,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.lightBorder, width: 0.8),
        ),
      ),
      dividerColor: AppColors.lightBorder,
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBg,
      cardColor: AppColors.darkCard,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.teal,
        secondary: AppColors.green,
        surface: AppColors.darkCard,
        onSurface: AppColors.darkText,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        // Used for secondary/hint text and icons, so it must stay readable
        // on the dark background.
        outline: AppColors.darkTextMuted,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkBg,
        foregroundColor: AppColors.darkText,
        elevation: 0,
        centerTitle: true,
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.teal,
        unselectedLabelColor: AppColors.darkTextMuted,
        indicatorColor: AppColors.teal,
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkCard,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF2A2F38), width: 0.8),
        ),
      ),
      dividerColor: const Color(0xFF2A2F38),
    );
  }
}

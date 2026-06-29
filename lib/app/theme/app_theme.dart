import 'package:flutter/material.dart';

class AppColors {
  static const ivory = Color(0xFFFFFAF1);
  static const deepGreen = Color(0xFF173D2D);
  static const leafGreen = Color(0xFF2E6B4E);
  static const peach = Color(0xFFFFB28B);
  static const ink = Color(0xFF203027);
  static const mutedInk = Color(0xFF66756B);
  static const card = Color(0xFFFFFFFF);
}

class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.deepGreen,
      brightness: Brightness.light,
      primary: AppColors.deepGreen,
      secondary: AppColors.peach,
      surface: AppColors.card,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.ivory,
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w800,
          color: AppColors.ink,
        ),
        headlineSmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: AppColors.ink,
        ),
        titleMedium: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
        bodyMedium: TextStyle(fontSize: 15, color: AppColors.ink, height: 1.35),
        labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(24)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.deepGreen,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.deepGreen,
          minimumSize: const Size(0, 48),
          side: const BorderSide(color: AppColors.deepGreen),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: AppColors.peach.withValues(alpha: 0.42),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? AppColors.deepGreen
                : AppColors.mutedInk,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

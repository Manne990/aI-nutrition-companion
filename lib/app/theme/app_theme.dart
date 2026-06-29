import 'package:flutter/material.dart';

class AppColors {
  static const ivory = Color(0xFFFFFAF1);
  static const warmSurface = Color(0xFFFFFCF6);
  static const softIvory = Color(0xFFF4EFE3);
  static const oat = Color(0xFFE7E3D7);
  static const deepGreen = Color(0xFF173D2D);
  static const leafGreen = Color(0xFF2E6B4E);
  static const sage = Color(0xFFA7B7A7);
  static const peach = Color(0xFFFFB28B);
  static const peachInk = Color(0xFFF07D55);
  static const ink = Color(0xFF203027);
  static const mutedInk = Color(0xFF66756B);
  static const card = Color(0xFFFFFFFF);
}

class AppSpacing {
  const AppSpacing._();

  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

class AppRadii {
  const AppRadii._();

  static const sm = 14.0;
  static const md = 18.0;
  static const lg = 24.0;
  static const xl = 34.0;
  static const pill = 999.0;
}

class AppShadows {
  const AppShadows._();

  static const soft = <BoxShadow>[
    BoxShadow(color: Color(0x1F173D2D), blurRadius: 26, offset: Offset(0, 12)),
  ];
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
          height: 1.06,
        ),
        headlineSmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: AppColors.ink,
          height: 1.14,
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
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.lg)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.deepGreen,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.deepGreen,
          minimumSize: const Size(0, 48),
          side: const BorderSide(color: AppColors.deepGreen),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
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

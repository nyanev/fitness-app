import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFF0D0D0D);
  static const surface = Color(0xFF1A1A1A);
  static const card = Color(0xFF242424);
  static const accent = Color(0xFF6C63FF);
  static const accentSecondary = Color(0xFF00D9A6);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF9E9E9E);
  static const divider = Color(0xFF2C2C2C);
  static const weightColor = Color(0xFF6C63FF);
  static const fatColor = Color(0xFF00D9A6);
  static const success = Color(0xFF34C759);
  static const warning = Color(0xFFFF9F0A);
  static const heartRateColor = Color(0xFFFF453A);
  static const sleepColor = Color(0xFF5E5CE6);
  static const workoutColor = Color(0xFF34C759);

  // Destructive / danger actions (delete, abandon, error icons, skip).
  static const destructive = Color(0xFFFF3B30);
  // Foreground on accent-colored buttons and badges.
  static const onAccent = Color(0xFFFFFFFF);

  // Delta badges: increase is "bad" (red), decrease is "good" (green).
  static const deltaPositiveColor = Color(0xFFFF3B30);
  static const deltaNegativeColor = Color(0xFF32D74B);

  // Body-composition overview chart: RGB primaries for clear distinction.
  static const chartWeight = Color(0xFF448AFF);
  static const chartFat = Color(0xFFFF5252);
  static const chartMuscle = Color(0xFF69F0AE);

  // Exercise muscle-group color coding.
  static const muscleChest = Color(0xFFFF6B6B);
  static const muscleBack = Color(0xFF4ECDC4);
  static const muscleLegs = Color(0xFF45B7D1);
  static const muscleShoulders = Color(0xFFFFD93D);
  static const muscleBiceps = Color(0xFFA78BFA);
  static const muscleTriceps = Color(0xFF6EE7B7);
  static const muscleCore = Color(0xFFFB923C);
  static const muscleCardio = Color(0xFFF472B6);
}

class AppTheme {
  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.accent,
          secondary: AppColors.accentSecondary,
          surface: AppColors.surface,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.accent,
          unselectedItemColor: AppColors.textSecondary,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
        ),
        fontFamily: 'SF Pro Display',
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 48,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.5,
          ),
          displayMedium: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 34,
            fontWeight: FontWeight.w700,
            letterSpacing: -1,
          ),
          titleLarge: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
          titleMedium: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
          bodyMedium: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
          bodySmall: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
          labelSmall: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
          ),
        ),
      );
}

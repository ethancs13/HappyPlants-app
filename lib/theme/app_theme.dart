import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Backgrounds
  static const Color cream = Color(0xFFF8F6F0);
  static const Color cardBg = Color(0xFFEFEDE5);
  static const Color divider = Color(0xFFDDDAD0);

  // Header / primary
  static const Color darkOlive = Color(0xFF424B2E);

  // Detail screen header (brown)
  static const Color brown = Color(0xFF4C2E05);

  // Accent
  static const Color tan = Color(0xFFCDC28E);
  static const Color olive = Color(0xFF798450);

  // Plant greens
  static const Color forest = Color(0xFF3E6B2E);
  static const Color plantStem = Color(0xFF424B2E);
  static const Color plantLeafMuted = Color(0xFF8A9A6A); // sad plant

  // Pot
  static const Color potBody = Color(0xFF8B5E3C);
  static const Color potRim = Color(0xFF6B4020);
  static const Color potRimAlt = Color(0xFF7B5030);

  // Text
  static const Color textPrimary = Color(0xFF231D13);
  static const Color textMuted = Color(0xFF888878);

  // Status
  static const Color statusGreen = Color(0xFF3E6B2E);
  static const Color statusGreenBg = Color(0xFFD4EDCF);
  static const Color statusRed = Color(0xFFC72F2F);
  static const Color statusRedBg = Color(0xFFFAE5E5);
}

class AppTheme {
  AppTheme._();

  static ThemeData get theme => ThemeData(
        scaffoldBackgroundColor: AppColors.cream,
        fontFamily: 'Inter',
        colorScheme: const ColorScheme.light(
          primary: AppColors.darkOlive,
          secondary: AppColors.forest,
          surface: AppColors.cream,
          error: AppColors.statusRed,
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            color: AppColors.tan,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
          headlineMedium: TextStyle(
            color: AppColors.tan,
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
          titleLarge: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
          titleMedium: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          bodyLarge: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          bodyMedium: TextStyle(
            color: AppColors.textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
          bodySmall: TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w400,
          ),
          labelLarge: TextStyle(
            color: AppColors.cream,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.darkOlive,
            foregroundColor: AppColors.tan,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.cardBg,
          hintStyle: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.divider, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.divider, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.darkOlive, width: 1.5),
          ),
        ),
      );
}

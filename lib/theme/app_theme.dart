import 'package:flutter/material.dart';

// ── Brand / illustration colors (same in both themes) ────────────────────────

class AppColors {
  AppColors._();

  // Header / primary (used for nav bars, FABs — stays the same in dark)
  static const Color darkOlive = Color(0xFF424B2E);
  static const Color brown = Color(0xFF4C2E05);
  static const Color tan = Color(0xFFCDC28E);
  static const Color olive = Color(0xFF798450);

  // Plant greens
  static const Color forest = Color(0xFF3E6B2E);
  static const Color plantStem = Color(0xFF424B2E);
  static const Color plantLeafMuted = Color(0xFF8A9A6A);

  // Pot illustration
  static const Color potBody = Color(0xFF8B5E3C);
  static const Color potRim = Color(0xFF6B4020);
  static const Color potRimAlt = Color(0xFF7B5030);

  // Status foreground (icon/text colors — same in both themes)
  static const Color statusGreen = Color(0xFF3E6B2E);
  static const Color statusRed = Color(0xFFC72F2F);
}

// ── Theme-variable colors (differ between light and dark) ─────────────────────

class HappyColors extends ThemeExtension<HappyColors> {
  const HappyColors({
    required this.bg,
    required this.card,
    required this.divider,
    required this.textPrimary,
    required this.textMuted,
    required this.statusGreenBg,
    required this.statusRedBg,
    required this.statusGreenFg,
    required this.statusRedFg,
    required this.plantSlotBg,
    required this.plantSlotFg,
  });

  final Color bg;
  final Color card;
  final Color divider;
  final Color textPrimary;
  final Color textMuted;
  final Color statusGreenBg;
  final Color statusRedBg;
  final Color statusGreenFg;
  final Color statusRedFg;
  /// Background behind plant illustrations in cards and the detail header.
  final Color plantSlotBg;
  /// Foreground (icons + title text) on top of plantSlotBg.
  final Color plantSlotFg;

  static const light = HappyColors(
    bg: Color(0xFFF8F6F0),
    card: Color(0xFFEFEDE5),
    divider: Color(0xFFDDDAD0),
    textPrimary: Color(0xFF231D13),
    textMuted: Color(0xFF888878),
    statusGreenBg: Color(0xFFD4EDCF),
    statusRedBg: Color(0xFFFAE5E5),
    statusGreenFg: Color(0xFF3E6B2E),
    statusRedFg: Color(0xFFC72F2F),
    plantSlotBg: Color(0xFFB8C9A3),
    plantSlotFg: Color(0xFF1E2810), // dark olive — readable on sage green
  );

  static const dark = HappyColors(
    bg: Color(0xFF1A1C18),
    card: Color(0xFF252820),
    divider: Color(0xFF353830),
    textPrimary: Color(0xFFE8E3D8),
    textMuted: Color(0xFF9A9580),
    statusGreenBg: Color(0xFF1E3520),
    statusRedBg: Color(0xFF3A1A1A),
    statusGreenFg: Color(0xFF7EC86A),
    statusRedFg: Color(0xFFEF7070),
    plantSlotBg: Color(0xFF2E3828),
    plantSlotFg: Color(0xFFCDC28E), // tan — readable on deep forest green
  );

  @override
  HappyColors copyWith({
    Color? bg,
    Color? card,
    Color? divider,
    Color? textPrimary,
    Color? textMuted,
    Color? statusGreenBg,
    Color? statusRedBg,
    Color? statusGreenFg,
    Color? statusRedFg,
    Color? plantSlotBg,
    Color? plantSlotFg,
  }) =>
      HappyColors(
        bg: bg ?? this.bg,
        card: card ?? this.card,
        divider: divider ?? this.divider,
        textPrimary: textPrimary ?? this.textPrimary,
        textMuted: textMuted ?? this.textMuted,
        statusGreenBg: statusGreenBg ?? this.statusGreenBg,
        statusRedBg: statusRedBg ?? this.statusRedBg,
        statusGreenFg: statusGreenFg ?? this.statusGreenFg,
        statusRedFg: statusRedFg ?? this.statusRedFg,
        plantSlotBg: plantSlotBg ?? this.plantSlotBg,
        plantSlotFg: plantSlotFg ?? this.plantSlotFg,
      );

  @override
  HappyColors lerp(ThemeExtension<HappyColors>? other, double t) {
    if (other is! HappyColors) return this;
    return HappyColors(
      bg: Color.lerp(bg, other.bg, t)!,
      card: Color.lerp(card, other.card, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      statusGreenBg: Color.lerp(statusGreenBg, other.statusGreenBg, t)!,
      statusRedBg: Color.lerp(statusRedBg, other.statusRedBg, t)!,
      statusGreenFg: Color.lerp(statusGreenFg, other.statusGreenFg, t)!,
      statusRedFg: Color.lerp(statusRedFg, other.statusRedFg, t)!,
      plantSlotBg: Color.lerp(plantSlotBg, other.plantSlotBg, t)!,
      plantSlotFg: Color.lerp(plantSlotFg, other.plantSlotFg, t)!,
    );
  }
}

extension HappyColorsX on BuildContext {
  HappyColors get col => Theme.of(this).extension<HappyColors>()!;
}

// ── ThemeData ─────────────────────────────────────────────────────────────────

class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(HappyColors.light, Brightness.light);
  static ThemeData get dark => _build(HappyColors.dark, Brightness.dark);

  // Backward-compat alias used before dark mode was added.
  static ThemeData get theme => light;

  static ThemeData _build(HappyColors c, Brightness brightness) => ThemeData(
        brightness: brightness,
        scaffoldBackgroundColor: c.bg,
        fontFamily: 'Inter',
        extensions: [c],
        colorScheme: ColorScheme(
          brightness: brightness,
          primary: AppColors.darkOlive,
          onPrimary: AppColors.tan,
          secondary: AppColors.forest,
          onSecondary: Colors.white,
          surface: c.card,
          onSurface: c.textPrimary,
          error: AppColors.statusRed,
          onError: Colors.white,
        ),
        textTheme: TextTheme(
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
            color: c.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
          titleMedium: TextStyle(
            color: c.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          bodyLarge: TextStyle(
            color: c.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          bodyMedium: TextStyle(
            color: c.textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
          bodySmall: TextStyle(
            color: c.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w400,
          ),
          labelLarge: const TextStyle(
            color: AppColors.tan,
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
          fillColor: c.card,
          hintStyle: TextStyle(
            color: c.textMuted,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: c.divider, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: c.divider, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: AppColors.darkOlive, width: 1.5),
          ),
        ),
      );
}

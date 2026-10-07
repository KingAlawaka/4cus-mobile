import 'package:flutter/material.dart';

/// 4cus design tokens: calm, minimal, distraction-free.
abstract final class FourcusColors {
  // Light palette
  static const Color lightBackground = Color(0xFFFAFAF8);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightInk = Color(0xFF1A1A1A);
  static const Color lightMuted = Color(0xFF6B6B66);
  static const Color lightBorder = Color(0xFFE8E6E1);

  // Dark palette (warm, not pure black)
  static const Color darkBackground = Color(0xFF141312);
  static const Color darkSurface = Color(0xFF1E1C1A);
  static const Color darkInk = Color(0xFFF5F3EE);
  static const Color darkMuted = Color(0xFFA8A49C);
  static const Color darkBorder = Color(0xFF2E2B28);

  // Single accent used sparingly
  static const Color teal = Color(0xFF0D9488);
  static const Color tealSoft = Color(0xFFE0F2F0);
  static const Color tealSoftDark = Color(0xFF1D3A37);

  static const double cardRadius = 16;
}

/// Light + dark Material 3 themes for 4cus.
abstract final class FourcusTheme {
  static ThemeData get light => _build(
        brightness: Brightness.light,
        background: FourcusColors.lightBackground,
        surface: FourcusColors.lightSurface,
        ink: FourcusColors.lightInk,
        muted: FourcusColors.lightMuted,
        border: FourcusColors.lightBorder,
        tealSoft: FourcusColors.tealSoft,
      );

  static ThemeData get dark => _build(
        brightness: Brightness.dark,
        background: FourcusColors.darkBackground,
        surface: FourcusColors.darkSurface,
        ink: FourcusColors.darkInk,
        muted: FourcusColors.darkMuted,
        border: FourcusColors.darkBorder,
        tealSoft: FourcusColors.tealSoftDark,
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color ink,
    required Color muted,
    required Color border,
    required Color tealSoft,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: FourcusColors.teal,
      brightness: brightness,
    ).copyWith(
      surface: surface,
      primary: FourcusColors.teal,
      onPrimary: Colors.white,
      primaryContainer: tealSoft,
      onPrimaryContainer: FourcusColors.teal,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: ink,
        displayColor: ink,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          color: ink,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(FourcusColors.cardRadius),
          side: BorderSide(color: border, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: FourcusColors.teal,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 52),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: FourcusColors.teal,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size(0, 48),
          side: BorderSide(color: border, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(color: muted, fontSize: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: FourcusColors.teal, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: FourcusColors.teal,
        unselectedItemColor: muted,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
        selectedLabelStyle:
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? FourcusColors.teal
              : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? FourcusColors.teal.withValues(alpha: 0.4)
              : null,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: FourcusColors.teal,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? FourcusColors.teal
              : null,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }
}

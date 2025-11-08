import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:admin_app/theme/brand_colors.dart';

ThemeData buildLightTheme() {
  final cs =
      ColorScheme.fromSeed(
        brightness: Brightness.light,
        seedColor: AppColors.marine,
      ).copyWith(
        primary: AppColors.marine,
        secondary: AppColors.vert,
        tertiary: AppColors.rose,
        error: AppColors.rouge,
      );

  final text = GoogleFonts.poppinsTextTheme();

  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    textTheme: text,
    appBarTheme: AppBarTheme(
      backgroundColor: cs.primary,
      foregroundColor: cs.onPrimary,
      centerTitle: true,
      titleTextStyle: text.titleLarge?.copyWith(
        color: cs.onPrimary,
        fontWeight: FontWeight.w600,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.cie.withValues(alpha: 0.25),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.primary, width: 2),
      ),
      prefixIconColor: AppColors.ardoise,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.cie,
      selectedColor: AppColors.vert,
      labelStyle: text.bodyMedium?.copyWith(color: AppColors.marine),
    ),
    cardTheme: CardThemeData(
      color: cs.surface,
      elevation: 0,
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.marine,
      contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white),
    ),
  );
}

ThemeData buildDarkTheme() {
  final cs =
      ColorScheme.fromSeed(
        brightness: Brightness.dark,
        seedColor: AppColors.cyan,
      ).copyWith(
        primary: AppColors.cyan,
        secondary: AppColors.vert,
        tertiary: AppColors.jaune,
        error: AppColors.rouge,
      );

  final text = GoogleFonts.poppinsTextTheme().apply(
    bodyColor: Colors.white,
    displayColor: Colors.white,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    textTheme: text,
    appBarTheme: AppBarTheme(
      backgroundColor: cs.surface,
      foregroundColor: cs.onSurface,
      centerTitle: true,
      titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w600),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Color(0xFF151A1F),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: AppColors.cyan, width: 2),
      ),
      prefixIconColor: AppColors.cie,
    ),
    cardTheme: CardThemeData(
      color: cs.surface,
      elevation: 0,
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}

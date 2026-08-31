import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'brand_colors.dart';

ThemeData buildLightTheme() {
  final base = ThemeData.light(useMaterial3: true);
  const colors = ColorScheme.light(
    primary: AppColors.orange,
    onPrimary: Colors.white,
    secondary: AppColors.bleuPetrole,
    onSecondary: Colors.white,
    tertiary: AppColors.vert,
    onTertiary: AppColors.anthracite,
    error: AppColors.danger,
    onError: Colors.white,
    surface: AppColors.surfaceLight,
    onSurface: AppColors.anthracite,
    outline: AppColors.grisBleute,
  );
  final text = GoogleFonts.poppinsTextTheme(
    base.textTheme,
  ).apply(bodyColor: AppColors.anthracite, displayColor: AppColors.anthracite);

  return base.copyWith(
    colorScheme: colors,
    scaffoldBackgroundColor: AppColors.surfaceAltLight,
    canvasColor: AppColors.surfaceAltLight,
    textTheme: text,
    dividerColor: AppColors.grisBleute,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.anthracite,
      surfaceTintColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge?.copyWith(
        color: AppColors.anthracite,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.grisBleute),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.orange,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.grisBleute,
        disabledForegroundColor: AppColors.anthracite,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.orange,
        side: const BorderSide(color: AppColors.orange, width: 1.4),
        backgroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.orange,
        textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.grisBleute),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.grisBleute),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.orange, width: 2),
      ),
      prefixIconColor: AppColors.anthracite,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.grisBleute,
      selectedColor: AppColors.orange,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      labelStyle: text.bodyMedium?.copyWith(
        color: AppColors.anthracite,
        fontWeight: FontWeight.w600,
      ),
      secondaryLabelStyle: text.bodyMedium?.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w700,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.anthracite,
      contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white),
      actionTextColor: AppColors.orange,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.orange,
      foregroundColor: Colors.white,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.orange,
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.selected)
            ? AppColors.orange
            : Colors.white;
      }),
      checkColor: WidgetStateProperty.all(Colors.white),
      side: const BorderSide(color: AppColors.grisBleute),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.selected)
            ? AppColors.orange
            : Colors.white;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.selected)
            ? AppColors.orange.withValues(alpha: 0.35)
            : AppColors.grisBleute;
      }),
    ),
  );
}

ThemeData buildDarkTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  const colors = ColorScheme.dark(
    primary: AppColors.orange,
    onPrimary: Colors.white,
    secondary: AppColors.turquoise,
    onSecondary: AppColors.surfaceDark,
    tertiary: AppColors.vert,
    onTertiary: AppColors.surfaceDark,
    error: AppColors.danger,
    onError: Colors.white,
    surface: AppColors.surfaceDark,
    onSurface: Colors.white,
    outline: AppColors.anthracite,
  );
  final text = GoogleFonts.poppinsTextTheme(
    base.textTheme,
  ).apply(bodyColor: Colors.white, displayColor: Colors.white);

  return base.copyWith(
    colorScheme: colors,
    scaffoldBackgroundColor: AppColors.surfaceDark,
    canvasColor: AppColors.surfaceDark,
    textTheme: text,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.surfaceDarkAlt,
      foregroundColor: Colors.white,
      surfaceTintColor: AppColors.surfaceDarkAlt,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.orange,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.orange,
      foregroundColor: Colors.white,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.orange,
    ),
  );
}

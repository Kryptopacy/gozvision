import 'package:flutter/material.dart';

/// GozVision Clinic Suite — professional dark theme.
///
/// Obsidian background, bioluminescent malachite accents: the matured
/// lineage of the GozAI pro dashboards (CONTEXT.md — design_system).
class ClinicTheme {
  ClinicTheme._();

  static const Color obsidian = Color(0xFF050806);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF8A8A99);
  static const Color malachite = Color(0xFF00FF87);
  static const Color malachiteDim = Color(0xFF00C86A);
  static const Color malachiteFaint = Color(0x1A00FF87);
  static const Color surface = Color(0x12FFFFFF);
  static const Color border = Color(0x25FFFFFF);
  static const Color hazardAlert = Color(0xFFFF3B30);
  static const Color warningAmber = Color(0xFFFFD60A);

  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: obsidian,
        colorScheme: const ColorScheme.dark(
          primary: malachite,
          secondary: malachiteDim,
          surface: obsidian,
          error: hazardAlert,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: textPrimary,
        ),
        cardTheme: CardThemeData(
          color: surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: border),
          ),
          margin: EdgeInsets.zero,
        ),
        navigationRailTheme: NavigationRailThemeData(
          backgroundColor: obsidian,
          indicatorColor: malachiteFaint,
          selectedIconTheme: const IconThemeData(color: malachite),
          selectedLabelTextStyle: const TextStyle(
            color: malachite,
            fontWeight: FontWeight.w700,
          ),
          unselectedIconTheme: const IconThemeData(color: textSecondary),
          unselectedLabelTextStyle: const TextStyle(color: textSecondary),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: border),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: malachite,
            foregroundColor: Colors.black,
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w800,
          ),
          titleMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
          bodyMedium: TextStyle(color: textPrimary),
          bodySmall: TextStyle(color: textSecondary),
          labelLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w800),
        ),
      );
}

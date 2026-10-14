import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// GozVision Clinic Suite — Unified Enterprise Dark Theme.
///
/// Designed to strictly match the GozVision design system (apps/website):
/// - Obsidian backdrop: #08090C
/// - Panels & cards: #131722 with 1px border rgba(255,255,255,0.08)
/// - Primary accent: #38BDF8 (Precision Optical Sky / Azure)
/// - Secondary accent: #0284C7
/// - Typography: Sora (Display & Headings) + Plus Jakarta Sans (Body & UI)
class ClinicTheme {
  ClinicTheme._();

  // Core Brand Palette
  static const Color obsidian         = Color(0xFF08090C);
  static const Color obsidianElevated = Color(0xFF0E1117);
  static const Color cardBackground   = Color(0xFF131722);
  static const Color surface          = Color(0xFF131722);
  static const Color surfaceDark      = Color(0xFF0E1117);
  static const Color surfaceLight     = Color(0x1AFFFFFF);
  static const Color surfaceGlass     = Color(0xFF131722);

  // Typography Palette
  static const Color textPrimary      = Color(0xFFF8FAFC);
  static const Color textSecondary    = Color(0xFF94A3B8);
  static const Color textMuted        = Color(0xFF64748B);

  // Brand Optical Accent (Precision Sky Azure - NOT green)
  static const Color brandAccent      = Color(0xFF38BDF8);
  static const Color brandAccentDim   = Color(0xFF0284C7);
  static const Color brandAccentGlow  = Color(0x2E38BDF8);
  static const Color brandAccentFaint = Color(0x1438BDF8);

  // Backward-compatible aliases pointing to Brand Accent
  static const Color malachite        = brandAccent;
  static const Color opticalCyan      = brandAccent;
  static const Color malachiteDim     = brandAccentDim;
  static const Color opticalAzure     = brandAccentDim;
  static const Color malachiteFaint   = brandAccentFaint;

  // Semantic Status
  static const Color border           = Color(0x14FFFFFF); // 8% white
  static const Color stroke           = border;
  static const Color hazardAlert      = Color(0xFFEF4444);
  static const Color warningAmber     = Color(0xFFF59E0B);
  static const Color success          = Color(0xFF10B981);

  static ThemeData get theme {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: obsidian,
      colorScheme: const ColorScheme.dark(
        primary: brandAccent,
        secondary: brandAccentDim,
        surface: cardBackground,
        error: hazardAlert,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: textPrimary,
      ),
      cardTheme: CardThemeData(
        color: cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: obsidian,
        indicatorColor: brandAccentFaint,
        selectedIconTheme: IconThemeData(color: brandAccent),
        selectedLabelTextStyle: TextStyle(
          color: brandAccent,
          fontWeight: FontWeight.w700,
        ),
        unselectedIconTheme: IconThemeData(color: textSecondary),
        unselectedLabelTextStyle: TextStyle(color: textSecondary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: obsidianElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: brandAccent, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: brandAccent,
          foregroundColor: obsidian,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );

    // High-end typography: Sora for Display/Headings, Plus Jakarta Sans for Body/UI
    final displayTheme = GoogleFonts.soraTextTheme(base.textTheme);
    final bodyTheme = GoogleFonts.plusJakartaSansTextTheme(base.textTheme);

    return base.copyWith(
      textTheme: bodyTheme.copyWith(
        displayLarge: displayTheme.displayLarge?.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.0,
        ),
        displayMedium: displayTheme.displayMedium?.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.8,
        ),
        headlineLarge: displayTheme.headlineLarge?.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        headlineMedium: displayTheme.headlineMedium?.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
        titleLarge: displayTheme.titleLarge?.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        titleMedium: displayTheme.titleMedium?.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: displayTheme.titleSmall?.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: bodyTheme.bodyLarge?.copyWith(
          color: textPrimary,
          fontSize: 15,
          height: 1.5,
        ),
        bodyMedium: bodyTheme.bodyMedium?.copyWith(
          color: textSecondary,
          fontSize: 13.5,
          height: 1.45,
        ),
        bodySmall: bodyTheme.bodySmall?.copyWith(
          color: textMuted,
          fontSize: 12,
        ),
        labelLarge: bodyTheme.labelLarge?.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

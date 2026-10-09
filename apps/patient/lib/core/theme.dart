import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// GozAI Design System — Dual-Aesthetic Architecture
///
/// [Patient App]     True Matte Black + High-Visibility Yellow
///                   Brutalist-accessible. Maximum contrast. Zero ambiguity.
///                   Designed for users with macular degeneration, cataracts,
///                   and severe low vision. Thick borders. Massive touch targets.
///
/// [Pro Dashboards]  Obsidian + Bioluminescent Malachite Green
///                   Sleek, premium "Clinical Intelligence" interface.
///                   For sighted caregivers and doctors. Glassmorphism.
///                   Data-dense but breathable. D&AD aesthetic.
class GozAITheme {
  // ─────────────────────────────────────────────
  // SHARED FOUNDATION
  // ─────────────────────────────────────────────
  static const Color backgroundBlack = Color(0xFF000000);  // True matte black
  static const Color backgroundPure  = backgroundBlack;
  static const Color backgroundDark  = Color(0xFF050806);
  static const Color obsidian       = Color(0xFF050806);   // Pro dashboard bg
  static const Color textPrimary    = Color(0xFFFFFFFF);
  static const Color textSecondary  = Color(0xFF8A8A99);
  static const Color hazardAlert    = Color(0xFFFF3B30);   // Danger red

  // ─────────────────────────────────────────────
  // PATIENT APP — High-Visibility Yellow
  // ─────────────────────────────────────────────
  static const Color patientAccent  = Color(0xFFFFD600);   // Safety Yellow
  static const Color patientBorder  = Color(0xFFFFD600);
  static const Color patientSurface = Color(0xFF111100);   // Warm near-black

  // ─────────────────────────────────────────────
  // PRO DASHBOARDS & OPTICAL LENS PALETTE
  // ─────────────────────────────────────────────
  static const Color malachite      = Color(0xFF00D2FF);   // Precision Optical Cyan
  static const Color opticalCyan    = malachite;
  static const Color malachiteDim   = Color(0xFF0284C7);   // Laser Azure
  static const Color opticalAzure   = malachiteDim;
  static const Color malachiteFaint = Color(0x1A00D2FF);   // Surface tint
  static const Color proSurface     = Color(0x12FFFFFF);   // Glassmorphic panel
  static const Color proBorder      = Color(0x25FFFFFF);
  static const Color proBorderGlow  = Color(0x4000D2FF);   // Active border

  // Legacy aliases kept for backward-compat across existing widgets
  static const Color primaryBlue    = malachite;
  static const Color accentCyan     = malachite;
  static const Color electricPink   = patientAccent;
  static const Color success        = malachite;
  static const Color surfacePure    = proSurface;
  static const Color surfaceElevated = Color(0x0DFFFFFF);
  static const Color borderSubtle   = proBorder;
  static const Color borderHover    = proBorderGlow;
  static const Color listeningPulse = patientAccent;
  static const Color speakingPulse  = malachite;

  // ─────────────────────────────────────────────
  // PATIENT APP THEME
  // ─────────────────────────────────────────────
  static ThemeData get patientTheme => _buildTheme(
    bg: backgroundBlack,
    primary: patientAccent,
    secondary: textPrimary,
  );

  // ─────────────────────────────────────────────
  // PRO DASHBOARD THEME (caregiver, doctor)
  // ─────────────────────────────────────────────
  static ThemeData get proTheme => _buildTheme(
    bg: obsidian,
    primary: malachite,
    secondary: malachiteDim,
  );

  // Main entry point — for MaterialApp.theme
  static ThemeData get darkTheme => patientTheme;

  // ─────────────────────────────────────────────
  // INTERNAL BUILDER
  // ─────────────────────────────────────────────
  static ThemeData _buildTheme({
    required Color bg,
    required Color primary,
    required Color secondary,
  }) {
    final baseTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      colorScheme: ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: const Color(0x1AFFFFFF),
        error: hazardAlert,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onSurface: textPrimary,
      ),
    );

    // Typography: Syncopate for display gravitas, Outfit for body legibility
    final displayFont = GoogleFonts.syncopateTextTheme(baseTheme.textTheme);
    final bodyFont    = GoogleFonts.outfitTextTheme(baseTheme.textTheme);

    final textTheme = bodyFont.copyWith(
      displayLarge: displayFont.displayLarge?.copyWith(
        fontSize: 48,
        fontWeight: FontWeight.w900,
        color: textPrimary,
        letterSpacing: -1.5,
        height: 1.1,
      ),
      headlineMedium: displayFont.headlineMedium?.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: textPrimary,
        letterSpacing: -0.5,
      ),
      titleLarge: displayFont.titleLarge?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        letterSpacing: 1.0,
      ),
      bodyLarge: bodyFont.bodyLarge?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w300,
        color: textPrimary,
        height: 1.6,
      ),
      bodyMedium: bodyFont.bodyMedium?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w300,
        color: textSecondary,
        height: 1.5,
      ),
      labelLarge: bodyFont.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: textPrimary,
        letterSpacing: 2.0,
      ),
    );

    return baseTheme.copyWith(
      textTheme: textTheme,
      focusColor: primary.withValues(alpha: 0.4),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.black,
          elevation: 0,
          minimumSize: const Size(double.infinity, 64),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: bodyFont.labelLarge?.copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0x0DFFFFFF),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: primary.withValues(alpha: 0.2), width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: displayFont.titleLarge?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
      ),
      iconTheme: IconThemeData(color: primary, size: 24),
      dividerTheme: DividerThemeData(
        color: primary.withValues(alpha: 0.15),
        thickness: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: primary),
    );
  }
}

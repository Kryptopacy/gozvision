import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// GozVision Patient Copilot — Unified Design System
///
/// Strictly aligned with the GozVision design tokens:
/// - True obsidian background: #08090C
/// - Panels & cards: #131722 with 1px border rgba(255,255,255,0.08)
/// - Precision optical sky azure: #38BDF8 (Primary optical accent)
/// - Safety accent: #FFD600 (High-visibility tactile controls for low-vision)
/// - Typography: Sora (Display & Headings) + Plus Jakarta Sans (Body & UI)
class GozAITheme {
  // ─────────────────────────────────────────────
  // SHARED FOUNDATION
  // ─────────────────────────────────────────────
  static const Color backgroundBlack = Color(0xFF08090C);  // True Obsidian
  static const Color backgroundPure  = backgroundBlack;
  static const Color backgroundDark  = Color(0xFF08090C);
  static const Color obsidian        = Color(0xFF08090C);
  static const Color obsidianElevated = Color(0xFF0E1117);
  static const Color textPrimary     = Color(0xFFF8FAFC);
  static const Color textSecondary   = Color(0xFF94A3B8);
  static const Color textMuted       = Color(0xFF64748B);
  static const Color hazardAlert     = Color(0xFFEF4444);

  // ─────────────────────────────────────────────
  // PATIENT ACCESSIBILITY (Tactile & High-Contrast)
  // ─────────────────────────────────────────────
  static const Color patientAccent   = Color(0xFFFFD600);  // Safety Yellow
  static const Color patientBorder   = Color(0xFFFFD600);
  static const Color patientSurface  = Color(0xFF131722);

  // ─────────────────────────────────────────────
  // BRAND OPTICAL PALETTE (#38BDF8 - Precision Sky Azure)
  // ─────────────────────────────────────────────
  static const Color brandAccent     = Color(0xFF38BDF8);  // Optical Sky Azure
  static const Color brandAccentDim  = Color(0xFF0284C7);  // Laser Azure
  static const Color brandAccentGlow = Color(0x3038BDF8);
  static const Color brandAccentFaint= Color(0x1438BDF8);

  // Backward-compatible aliases mapped to unified brand tokens
  static const Color malachite       = brandAccent;
  static const Color opticalCyan     = brandAccent;
  static const Color malachiteDim    = brandAccentDim;
  static const Color opticalAzure    = brandAccentDim;
  static const Color malachiteFaint  = brandAccentFaint;
  static const Color primaryBlue     = brandAccent;
  static const Color accentCyan      = brandAccent;
  static const Color electricPink    = brandAccent;
  static const Color success         = Color(0xFF10B981);

  static const Color proSurface      = Color(0xFF131722);
  static const Color proBorder       = Color(0x14FFFFFF);
  static const Color proBorderGlow   = Color(0x4038BDF8);

  static const Color surfacePure     = proSurface;
  static const Color surfaceGlass    = proSurface;
  static const Color surfaceElevated = Color(0xFF0E1117);
  static const Color borderSubtle    = proBorder;
  static const Color borderHover     = proBorderGlow;
  static const Color listeningPulse  = patientAccent;
  static const Color speakingPulse   = brandAccent;

  // ─────────────────────────────────────────────
  // THEMES
  // ─────────────────────────────────────────────
  static ThemeData get patientTheme => _buildTheme(
    bg: backgroundBlack,
    primary: brandAccent,
    secondary: textPrimary,
  );

  static ThemeData get proTheme => _buildTheme(
    bg: obsidian,
    primary: brandAccent,
    secondary: brandAccentDim,
  );

  static ThemeData get darkTheme => patientTheme;

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
        surface: const Color(0xFF131722),
        error: hazardAlert,
        onPrimary: obsidian,
        onSecondary: obsidian,
        onSurface: textPrimary,
      ),
    );

    // Premium Typography: Sora for display & headings, Plus Jakarta Sans for body
    final displayFont = GoogleFonts.soraTextTheme(baseTheme.textTheme);
    final bodyFont    = GoogleFonts.plusJakartaSansTextTheme(baseTheme.textTheme);

    final textTheme = bodyFont.copyWith(
      displayLarge: displayFont.displayLarge?.copyWith(
        fontSize: 44,
        fontWeight: FontWeight.w800,
        color: textPrimary,
        letterSpacing: -1.0,
        height: 1.15,
      ),
      headlineMedium: displayFont.headlineMedium?.copyWith(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        letterSpacing: -0.4,
      ),
      titleLarge: displayFont.titleLarge?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        letterSpacing: -0.2,
      ),
      bodyLarge: bodyFont.bodyLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: textPrimary,
        height: 1.55,
      ),
      bodyMedium: bodyFont.bodyMedium?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: textSecondary,
        height: 1.5,
      ),
      labelLarge: bodyFont.labelLarge?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        letterSpacing: 0.3,
      ),
    );

    return baseTheme.copyWith(
      textTheme: textTheme,
      focusColor: primary.withValues(alpha: 0.4),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: obsidian,
          elevation: 0,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: bodyFont.labelLarge?.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF131722),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0x14FFFFFF), width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: displayFont.titleLarge?.copyWith(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.3,
        ),
      ),
      iconTheme: IconThemeData(color: primary, size: 24),
      dividerTheme: const DividerThemeData(
        color: Color(0x14FFFFFF),
        thickness: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: primary),
    );
  }
}

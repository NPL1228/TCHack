import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Color Palette ──────────────────────────────────────────────
  static const Color background    = Color(0xFF0A0E1A);
  static const Color surface       = Color(0xFF131929);
  static const Color surfaceCard   = Color(0xFF1A2236);
  static const Color border        = Color(0xFF252D42);
  static const Color accent        = Color(0xFF00D084); // emerald green
  static const Color accentGold    = Color(0xFFF5A623); // warm gold
  static const Color accentRed     = Color(0xFFFF4D6A);
  static const Color accentBlue    = Color(0xFF4D9FFF);
  static const Color accentPurple  = Color(0xFF9B6FFF);
  static const Color textPrimary   = Color(0xFFEFF2FB);
  static const Color textSecondary = Color(0xFF8A93A8);
  static const Color textMuted     = Color(0xFF4A5568);

  // ── Category Colors ──────────────────────────────────────────
  static const Map<String, Color> categoryColors = {
    'Food & Dining':   Color(0xFFFF7043),
    'Transport':       Color(0xFF4D9FFF),
    'Groceries':       Color(0xFF00D084),
    'Entertainment':   Color(0xFF9B6FFF),
    'Utilities':       Color(0xFFF5A623),
    'Shopping':        Color(0xFFFF4D6A),
    'Health':          Color(0xFF26C6DA),
    'Subscriptions':   Color(0xFFAB47BC),
    'Education':       Color(0xFF66BB6A),
    'Travel':          Color(0xFF26A69A),
    'Personal Care':   Color(0xFFEC407A),
    'Other':           Color(0xFF8A93A8),
  };

  static const Map<String, String> categoryIcons = {
    'Food & Dining':   '🍔',
    'Transport':       '🚗',
    'Groceries':       '🛒',
    'Entertainment':   '🎭',
    'Utilities':       '💡',
    'Shopping':        '🛍️',
    'Health':          '🏥',
    'Subscriptions':   '📺',
    'Education':       '📚',
    'Travel':          '✈️',
    'Personal Care':   '💄',
    'Other':           '📦',
  };

  static List<String> get categories => categoryColors.keys.toList();

  // ── Income Category Colors ────────────────────────────────────
  static const Map<String, Color> incomeCategoryColors = {
    'Salary':        Color(0xFF00D084),
    'Allowance':     Color(0xFF26C6DA),
    'Investment':    Color(0xFF66BB6A),
    'Freelance':     Color(0xFF4D9FFF),
    'Business':      Color(0xFFF5A623),
    'Gift':          Color(0xFFEC407A),
    'Rental':        Color(0xFFAB47BC),
    'Other Income':  Color(0xFF8A93A8),
  };

  static const Map<String, String> incomeCategoryIcons = {
    'Salary':        '💼',
    'Allowance':     '🎓',
    'Investment':    '📈',
    'Freelance':     '💻',
    'Business':      '🏢',
    'Gift':          '🎁',
    'Rental':        '🏠',
    'Other Income':  '💰',
  };

  static List<String> get incomeCategories => incomeCategoryColors.keys.toList();

  // ── Theme Data ────────────────────────────────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary:    accent,
        secondary:  accentGold,
        surface:    surface,
        error:      accentRed,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge:  GoogleFonts.inter(color: textPrimary, fontWeight: FontWeight.w700),
        displayMedium: GoogleFonts.inter(color: textPrimary, fontWeight: FontWeight.w700),
        headlineLarge: GoogleFonts.inter(color: textPrimary, fontWeight: FontWeight.w700),
        headlineMedium:GoogleFonts.inter(color: textPrimary, fontWeight: FontWeight.w600),
        titleLarge:    GoogleFonts.inter(color: textPrimary, fontWeight: FontWeight.w600),
        titleMedium:   GoogleFonts.inter(color: textPrimary, fontWeight: FontWeight.w500),
        bodyLarge:     GoogleFonts.inter(color: textPrimary),
        bodyMedium:    GoogleFonts.inter(color: textSecondary),
        bodySmall:     GoogleFonts.inter(color: textMuted),
      ),
      cardTheme: CardThemeData(
        color: surfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          color: textPrimary, fontSize: 20, fontWeight: FontWeight.w700,
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: accent,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceCard,
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
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle: const TextStyle(color: textMuted),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.black,
        elevation: 4,
      ),
      dividerTheme: const DividerThemeData(color: border, thickness: 1),
    );
  }

  // ── Gradient Helpers ─────────────────────────────────────────
  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF00D084), Color(0xFF00B36D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFF5A623), Color(0xFFE8920F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient redGradient = LinearGradient(
    colors: [Color(0xFFFF4D6A), Color(0xFFE0334F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient cardGradient = LinearGradient(
    colors: [surfaceCard, surface.withOpacity(0.8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

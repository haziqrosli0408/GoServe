import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // 🟢 CUSTOMER THEME (GREEN)
  static final ThemeData customerTheme = ThemeData(
    primaryColor: const Color(0xFFFF6B00),
    scaffoldBackgroundColor: const Color(0xFFFAF9F6),
    fontFamily: GoogleFonts.outfit().fontFamily,
    textTheme: GoogleFonts.outfitTextTheme(),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFF6B00),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFFFF6B00),
    ),
  );

  // 🟣 PROVIDER THEME (INDIGO BLUE)
  static final ThemeData providerTheme = ThemeData(
    primaryColor: const Color(0xFF4F46E5),
    scaffoldBackgroundColor: const Color(0xFFF8FAFC),
    fontFamily: GoogleFonts.outfit().fontFamily,
    textTheme: GoogleFonts.outfitTextTheme(),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF4F46E5),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF4F46E5),
    ),
  );
}

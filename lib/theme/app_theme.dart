import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // 🟢 CUSTOMER THEME (GREEN)
  static final ThemeData customerTheme = ThemeData(
    primaryColor: const Color(0xFFFF6B00),
    scaffoldBackgroundColor: const Color(0xFFFAF9F6),
    textTheme: GoogleFonts.interTextTheme(),
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

  // 🟣 PROVIDER THEME (SOFT PURPLE)
  static final ThemeData providerTheme = ThemeData(
    primaryColor: const Color(0xFF8B5CF6),
    scaffoldBackgroundColor: const Color(0xFFF9F7FF),
    textTheme: GoogleFonts.interTextTheme(),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF8B5CF6),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF8B5CF6),
    ),
  );
}

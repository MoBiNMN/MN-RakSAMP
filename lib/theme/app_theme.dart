import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const double _cardRadius = 20.0;
  static const double _inputRadius = 14.0;

  static final darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF0A0F14),
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF00E6CC),
      secondary: Color(0xFFFF2A6D),
      surface: Color(0xFF131B24),
      surfaceContainer: Color(0xFF1A242E),
      error: Color(0xFFFF5555),
      onPrimary: Colors.black,
    ),
    textTheme: GoogleFonts.outfitTextTheme(
      ThemeData.dark().textTheme,
    ).apply(bodyColor: const Color(0xFFE0E6ED), displayColor: Colors.white),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF131B24),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_cardRadius),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF1A232E),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_inputRadius),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_inputRadius),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_inputRadius),
        borderSide: const BorderSide(color: Color(0xFF00E6CC), width: 1.5),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF00E6CC),
        foregroundColor: Colors.black,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_inputRadius),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    ),
  );

  static final lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF1F4F8),
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF00B8A9),
      secondary: Color(0xFFD91B5C),
      surface: Colors.white,
      surfaceContainer: Color(0xFFF9FAFB),
      error: Color(0xFFD32F2F),
      onPrimary: Colors.white,
    ),
    textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme).apply(
      bodyColor: const Color(0xFF2D3748),
      displayColor: const Color(0xFF1A202C),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFF1F4F8),
      elevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: Color(0xFF1A202C)),
      titleTextStyle: TextStyle(
        color: Color(0xFF1A202C),
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 8,
      shadowColor: const Color(0xFFE2E8F0).withValues(alpha: 0.3),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_cardRadius),
        side: BorderSide(color: const Color(0xFFE2E8F0).withValues(alpha: 0.5)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_inputRadius),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_inputRadius),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_inputRadius),
        borderSide: const BorderSide(color: Color(0xFF00B8A9), width: 1.5),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF00B8A9),
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_inputRadius),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    ),
  );
}

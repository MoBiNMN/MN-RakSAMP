import 'package:flutter/material.dart';

/// Single app theme: dark blue, matched to the app icon's brand blue
/// (#267CB5 - #409DCE).  Near-black surfaces carry a blue undertone, accents
/// are a vivid blue with a light-blue secondary (gradients), and running
/// states stay green as a semantic colour.
class AppTheme {
  static const double _cardRadius = 20.0;
  static const double _inputRadius = 14.0;

  // Core palette
  static const Color _background = Color(0xFF070B12);
  static const Color _surface = Color(0xFF0D1520);
  static const Color _surfaceContainer = Color(0xFF131E2C);
  static const Color _primary = Color(0xFF3FA3DC);
  static const Color _secondary = Color(0xFF6FC9EE);
  static const Color _error = Color(0xFFFF5C6E);
  static const Color _onPrimary = Color(0xFF03111C);

  /// Shared "online / running" green - the status dot, the Running badge and
  /// the account screen subtitle all use this so they never drift apart.
  static const Color runningGreen = Color(0xFF2EE8A6);

  static final theme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: _background,
    colorScheme: const ColorScheme.dark(
      primary: _primary,
      secondary: _secondary,
      surface: _surface,
      surfaceContainer: _surfaceContainer,
      error: _error,
      onPrimary: _onPrimary,
    ),
    textTheme: ThemeData.dark().textTheme.apply(
      bodyColor: const Color(0xFFD5E3F2),
      displayColor: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
    ),
    cardTheme: CardThemeData(
      color: _surface,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_cardRadius),
        side: BorderSide(color: _primary.withValues(alpha: 0.08)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _surfaceContainer,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_inputRadius),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_inputRadius),
        borderSide: BorderSide(color: _primary.withValues(alpha: 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_inputRadius),
        borderSide: const BorderSide(color: _primary, width: 1.5),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _primary,
        foregroundColor: _onPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_inputRadius),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: _surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_cardRadius),
      ),
    ),
  );
}

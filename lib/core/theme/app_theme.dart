import 'package:flutter/material.dart';

class AppTheme {
  static final ThemeData lightTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  colorScheme: const ColorScheme.light(
    primary: Color(0xFFFF00FF), // Magenta
    secondary: Color(0xFFCC00CC), // Darker Magenta
    tertiary: Color(0xFFFF66FF),
    surface: Color(0xFFF5F5F5),
  ),
  scaffoldBackgroundColor: Colors.white,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.white,
    elevation: 0,
    scrolledUnderElevation: 0, // Add this
    surfaceTintColor: Colors.transparent, // Add this
  ),
  cardTheme: const CardTheme(
    color: Colors.white,
    elevation: 2,
  ),
);

static final ThemeData darkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: const ColorScheme.dark(
    primary: Color(0xFFFF00FF), // Magenta
    secondary: Color(0xFFCC00CC), // Darker Magenta
    tertiary: Color(0xFFFF66FF),
    surface: Color(0xFF2C2C2C),
  ),
  scaffoldBackgroundColor: const Color(0xFF1A1A1A),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF1A1A1A),
    elevation: 0,
    scrolledUnderElevation: 0, // Add this
    surfaceTintColor: Colors.transparent, // Add this
  ),
  cardTheme: const CardTheme(
    color: Color(0xFF2C2C2C),
    elevation: 2,
  ),
);
}
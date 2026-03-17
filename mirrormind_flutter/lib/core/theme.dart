import 'package:flutter/material.dart';

import 'constants.dart';

/// The dark theme used throughout the MirrorMind app.
final ThemeData mirrorMindTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: backgroundColor,
  colorScheme: const ColorScheme.dark(
    primary: Colors.white,
    onPrimary: Color(0xFF0A0A1A),
    surface: Color(0xFF111127),
    onSurface: Colors.white,
    secondary: Color(0xFF4A5568),
    onSecondary: Colors.white,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: true,
    titleTextStyle: TextStyle(
      color: Colors.white,
      fontSize: 18,
      fontWeight: FontWeight.w600,
    ),
    iconTheme: IconThemeData(color: Colors.white),
  ),
  textTheme: const TextTheme(
    displayLarge: TextStyle(
      color: Colors.white,
      fontSize: 32,
      fontWeight: FontWeight.bold,
    ),
    displayMedium: TextStyle(
      color: Colors.white,
      fontSize: 28,
      fontWeight: FontWeight.bold,
    ),
    displaySmall: TextStyle(
      color: Colors.white,
      fontSize: 24,
      fontWeight: FontWeight.bold,
    ),
    headlineMedium: TextStyle(
      color: Colors.white,
      fontSize: 20,
      fontWeight: FontWeight.w600,
    ),
    titleLarge: TextStyle(
      color: Colors.white,
      fontSize: 18,
      fontWeight: FontWeight.w600,
    ),
    titleMedium: TextStyle(
      color: Color(0xCCFFFFFF), // white70
      fontSize: 16,
      fontWeight: FontWeight.w500,
    ),
    bodyLarge: TextStyle(
      color: Color(0xCCFFFFFF),
      fontSize: 16,
    ),
    bodyMedium: TextStyle(
      color: Color(0xB3FFFFFF), // white60
      fontSize: 14,
    ),
    bodySmall: TextStyle(
      color: Color(0x99FFFFFF), // white50
      fontSize: 12,
    ),
    labelLarge: TextStyle(
      color: Colors.white,
      fontSize: 14,
      fontWeight: FontWeight.w600,
    ),
  ),
);

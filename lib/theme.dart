import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand greens
  static const green = Color(0xFF2D7A4F);
  static const lightGreen = Color(0xFFE8F5E9);
  static const background = Color(0xFFF4F6F4);

  // Hero gradient stop colours (used in home_screen.dart)
  static const heroGreenStart    = Color(0xFF1E5C38);
  static const heroGreenEnd      = Color(0xFF3A9160);
  static const heroBlueEnd       = Color(0xFF1A2535);
  static const heroRedEnd        = Color(0xFF2D1A0A);
  // Dark-mode hero: deep navy palette
  static const heroDarkBlueStart = Color(0xFF0A1628);  // midnight navy
  static const heroDarkBlueEnd   = Color(0xFF1B3A6B);  // deep ocean
  static const heroDarkRainyEnd  = Color(0xFF0D1F2D);  // stormy slate

  static ThemeData light() => ThemeData(
    colorSchemeSeed: green,
    useMaterial3: true,
    scaffoldBackgroundColor: background,
    textTheme: GoogleFonts.interTextTheme(),
  );

  static const darkColorScheme = ColorScheme.dark(
    background:           Color(0xFF1A1A2E),
    surface:              Color(0xFF252540),
    surfaceVariant:       Color(0xFF1E2D20),
    primary:              Color(0xFF2D7A4F),
    onPrimary:            Colors.white,
    primaryContainer:     Color(0xFF1E2D20),
    onPrimaryContainer:   Color(0xFF81C784),
    onSurface:            Color(0xFFE8E8FF),
    onSurfaceVariant:     Color(0xFF9090C0),
    outline:              Color(0xFF252540),
  );

  static ThemeData dark() => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xFF1A1A2E),
    textTheme: GoogleFonts.interTextTheme(
      ThemeData(brightness: Brightness.dark).textTheme,
    ),
    colorScheme: darkColorScheme,
  );

  static Color severityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'healthy': return const Color(0xFF4CAF50);
      case 'low':     return const Color(0xFFFFEB3B);
      case 'medium':  return const Color(0xFFFF9800);
      case 'high':    return const Color(0xFFF44336);
      default:        return const Color(0xFF9E9E9E);
    }
  }

  static IconData severityIcon(String severity) {
    switch (severity.toLowerCase()) {
      case 'healthy': return Icons.check_circle;
      case 'low':     return Icons.info;
      case 'medium':  return Icons.warning;
      case 'high':    return Icons.dangerous;
      default:        return Icons.help;
    }
  }
}

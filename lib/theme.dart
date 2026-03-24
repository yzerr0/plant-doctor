import 'package:flutter/material.dart';

class AppTheme {
  static const green = Color(0xFF2E7D32);
  static const lightGreen = Color(0xFFE8F5E9);
  static const background = Color(0xFFF1F8F1);

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

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_doctor/theme.dart';

void main() {
  group('AppTheme.darkColorScheme — Deep Space palette', () {
    test('surface is #252540', () {
      expect(AppTheme.darkColorScheme.surface, const Color(0xFF252540));
    });

    test('primaryContainer is #1e2d20', () {
      expect(AppTheme.darkColorScheme.primaryContainer,
          const Color(0xFF1E2D20));
    });

    test('onSurface is #e8e8ff', () {
      expect(AppTheme.darkColorScheme.onSurface, const Color(0xFFE8E8FF));
    });

    test('primary is #2d7a4f', () {
      expect(AppTheme.darkColorScheme.primary, const Color(0xFF2D7A4F));
    });
  });

  test('AppTheme.green is #2d7a4f', () {
    expect(AppTheme.green, const Color(0xFF2D7A4F));
  });

  test('hero gradient constants are present', () {
    expect(AppTheme.heroGreenStart, const Color(0xFF1E5C38));
    expect(AppTheme.heroGreenEnd, const Color(0xFF3A9160));
    expect(AppTheme.heroBlueEnd, const Color(0xFF1A2535));
    expect(AppTheme.heroRedEnd, const Color(0xFF2D1A0A));
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_doctor/screens/plant_profile_screen.dart';

void main() {
  testWidgets('SpeciesHistoryScreen renders without error', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: SpeciesHistoryScreen(
            scientificName: 'Monstera deliciosa',
            commonName: 'Monstera',
          ),
        ),
      ),
    );
    expect(find.byType(SpeciesHistoryScreen), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_doctor/screens/plant_profiles_list_screen.dart';

void main() {
  testWidgets('MyPlantsScreen renders without error', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: MyPlantsScreen()),
      ),
    );
    expect(find.byType(MyPlantsScreen), findsOneWidget);
  });
}

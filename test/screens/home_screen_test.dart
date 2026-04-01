import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_doctor/screens/home_screen.dart';

void main() {
  testWidgets('HomeScreen renders without error', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: HomeScreen()),
      ),
    );
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('HomeScreen shows greeting in hero', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: HomeScreen()),
      ),
    );
    // Hero shows time-based greeting (no app title bar — title was removed)
    expect(
      find.textContaining(RegExp(r'Good (morning|afternoon|evening)')),
      findsOneWidget,
    );
  });

  testWidgets('HomeScreen shows bottom navigation bar', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: HomeScreen()),
      ),
    );
    expect(find.byType(BottomAppBar), findsOneWidget);
  });

  testWidgets('HomeScreen shows scan FAB', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: HomeScreen()),
      ),
    );
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
}

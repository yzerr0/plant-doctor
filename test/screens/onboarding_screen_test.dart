import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_doctor/screens/onboarding_screen.dart';

void main() {
  testWidgets('shows PlantDoctor title and Get Started on page 1', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: OnboardingScreen(onComplete: () async {})),
    );
    expect(find.text('PlantDoctor'), findsOneWidget);
    expect(find.text('Get Started →'), findsOneWidget);
    expect(find.text('Skip for now'), findsNothing);
  });

  testWidgets('Get Started advances to page 2 which has skip', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: OnboardingScreen(onComplete: () async {})),
    );
    await tester.tap(find.text('Get Started →'));
    await tester.pumpAndSettle();
    expect(find.text('Weather-Smart Care'), findsOneWidget);
    expect(find.text('Skip for now'), findsOneWidget);
  });

  testWidgets('Skip on page 2 advances to page 3', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: OnboardingScreen(onComplete: () async {})),
    );
    await tester.tap(find.text('Get Started →'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();
    expect(find.text('Never Miss a Watering'), findsOneWidget);
  });

  testWidgets('Skip on page 3 calls onComplete', (tester) async {
    bool completed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScreen(onComplete: () async { completed = true; }),
      ),
    );
    // advance to page 2
    await tester.tap(find.text('Get Started →'));
    await tester.pumpAndSettle();
    // advance to page 3
    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();
    // skip on page 3
    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();
    expect(completed, isTrue);
  });
}

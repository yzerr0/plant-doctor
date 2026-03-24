import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_doctor/widgets/severity_badge.dart';

void main() {
  testWidgets('SeverityBadge shows correct label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SeverityBadge(severity: 'high'))),
    );
    expect(find.text('HIGH'), findsOneWidget);
  });

  testWidgets('SeverityBadge renders for healthy', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SeverityBadge(severity: 'healthy'))),
    );
    expect(find.text('HEALTHY'), findsOneWidget);
  });
}

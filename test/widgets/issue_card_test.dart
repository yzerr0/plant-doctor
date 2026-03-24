import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_doctor/models/diagnosis_model.dart';
import 'package:plant_doctor/widgets/issue_card.dart';

void main() {
  final testIssue = PlantIssue(
    name: 'Root Rot',
    severity: 'high',
    cause: 'Overwatering',
    symptoms: ['yellowing', 'mushy stem'],
    treatment: ['Remove rot', 'Repot'],
    preventionTips: ['Water less'],
  );

  testWidgets('IssueCard shows issue name', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: IssueCard(issue: testIssue))),
    );
    expect(find.text('Root Rot'), findsOneWidget);
  });

  testWidgets('IssueCard expands to show cause', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: IssueCard(issue: testIssue))),
    );
    await tester.tap(find.text('Root Rot'));
    await tester.pumpAndSettle();
    expect(find.text('Overwatering'), findsOneWidget);
  });
}

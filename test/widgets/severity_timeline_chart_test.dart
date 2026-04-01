import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_doctor/models/diagnosis_model.dart';
import 'package:plant_doctor/widgets/severity_timeline_chart.dart';

const _emptySpeciesInfo = SpeciesInfo(
  origin: '',
  lifespan: '',
  difficulty: '',
  light: '',
  water: '',
  humidity: '',
  temperature: '',
  toxicity: '',
  funFact: '',
);

DiagnosisResult _fakeResult(String id, String severity) {
  return DiagnosisResult(
    id: id,
    imageUrl: 'https://example.com/$id.jpg',
    plantSpecies: 'Monstera',
    overallSeverity: severity,
    summary: 'Test summary',
    identificationCertainty: 'certain',
    identificationLevel: 'species',
    followUpIn: 7,
    speciesInfo: _emptySpeciesInfo,
    issues: [],
    createdAt: DateTime(2025, 1, int.parse(id)),
  );
}

void main() {
  testWidgets('renders without error with empty list', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SeverityTimelineChart(diagnoses: []))),
    );
    expect(find.byType(SeverityTimelineChart), findsOneWidget);
  });

  testWidgets('renders without error with multiple diagnoses', (tester) async {
    final diagnoses = [
      _fakeResult('1', 'healthy'),
      _fakeResult('2', 'low'),
      _fakeResult('3', 'medium'),
      _fakeResult('4', 'high'),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SeverityTimelineChart(diagnoses: diagnoses),
        ),
      ),
    );
    expect(find.byType(SeverityTimelineChart), findsOneWidget);
  });

  testWidgets('shows placeholder when fewer than 2 diagnoses', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SeverityTimelineChart(
            diagnoses: [_fakeResult('1', 'healthy')],
          ),
        ),
      ),
    );
    expect(find.text('Scan more plants to see your health trend'), findsOneWidget);
  });
}

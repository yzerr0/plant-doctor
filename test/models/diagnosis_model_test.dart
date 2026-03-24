import 'package:flutter_test/flutter_test.dart';
import 'package:plant_doctor/models/diagnosis_model.dart';

void main() {
  group('PlantIssue.fromJson', () {
    test('parses all fields correctly', () {
      final json = {
        'name': 'Spider Mites',
        'severity': 'Medium',
        'cause': 'Low humidity',
        'symptoms': ['webbing', 'yellowing'],
        'treatment': ['Step 1', 'Step 2'],
        'preventionTips': ['Tip 1'],
      };
      final issue = PlantIssue.fromJson(json);
      expect(issue.name, 'Spider Mites');
      expect(issue.severity, 'medium'); // normalized to lowercase
      expect(issue.cause, 'Low humidity');
      expect(issue.symptoms, ['webbing', 'yellowing']);
      expect(issue.treatment, ['Step 1', 'Step 2']);
      expect(issue.preventionTips, ['Tip 1']);
    });

    test('handles missing fields with defaults', () {
      final issue = PlantIssue.fromJson({});
      expect(issue.name, '');
      expect(issue.severity, 'low');
      expect(issue.symptoms, isEmpty);
    });
  });

  group('DiagnosisResult.fromJson', () {
    final validJson = {
      'plantSpecies': 'Monstera deliciosa',
      'confidence': 0.91,
      'overallSeverity': 'Medium',
      'summary': 'Looks fine.',
      'followUpIn': 7,
      'speciesInfo': {
        'origin': 'Mexico',
        'lifespan': 'Perennial',
        'difficulty': 'Easy',
        'light': 'Indirect',
        'water': 'Weekly',
        'humidity': 'High',
        'temperature': '65-85°F',
        'toxicity': 'Toxic',
        'funFact': 'Makes holes to survive storms.',
      },
      'issues': [],
    };

    test('parses all top-level fields', () {
      final result = DiagnosisResult.fromJson('id1', 'http://img.url', validJson);
      expect(result.id, 'id1');
      expect(result.imageUrl, 'http://img.url');
      expect(result.plantSpecies, 'Monstera deliciosa');
      expect(result.confidence, 0.91);
      expect(result.overallSeverity, 'medium'); // normalized
      expect(result.followUpIn, 7);
      expect(result.issues, isEmpty);
    });

    test('normalizes overallSeverity to lowercase', () {
      final json = Map<String, dynamic>.from(validJson)..['overallSeverity'] = 'HIGH';
      final result = DiagnosisResult.fromJson('id2', 'url', json);
      expect(result.overallSeverity, 'high');
    });
  });

  group('DiagnosisResult.fromFirestore', () {
    test('parses createdAt from stored ISO string — not DateTime.now()', () {
      final stored = {
        'plantSpecies': 'Pothos',
        'confidence': 0.85,
        'overallSeverity': 'healthy',
        'summary': 'Looks great.',
        'followUpIn': 14,
        'imageUrl': 'http://img.url',
        'createdAt': '2025-01-15T10:30:00.000',
        'speciesInfo': {
          'origin': '', 'lifespan': '', 'difficulty': '',
          'light': '', 'water': '', 'humidity': '',
          'temperature': '', 'toxicity': '', 'funFact': '',
        },
        'issues': [],
      };
      final result = DiagnosisResult.fromFirestore('id3', stored);
      expect(result.createdAt.year, 2025);
      expect(result.createdAt.month, 1);
      expect(result.createdAt.day, 15);
    });

    test('falls back to DateTime.now() if createdAt is missing', () {
      final stored = {
        'plantSpecies': 'Pothos',
        'confidence': 0.5,
        'overallSeverity': 'healthy',
        'summary': '',
        'followUpIn': 7,
        'imageUrl': '',
        'speciesInfo': {
          'origin': '', 'lifespan': '', 'difficulty': '',
          'light': '', 'water': '', 'humidity': '',
          'temperature': '', 'toxicity': '', 'funFact': '',
        },
        'issues': [],
      };
      final before = DateTime.now();
      final result = DiagnosisResult.fromFirestore('id4', stored);
      final after = DateTime.now();
      expect(result.createdAt.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
      expect(result.createdAt.isBefore(after.add(const Duration(seconds: 1))), isTrue);
    });
  });
}

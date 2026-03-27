import 'package:flutter_test/flutter_test.dart';
import 'package:plant_doctor/models/diagnosis_model.dart';

void main() {
  group('WeatherSnapshot', () {
    test('fromJson parses all fields correctly', () {
      final json = {
        'tempC': 22.5,
        'humidityPct': 65,
        'uvIndex': 3,
        'rainChancePct': 20,
        'condition': 'sunny',
        'windKph': 12.6,
      };
      final snap = WeatherSnapshot.fromJson(json);
      expect(snap.tempC, 22.5);
      expect(snap.humidityPct, 65);
      expect(snap.uvIndex, 3);
      expect(snap.rainChancePct, 20);
      expect(snap.condition, 'sunny');
      expect(snap.windKph, 12.6);
    });

    test('fromJson uses safe defaults for missing optional fields', () {
      final snap = WeatherSnapshot.fromJson({'tempC': 20.0, 'humidityPct': 50});
      expect(snap.uvIndex, 0);
      expect(snap.rainChancePct, 0);
      expect(snap.condition, 'cloudy');
      expect(snap.windKph, 0.0);
    });

    test('fromJson uses safe defaults when tempC and humidityPct are missing', () {
      final snap = WeatherSnapshot.fromJson({});
      expect(snap.tempC, 0.0);
      expect(snap.humidityPct, 0);
    });

    test('toJson round-trips all 6 fields correctly', () {
      const snap = WeatherSnapshot(
        tempC: 18.0, humidityPct: 70, uvIndex: 5,
        rainChancePct: 40, condition: 'cloudy', windKph: 8.0,
      );
      final json = snap.toJson();
      final restored = WeatherSnapshot.fromJson(json);
      expect(restored.tempC, 18.0);
      expect(restored.humidityPct, 70);
      expect(restored.uvIndex, 5);
      expect(restored.rainChancePct, 40);
      expect(restored.condition, 'cloudy');
      expect(restored.windKph, 8.0);
    });
  });

  group('DiagnosisResult.fromFirestore with usHardinessZone', () {
    test('parses usHardinessZone when present', () {
      final json = {
        'imageUrl': 'https://example.com/img.jpg',
        'plantSpecies': 'Monstera deliciosa',
        'overallSeverity': 'healthy',
        'summary': 'Looks good',
        'identificationCertainty': 'certain',
        'identificationLevel': 'species',
        'followUpIn': 14,
        'speciesInfo': {
          'origin': 'Mexico', 'lifespan': 'Perennial', 'difficulty': 'Easy',
          'light': 'Indirect', 'water': 'Weekly', 'humidity': 'High',
          'temperature': '65-85°F', 'toxicity': 'Toxic to cats',
          'funFact': 'Leaves develop holes as they mature.',
        },
        'issues': [],
        'createdAt': '2026-03-27T10:00:00.000',
        'usHardinessZone': '9b',
      };
      final result = DiagnosisResult.fromFirestore('test-id', json);
      expect(result.usHardinessZone, '9b');
    });

    test('usHardinessZone is null when absent', () {
      final json = {
        'imageUrl': 'https://example.com/img.jpg',
        'plantSpecies': 'Monstera deliciosa',
        'overallSeverity': 'healthy',
        'summary': 'Looks good',
        'identificationCertainty': 'certain',
        'identificationLevel': 'species',
        'followUpIn': 14,
        'speciesInfo': {
          'origin': 'Mexico', 'lifespan': 'Perennial', 'difficulty': 'Easy',
          'light': 'Indirect', 'water': 'Weekly', 'humidity': 'High',
          'temperature': '65-85°F', 'toxicity': 'Safe',
          'funFact': 'Fact.',
        },
        'issues': [],
        'createdAt': '2026-03-27T10:00:00.000',
      };
      final result = DiagnosisResult.fromFirestore('test-id', json);
      expect(result.usHardinessZone, isNull);
    });
  });
}

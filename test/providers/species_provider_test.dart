import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_doctor/models/watering_prefs.dart';
import 'package:plant_doctor/providers/species_provider.dart';

void main() {
  test('speciesGroupsProvider is a Provider', () {
    expect(speciesGroupsProvider, isA<Provider<List<SpeciesGroup>>>());
  });

  test('wateringPrefsProvider is a StreamProvider family', () {
    expect(wateringPrefsProvider('Monstera deliciosa'), isNotNull);
  });

  test('SpeciesGroup holds scientificName, commonName, diagnoses', () {
    const group = SpeciesGroup(
      scientificName: 'Monstera deliciosa',
      commonName: 'Monstera',
      diagnoses: [],
    );
    expect(group.scientificName, 'Monstera deliciosa');
    expect(group.commonName, 'Monstera');
    expect(group.diagnoses, isEmpty);
  });

  group('daysUntilWatering', () {
    test('returns negative when overdue', () {
      final last = DateTime.now().subtract(const Duration(days: 10));
      final prefs = WateringPrefs(intervalDays: 7, lastWateredAt: last);
      final days = daysUntilWatering(prefs);
      expect(days, isNegative);
    });

    test('returns 0 when due today', () {
      final last = DateTime.now().subtract(const Duration(days: 7));
      final prefs = WateringPrefs(intervalDays: 7, lastWateredAt: last);
      final days = daysUntilWatering(prefs);
      expect(days, 0);
    });

    test('returns positive when upcoming', () {
      final last = DateTime.now().subtract(const Duration(days: 3));
      final prefs = WateringPrefs(intervalDays: 7, lastWateredAt: last);
      final days = daysUntilWatering(prefs);
      expect(days, 4);
    });

    test('returns null when lastWateredAt is null', () {
      final prefs = WateringPrefs(intervalDays: 7);
      expect(daysUntilWatering(prefs), isNull);
    });
  });

  group('WateringBannerKind priority', () {
    test('overdue has lower index than dueToday', () {
      expect(WateringBannerKind.overdue.index,
          lessThan(WateringBannerKind.dueToday.index));
    });

    test('dueToday has lower index than dueSoon', () {
      expect(WateringBannerKind.dueToday.index,
          lessThan(WateringBannerKind.dueSoon.index));
    });
  });
}

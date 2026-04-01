import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/diagnosis_model.dart';
import '../models/watering_prefs.dart';
import '../services/watering_service.dart';
import 'auth_provider.dart';
import 'diagnoses_provider.dart';
import 'weather_provider.dart';

class SpeciesGroup {
  final String scientificName; // grouping key, e.g. "Monstera deliciosa"
  final String commonName; // display name, e.g. "Monstera"
  final List<DiagnosisResult> diagnoses; // sorted oldest→newest

  const SpeciesGroup({
    required this.scientificName,
    required this.commonName,
    required this.diagnoses,
  });
}

String _extractScientificName(String plantSpecies) {
  final parts = plantSpecies.split('(');
  return parts.length > 1
      ? parts[1].replaceAll(')', '').trim()
      : plantSpecies.trim();
}

String _extractCommonName(String plantSpecies) =>
    plantSpecies.split('(')[0].trim();

/// Derives species groups from the diagnoses stream — no Firestore writes.
final speciesGroupsProvider = Provider<List<SpeciesGroup>>((ref) {
  final diagnoses = ref.watch(diagnosesProvider).valueOrNull ?? [];

  final Map<String, List<DiagnosisResult>> groups = {};
  for (final d in diagnoses) {
    final key = _extractScientificName(d.plantSpecies);
    groups.putIfAbsent(key, () => []).add(d);
  }

  final result = groups.entries.map((e) {
    final sorted = List<DiagnosisResult>.from(e.value)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return SpeciesGroup(
      scientificName: e.key,
      commonName: _extractCommonName(sorted.last.plantSpecies),
      diagnoses: sorted,
    );
  }).toList()
    ..sort((a, b) =>
        b.diagnoses.last.createdAt.compareTo(a.diagnoses.last.createdAt));

  return result;
});

/// Per-species watering preferences streamed from Firestore.
final wateringPrefsProvider =
    StreamProvider.family<WateringPrefs?, String>((ref, scientificName) {
  final asyncUser = ref.watch(authStateProvider);
  return asyncUser.when(
    data: (user) => user != null
        ? WateringService.prefsStream(user.uid, scientificName)
        : Stream.value(null),
    loading: () => Stream.value(null),
    error: (_, __) => Stream.value(null),
  );
});

// ─── Watering banner ─────────────────────────────────────────────────────────

enum WateringBannerKind {
  overdue,   // 0 — most urgent
  dueToday,  // 1
  dueSoon,   // 2
  rainSkip,  // 3
  allGood,   // 4
  frost,     // 5 — handled by early return in urgentWateringProvider, never ranked via index
}

class WateringBannerData {
  final WateringBannerKind kind;
  final String plantName;
  final String scientificName;
  final int daysUntil; // negative = overdue, 0 = today, positive = future

  const WateringBannerData({
    required this.kind,
    required this.plantName,
    required this.scientificName,
    required this.daysUntil,
  });
}

/// Returns days until next watering (negative if overdue, null if never set).
int? daysUntilWatering(WateringPrefs prefs) {
  if (prefs.lastWateredAt == null) return null;
  final nextWater =
      prefs.lastWateredAt!.add(Duration(days: prefs.intervalDays));
  final today = DateTime.now();
  final todayMidnight = DateTime(today.year, today.month, today.day);
  final nextMidnight = DateTime(
      nextWater.year, nextWater.month, nextWater.day);
  return nextMidnight.difference(todayMidnight).inDays;
}

/// The single most urgent watering banner across all tracked species.
/// Returns null if no species have `lastWateredAt` set and no frost.
final urgentWateringProvider = Provider<WateringBannerData?>((ref) {
  final groups = ref.watch(speciesGroupsProvider);
  final weather = ref.watch(weatherProvider).valueOrNull;

  // Frost check: live temperature <= 2°C
  if (weather != null && weather.current.tempC <= 2.0) {
    return const WateringBannerData(
      kind: WateringBannerKind.frost,
      plantName: '',
      scientificName: '',
      daysUntil: 0,
    );
  }

  // Rain skip: getWeather builds forecast starting from tomorrow (index 0 = tomorrow).
  // Overdue plants still show as overdue even in rain — rain skip only applies to
  // plants that are due today or due soon (see classification block below).
  final hasRainForecast = weather != null &&
      weather.forecast.isNotEmpty &&
      weather.forecast.first.rainChancePct > 50;

  WateringBannerData? mostUrgent;

  for (final group in groups) {
    final prefs =
        ref.watch(wateringPrefsProvider(group.scientificName)).valueOrNull;
    if (prefs == null) continue;

    final days = daysUntilWatering(prefs);
    if (days == null) continue; // never recorded a watering

    WateringBannerKind kind;
    if (days < 0) {
      kind = WateringBannerKind.overdue;
    } else if (days == 0) {
      kind = hasRainForecast ? WateringBannerKind.rainSkip : WateringBannerKind.dueToday;
    } else if (days <= 3) {
      kind = hasRainForecast ? WateringBannerKind.rainSkip : WateringBannerKind.dueSoon;
    } else {
      kind = WateringBannerKind.allGood;
    }

    final candidate = WateringBannerData(
      kind: kind,
      plantName: group.commonName,
      scientificName: group.scientificName,
      daysUntil: days,
    );

    if (mostUrgent == null ||
        candidate.kind.index < mostUrgent.kind.index) {
      mostUrgent = candidate;
    }
  }

  return mostUrgent;
});

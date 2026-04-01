import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/diagnosis_model.dart';
import '../models/watering_prefs.dart';
import '../providers/auth_provider.dart';
import '../providers/species_provider.dart';
import '../services/reminder_service.dart';
import '../services/watering_service.dart';
import '../widgets/severity_badge.dart';
import '../widgets/severity_timeline_chart.dart';
import 'result_screen.dart';

class SpeciesHistoryScreen extends ConsumerWidget {
  final String scientificName;
  final String commonName;

  const SpeciesHistoryScreen({
    super.key,
    required this.scientificName,
    required this.commonName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(speciesGroupsProvider);
    final group = groups.firstWhere(
      (g) => g.scientificName == scientificName,
      orElse: () => SpeciesGroup(
        scientificName: scientificName,
        commonName: commonName,
        diagnoses: const [],
      ),
    );

    final prefs = ref.watch(wateringPrefsProvider(scientificName)).valueOrNull;
    final user = ref.watch(authStateProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(commonName)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader('Health Timeline'),
          SizedBox(
            height: 160,
            child: SeverityTimelineChart(diagnoses: group.diagnoses),
          ),
          const SizedBox(height: 24),

          _SectionHeader('Watering'),
          _WateringCard(
            scientificName: scientificName,
            commonName: commonName,
            prefs: prefs,
            uid: user?.uid ?? '',
          ),
          const SizedBox(height: 24),

          _SectionHeader('Scan History (${group.diagnoses.length})'),
          if (group.diagnoses.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child:
                  Text('No scans yet.', style: TextStyle(color: Colors.grey)),
            )
          else
            ...group.diagnoses.reversed
                .map((d) => _DiagnosisTile(diagnosis: d)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.bold)),
    );
  }
}

class _WateringCard extends StatelessWidget {
  final String scientificName;
  final String commonName;
  final WateringPrefs? prefs;
  final String uid;

  const _WateringCard({
    required this.scientificName,
    required this.commonName,
    required this.prefs,
    required this.uid,
  });

  void _requireAuth(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sign in to use watering reminders')),
    );
  }

  Future<void> _confirmMarkWatered(BuildContext context, int interval) async {
    if (uid.isEmpty) {
      _requireAuth(context);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as watered?'),
        content: Text(
            'Next reminder in $interval day${interval == 1 ? '' : 's'}.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirm')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final now = DateTime.now();
    await WateringService.markWatered(uid, scientificName);
    await ReminderService.scheduleWatering(
      scientificName: scientificName,
      plantName: commonName,
      intervalDays: interval,
      lastWateredAt: now,
    );
  }

  Future<void> _pickInterval(BuildContext context, int current) async {
    if (uid.isEmpty) {
      _requireAuth(context);
      return;
    }
    const options = [1, 2, 3, 5, 7, 10, 14, 21, 30];
    final selected = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Watering interval'),
        children: options
            .map((d) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, d),
                  child: Text(
                    'Every $d day${d == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontWeight:
                          d == current ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ))
            .toList(),
      ),
    );
    if (selected != null && selected != current && context.mounted) {
      await WateringService.updateInterval(uid, scientificName, selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final last = prefs?.lastWateredAt;
    final interval = prefs?.intervalDays ?? 7;

    String nextLabel;
    if (last == null) {
      nextLabel = 'Never watered';
    } else {
      final next = last.add(Duration(days: interval));
      final diff = next.difference(DateTime.now()).inDays;
      nextLabel = diff <= 0
          ? 'Water today!'
          : 'Next in $diff day${diff == 1 ? '' : 's'}';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.water_drop_outlined, color: Colors.blue),
                const SizedBox(width: 12),
                Expanded(child: Text(nextLabel)),
                TextButton(
                  onPressed: () => _confirmMarkWatered(context, interval),
                  child: const Text('Mark Watered'),
                ),
              ],
            ),
            Row(
              children: [
                const SizedBox(width: 36),
                Text(
                  'Every $interval day${interval == 1 ? '' : 's'}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => _pickInterval(context, interval),
                  child: const Text(
                    'Change',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DiagnosisTile extends StatelessWidget {
  final DiagnosisResult diagnosis;
  const _DiagnosisTile({required this.diagnosis});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.eco_outlined),
      title: Text(diagnosis.plantSpecies),
      subtitle: Text(
        '${diagnosis.createdAt.day}/${diagnosis.createdAt.month}/${diagnosis.createdAt.year}',
      ),
      trailing: SeverityBadge(severity: diagnosis.overallSeverity),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ResultScreen(diagnosis: diagnosis)),
      ),
    );
  }
}

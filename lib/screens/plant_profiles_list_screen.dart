import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/species_provider.dart';
import '../widgets/severity_badge.dart';
import 'plant_profile_screen.dart';

class MyPlantsScreen extends ConsumerWidget {
  const MyPlantsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(speciesGroupsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Plants')),
      body: groups.isEmpty
          ? const Center(
              child: Text(
                'Scan your first plant to start tracking',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: groups.length,
              itemBuilder: (context, i) => _SpeciesTile(group: groups[i]),
            ),
    );
  }
}

class _SpeciesTile extends StatelessWidget {
  final SpeciesGroup group;
  const _SpeciesTile({required this.group});

  @override
  Widget build(BuildContext context) {
    final lastScan = group.diagnoses.last;
    final scanCount = group.diagnoses.length;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Text(
          group.commonName.isNotEmpty ? group.commonName[0].toUpperCase() : '?',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(group.commonName),
      subtitle: Text(
          '$scanCount scan${scanCount == 1 ? '' : 's'} · ${group.scientificName}'),
      trailing: SeverityBadge(severity: lastScan.overallSeverity),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SpeciesHistoryScreen(
            scientificName: group.scientificName,
            commonName: group.commonName,
          ),
        ),
      ),
    );
  }
}

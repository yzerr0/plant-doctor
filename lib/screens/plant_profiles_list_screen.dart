import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/species_provider.dart';
import '../theme.dart';
import '../widgets/severity_badge.dart';
import 'plant_profile_screen.dart';

class MyPlantsScreen extends ConsumerWidget {
  const MyPlantsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(speciesGroupsProvider);
    final isWide = MediaQuery.of(context).size.shortestSide >= 600;

    return Scaffold(
      appBar: AppBar(title: const Text('My Plants')),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isWide ? 680 : double.infinity),
          child: groups.isEmpty
              ? const Center(
                  child: Text(
                    'Scan your first plant to start tracking',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : isWide
                  ? GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 2.8,
                      ),
                      itemCount: groups.length,
                      itemBuilder: (context, i) =>
                          _SpeciesTile(group: groups[i]),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      itemCount: groups.length,
                      itemBuilder: (context, i) =>
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _SpeciesTile(group: groups[i]),
                          ),
                    ),
        ),
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
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(12),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SpeciesHistoryScreen(
              scientificName: group.scientificName,
              commonName: group.commonName,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: lastScan.imageUrl,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: AppTheme.lightGreen,
                    child: const Icon(Icons.local_florist,
                        color: AppTheme.green, size: 24),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: AppTheme.lightGreen,
                    child: const Icon(Icons.local_florist,
                        color: AppTheme.green, size: 24),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      group.commonName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$scanCount scan${scanCount == 1 ? '' : 's'} · ${group.scientificName}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SeverityBadge(severity: lastScan.overallSeverity),
            ],
          ),
        ),
      ),
    );
  }
}

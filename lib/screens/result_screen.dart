import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/diagnosis_model.dart';
import '../providers/auth_provider.dart';
import '../theme.dart';
import '../widgets/issue_card.dart';
import 'auth_screen.dart';

class ResultScreen extends ConsumerWidget {
  final DiagnosisResult diagnosis;
  const ResultScreen({super.key, required this.diagnosis});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: AppTheme.green,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.content_copy_outlined),
                tooltip: 'Copy summary',
                onPressed: () {
                  Clipboard.setData(ClipboardData(
                    text: '${diagnosis.plantSpecies}\n\n${diagnosis.summary}',
                  ));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Copied to clipboard'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: CachedNetworkImage(
                imageUrl: diagnosis.imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(color: AppTheme.lightGreen,
                  child: const Center(child: Icon(Icons.local_florist, size: 60, color: AppTheme.green))),
                errorWidget: (_, _, _) => Container(color: AppTheme.lightGreen,
                  child: const Center(child: Icon(Icons.local_florist, size: 60, color: AppTheme.green))),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _signInBanner(context, ref),
                _speciesHeader(),
                _severityBanner(),
                _summary(),
                _careGrid(context),
                _funFact(),
                _issuesSection(),
                _followUp(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _signInBanner(BuildContext context, WidgetRef ref) {
    final isAnonymous =
        ref.watch(authStateProvider).valueOrNull?.isAnonymous ?? true;
    if (!isAnonymous) return const SizedBox.shrink();
    return Container(
      color: AppTheme.lightGreen,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Sign in to save your history across devices',
              style: TextStyle(fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AuthScreen()),
            ),
            child: const Text('Sign In',
                style: TextStyle(
                    color: AppTheme.green, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _speciesHeader() {
    final parts = diagnosis.plantSpecies.split('(');
    final commonName = parts[0].trim();
    final scientific = parts.length > 1 ? parts[1].replaceAll(')', '').trim() : '';
    final (chipLabel, chipColor, chipText) = switch (diagnosis.identificationCertainty) {
      'certain'   => ('✓ Certain',   AppTheme.green,           Colors.white),
      'likely'    => ('~ Likely',    const Color(0xFFF59E0B),  Colors.white),
      _           => ('? Uncertain', const Color(0xFF9E9E9E),  Colors.white),
    };

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(commonName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                if (scientific.isNotEmpty)
                  Text(scientific, style: const TextStyle(fontSize: 13, color: Colors.grey, fontStyle: FontStyle.italic)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: chipColor,
              borderRadius: BorderRadius.circular(20)),
            child: Text(chipLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: chipText)),
          ),
        ],
      ),
    );
  }

  Widget _severityBanner() {
    final color = AppTheme.severityColor(diagnosis.overallSeverity);
    final icon = AppTheme.severityIcon(diagnosis.overallSeverity);
    final label = diagnosis.overallSeverity.toUpperCase();
    return Container(
      width: double.infinity,
      color: color,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text(label,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
          if (diagnosis.issues.isNotEmpty) ...[
            const Spacer(),
            Text('${diagnosis.issues.length} issue${diagnosis.issues.length > 1 ? 's' : ''} detected',
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ],
      ),
    );
  }

  Widget _summary() => Container(
    color: Colors.white,
    margin: const EdgeInsets.only(top: 6),
    padding: const EdgeInsets.all(16),
    child: Text(diagnosis.summary, style: const TextStyle(fontSize: 14, height: 1.6)),
  );

  Widget _careGrid(BuildContext context) {
    final s = diagnosis.speciesInfo;
    final cells = [
      ('☀️', 'Light', s.light),
      ('💧', 'Water', s.water),
      ('💦', 'Humidity', s.humidity),
      ('🌡️', 'Temp', s.temperature),
      ('🟢', 'Difficulty', s.difficulty),
      ('⚠️', 'Toxicity', s.toxicity),
    ];
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('CARE INFO',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey, letterSpacing: 1.2)),
          const SizedBox(height: 4),
          const Text('Tap any cell for full details',
            style: TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.4,
            children: cells.map((c) => _careCell(context, c.$1, c.$2, c.$3)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _careCell(BuildContext context, String emoji, String label, String value) {
    final isToxic = label == 'Toxicity' && value.toLowerCase().contains('toxic');
    return Material(
      color: isToxic ? const Color(0xFFFFEBEE) : AppTheme.background,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _showCareDetail(context, emoji, label, value),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 4),
              Text(value.isEmpty ? '—' : value,
                style: TextStyle(fontSize: 10, color: isToxic ? Colors.red[800] : Colors.black87, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }

  void _showCareDetail(BuildContext context, String emoji, String label, String value) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Text(label.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: Colors.grey, letterSpacing: 1.2)),
                ],
              ),
              const SizedBox(height: 12),
              Text(value.isEmpty ? '—' : value,
                style: const TextStyle(fontSize: 15, height: 1.7)),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _funFact() => Container(
    margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppTheme.lightGreen,
      borderRadius: BorderRadius.circular(12)),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('🍃', style: TextStyle(fontSize: 18)),
        const SizedBox(width: 8),
        Expanded(child: Text(diagnosis.speciesInfo.funFact,
          style: const TextStyle(fontSize: 13, color: AppTheme.green, height: 1.4))),
      ],
    ),
  );

  Widget _issuesSection() {
    if (diagnosis.issues.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ISSUES DETECTED',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          ...diagnosis.issues.map((issue) => IssueCard(issue: issue)),
        ],
      ),
    );
  }

  Widget _followUp() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('🗓 ', style: TextStyle(fontSize: 16)),
        Text('Check again in ${diagnosis.followUpIn} days',
          style: const TextStyle(fontSize: 13, color: Colors.grey)),
      ],
    ),
  );
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/diagnosis_model.dart';
import '../theme.dart';
import '../widgets/severity_badge.dart';
import '../widgets/issue_card.dart';

class ResultScreen extends StatelessWidget {
  final DiagnosisResult diagnosis;
  const ResultScreen({super.key, required this.diagnosis});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: AppTheme.green,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: CachedNetworkImage(
                imageUrl: diagnosis.imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: AppTheme.lightGreen,
                  child: const Center(child: Icon(Icons.local_florist, size: 60, color: AppTheme.green))),
                errorWidget: (_, __, ___) => Container(color: AppTheme.lightGreen,
                  child: const Center(child: Icon(Icons.local_florist, size: 60, color: AppTheme.green))),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _speciesHeader(),
                _severityBanner(),
                _summary(),
                _careGrid(),
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

  Widget _speciesHeader() {
    final parts = diagnosis.plantSpecies.split('(');
    final commonName = parts[0].trim();
    final scientific = parts.length > 1 ? parts[1].replaceAll(')', '').trim() : '';
    final pct = '${(diagnosis.confidence * 100).toStringAsFixed(0)}%';

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
              color: AppTheme.lightGreen,
              borderRadius: BorderRadius.circular(20)),
            child: Text(pct, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.green)),
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

  Widget _careGrid() {
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
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.4,
            children: cells.map((c) => _careCell(c.$1, c.$2, c.$3)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _careCell(String emoji, String label, String value) {
    final isToxic = label == 'Toxicity' && value.toLowerCase().contains('toxic');
    return Container(
      decoration: BoxDecoration(
        color: isToxic ? const Color(0xFFFFEBEE) : AppTheme.background,
        borderRadius: BorderRadius.circular(10)),
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

import 'package:flutter/material.dart';
import '../models/diagnosis_model.dart';
import '../theme.dart';
import 'severity_badge.dart';

class IssueCard extends StatelessWidget {
  final PlantIssue issue;
  const IssueCard({super.key, required this.issue});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = AppTheme.severityColor(issue.severity);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(issue.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        trailing: SeverityBadge(severity: issue.severity),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label(context, 'Cause'), Text(issue.cause),
                if (issue.symptoms.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _label(context, 'Symptoms'),
                  ...issue.symptoms.map((s) => _bullet(s)),
                ],
                if (issue.treatment.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _label(context, 'Treatment'),
                  ...issue.treatment.asMap().entries.map(
                    (e) => _bullet('${e.key + 1}. ${e.value}')),
                ],
                if (issue.preventionTips.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _label(context, 'Prevention'),
                  ...issue.preventionTips.map((t) => _bullet(t)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(text.toUpperCase(),
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurfaceVariant, letterSpacing: 1)),
  );

  Widget _bullet(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 2, left: 4),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start,
      children: [const Text('• ', style: TextStyle(fontSize: 13)), Expanded(child: Text(text, style: const TextStyle(fontSize: 13)))]),
  );
}

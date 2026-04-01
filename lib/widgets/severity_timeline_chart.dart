import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/diagnosis_model.dart';
import '../theme.dart';

class SeverityTimelineChart extends StatelessWidget {
  final List<DiagnosisResult> diagnoses;

  const SeverityTimelineChart({super.key, required this.diagnoses});

  static double _severityToY(String severity) => switch (severity) {
        'healthy' => 0,
        'low' => 1,
        'medium' => 2,
        'high' => 3,
        _ => 0,
      };

  @override
  Widget build(BuildContext context) {
    if (diagnoses.length < 2) {
      return const Center(
        child: Text(
          'Scan more plants to see your health trend',
          style: TextStyle(color: Colors.grey, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      );
    }

    final spots = diagnoses.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), _severityToY(e.value.overallSeverity));
    }).toList();

    final lineColor = AppTheme.severityColor(diagnoses.last.overallSeverity);

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 3,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= diagnoses.length) {
                  return const SizedBox.shrink();
                }
                final d = diagnoses[index].createdAt;
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${d.month}/${d.day}',
                    style: const TextStyle(fontSize: 9, color: Colors.grey),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: lineColor,
            barWidth: 2.5,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, _, __, ___) {
                final severity = diagnoses[spot.x.toInt()].overallSeverity;
                return FlDotCirclePainter(
                  radius: 4,
                  color: AppTheme.severityColor(severity),
                  strokeWidth: 1.5,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: lineColor.withAlpha(25),
            ),
          ),
        ],
      ),
    );
  }
}

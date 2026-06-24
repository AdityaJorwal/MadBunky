import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/models.dart';

class SubjectSummaryWidget extends StatelessWidget {
  final Subject subject;

  const SubjectSummaryWidget({super.key, required this.subject});

  @override
  Widget build(BuildContext context) {
    // Determine colors
    final Color subjectsColor = Color(subject.colorValue ?? 0xFF4287f5);

    // Calculate chart data
    int total = subject.total;
    // Avoid division by zero
    if (total == 0) {
      // Show empty state? Or full grey ring.
    }

    // Chart Sections
    final List<PieChartSectionData> sections = [];

    if (subject.present > 0) {
      sections.add(PieChartSectionData(
        color: Colors.green,
        value: subject.present.toDouble(),
        title: '',
        radius: 8,
      ));
    }
    if (subject.proxy > 0) {
      sections.add(PieChartSectionData(
        color: Colors.amber,
        value: subject.proxy.toDouble(),
        title: '',
        radius: 8,
      ));
    }
    if (subject.absent > 0) {
      sections.add(PieChartSectionData(
        color: Colors.red,
        value: subject.absent.toDouble(),
        title: '',
        radius: 8,
      ));
    }

    // Remaining? No, absent is already counted.
    // If total=0, we can add a grey section.
    if (sections.isEmpty) {
      sections.add(PieChartSectionData(
        color: Colors.grey.withValues(alpha: 0.3),
        value: 1,
        title: '',
        radius: 8,
      ));
    }

    return Container(
      width: 150, // Matches widget min size
      height: 150,
      decoration: BoxDecoration(
        // The background is actually handled by the native XML (glass),
        // BUT if we are rendering this to an IMAGE to put ON TOP of the glass,
        // we can keep this transparent.
        // Or we can simulate the glass here if we want full control.
        // User requested "glass". Native XML provides best glass.
        // So we just render contents.
        color: Colors.transparent,
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Name
          Text(
            subject.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),

          // Chart + Percentage
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sections: sections,
                    centerSpaceRadius: 25,
                    sectionsSpace: 2,
                    startDegreeOffset: 270,
                  ),
                ),
                Text(
                  "${subject.currentPercentage.toInt()}%",
                  style: TextStyle(
                    color: subjectsColor, // Use subject color for text
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Stats Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatArgs(Icons.check, Colors.green, subject.present),
              _buildStatArgs(Icons.close, Colors.red, subject.absent),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildStatArgs(IconData icon, Color color, int value) {
    return Row(
      children: [
        Icon(icon, color: color, size: 12),
        const SizedBox(width: 4),
        Text(
          "$value",
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}

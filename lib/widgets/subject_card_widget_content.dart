import 'package:flutter/material.dart';
import '../models/models.dart';
import 'package:fl_chart/fl_chart.dart';

class SubjectCardContentWidget extends StatelessWidget {
  final Subject subject;

  const SubjectCardContentWidget({super.key, required this.subject});

  @override
  Widget build(BuildContext context) {
    // Derived from SubjectCard but simplified for Widget Image
    // We only render the visual part, interactive buttons are native.

    final percentage = subject.currentPercentage;
    final health = _calculateHealth(subject);
    final color = Color(subject.colorValue ?? 0xFF4287f5);

    return Container(
      width: 300,
      height: 120, // Adjust based on layout
      decoration: BoxDecoration(
        // Background handled by glass?
        // If we want it to look exactly like the app card, we should use the App's card decoration
        // BUT with transparent background to let glass show through?
        // User said "match app ui visual harmony".
        // App card has a container color.
        // Widget has glass background.
        // Let's render TRANSPARENT background here so Glass shows.
        color: Colors.transparent,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Left: Name & Status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  subject.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  health.statusText,
                  style: TextStyle(
                    color: health.color,
                    fontSize: 12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  "Attendance: ${percentage.toInt()}%", // Explicit text
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                )
              ],
            ),
          ),

          // Right: Progress Ring
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sections: [
                      PieChartSectionData(
                        value: percentage,
                        color: color,
                        radius: 8,
                        showTitle: false,
                      ),
                      PieChartSectionData(
                        value: 100 - percentage,
                        color: Colors.white10,
                        radius: 8,
                        showTitle: false,
                      ),
                    ],
                    startDegreeOffset: 270,
                    sectionsSpace: 0,
                    centerSpaceRadius: 30,
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "${percentage.toInt()}%",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  AttendanceHealth _calculateHealth(Subject subject) {
    // Simplified copy of health logic
    final total = subject.total;
    final effectivePresent = subject.present + subject.proxy;
    final target = subject.targetPercentage;
    final double currentPct = total == 0 ? 0 : (effectivePresent / total) * 100;

    // 1. Can I miss next class?
    int canMiss = 0;
    while (true) {
      if ((effectivePresent) / (total + canMiss + 1) * 100 < target) {
        break;
      }
      canMiss++;
      if (canMiss > 1000) break;
    }

    if (canMiss > 0) {
      return AttendanceHealth(
        "Can miss next $canMiss",
        Colors.green,
        currentPct,
      );
    }

    // 2. Must attend next?
    int mustAttend = 0;
    if (currentPct < target) {
      while (true) {
        if ((effectivePresent + mustAttend) / (total + mustAttend) * 100 >=
            target) {
          break;
        }
        mustAttend++;
        if (mustAttend > 1000) break;
      }
      return AttendanceHealth(
        "Must attend next $mustAttend",
        Colors.red,
        currentPct,
      );
    }

    return AttendanceHealth(
      "On track",
      const Color(0xFFE8A317),
      currentPct,
    );
  }
}

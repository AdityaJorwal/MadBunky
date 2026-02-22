import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ActivityGraphWidget extends StatelessWidget {
  final List<double> dataPoints;
  final String label;
  final Color color;

  const ActivityGraphWidget({
    super.key,
    required this.dataPoints,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label.toUpperCase(),
                style: GoogleFonts.ibmPlexMono(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "LIVE",
                style: GoogleFonts.ibmPlexMono(
                  color: Colors.redAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: dataPoints.length.toDouble() - 1,
                minY: 0,
                maxY: 1.2, // Normalize data 0-1
                lineBarsData: [
                  LineChartBarData(
                    spots: dataPoints
                        .asMap()
                        .entries
                        .map((e) => FlSpot(e.key.toDouble(), e.value))
                        .toList(),
                    isCurved: false, // Digital look
                    color: color,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                        show: true,
                        checkToShowDot: (spot, barData) =>
                            spot.y > 0, // Only show dots for active events
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 2,
                            color: color,
                            strokeWidth: 0,
                          );
                        }),
                    belowBarData: BarAreaData(
                      show: true,
                      color: color.withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/models.dart';
import '../theme.dart';
import '../utils/morph_dialog.dart';
import 'attendance_indicator.dart';

class FolderInfoSheet extends StatefulWidget {
  final Group group;
  final List<Subject> subjects;

  const FolderInfoSheet({
    super.key,
    required this.group,
    required this.subjects,
  });

  @override
  State<FolderInfoSheet> createState() => _FolderInfoSheetState();
}

class _FolderInfoSheetState extends State<FolderInfoSheet> {
  @override
  Widget build(BuildContext context) {
    if (widget.subjects.isEmpty) {
      return const GlassDialogContainer(
        title: "Folder Empty",
        child: Center(child: Text("No subjects in this folder.")),
      );
    }

    // --- Calculations ---

    // 1. Overall Stats
    int totalPresent = 0;
    int totalAbsent = 0;
    int totalProxy = 0;
    int totalAmbiguous = 0;

    for (var s in widget.subjects) {
      totalPresent += s.present;
      totalAbsent += s.absent;
      totalProxy += s.proxy;
      totalAmbiguous += s.ambiguous;
    }

    final totalClasses =
        totalPresent + totalAbsent + totalProxy + totalAmbiguous;
    final overallPct = totalClasses == 0
        ? 0.0
        : ((totalPresent + totalProxy) / totalClasses) * 100;

    // 2. Best & Risk Subjects
    // Copy list to sort
    final sortedSubjects = List<Subject>.from(widget.subjects);
    sortedSubjects
        .sort((a, b) => b.currentPercentage.compareTo(a.currentPercentage));

    final bestSubject = sortedSubjects.first;
    final riskSubject = sortedSubjects.last; // Could be same if only 1

    final hasRisk =
        riskSubject.currentPercentage < riskSubject.targetPercentage;

    return GlassDialogContainer(
      title: widget.group.name,
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            side: BorderSide(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: Text(
            "Close",
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          // 1. Header Stats (Overall % + Trend Graph)
          Container(
            height: 220,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Overall Health",
                          style: GoogleFonts.outfit(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "${overallPct.toStringAsFixed(1)}%",
                              style: GoogleFonts.outfit(
                                  color: overallPct >= 75
                                      ? AppTheme.pastelGreen
                                      : AppTheme.pastelRed,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  height: 1),
                            ),
                            const SizedBox(width: 8),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                "$totalClasses Total Classes",
                                style: GoogleFonts.outfit(
                                  color: Colors.white30,
                                  fontSize: 12,
                                ),
                              ),
                            )
                          ],
                        )
                      ],
                    ),
                    // Mini Circular Indicator? Or just Icon?
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: (overallPct >= 75
                                  ? AppTheme.pastelGreen
                                  : AppTheme.pastelRed)
                              .withValues(alpha: 0.1),
                          shape: BoxShape.circle),
                      child: CircularAttendanceIndicator(
                        percentage: overallPct,
                        target: 75.0, // Assuming a default target of 75% for overall health
                        color: overallPct >= 75
                            ? AppTheme.pastelGreen
                            : AppTheme.pastelRed,
                        size: 64,
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _FolderTrendChart(subjects: widget.subjects),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 2. Smart Highlights (Row of 2 Cards)
          if (widget.subjects.length > 1)
            Row(
              children: [
                Expanded(
                    child: _buildHighlightCard(
                        context,
                        "Best Performing",
                        bestSubject.name,
                        "${bestSubject.currentPercentage.toStringAsFixed(1)}%",
                        AppTheme.pastelGreen,
                        Icons.emoji_events)),
                const SizedBox(width: 12),
                Expanded(
                    child: _buildHighlightCard(
                        context,
                        "Needs Attention",
                        riskSubject.name,
                        "${riskSubject.currentPercentage.toStringAsFixed(1)}%",
                        hasRisk
                            ? AppTheme.pastelRed
                            : AppTheme
                                .pastelGreen, // Green if even worst is good
                        hasRisk ? Icons.warning : Icons.thumb_up)),
              ],
            ),

          if (widget.subjects.length > 1) const SizedBox(height: 20),

          Text(
            "Subjects Breakdown",
            style: GoogleFonts.outfit(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          // 3. Subject List
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              physics: const BouncingScrollPhysics(),
              itemCount: sortedSubjects.length,
              separatorBuilder: (c, i) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final subject = sortedSubjects[index];
                return _buildSubjectRow(context, subject);
              },
            ),
          )
        ],
      ),
    ),
  );
}

  Widget _buildHighlightCard(BuildContext context, String title, String name,
      String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.outfit(
                      color: color.withValues(alpha: 0.8),
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: GoogleFonts.outfit(
                color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            value,
            style: GoogleFonts.outfit(
                color: color, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectRow(BuildContext context, Subject subject) {
    final pct = subject.currentPercentage;
    final isSafe = pct >= subject.targetPercentage;
    final color = isSafe ? AppTheme.pastelGreen : AppTheme.pastelRed;

    return Row(
      children: [
        // Color Pill
        Container(
          width: 4,
          height: 32,
          decoration: BoxDecoration(
              color: Color(subject.colorValue ?? Colors.blue.toARGB32()),
              borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              subject.name,
              style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            // Mini Bar
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct / 100,
                minHeight: 4,
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            )
          ],
        )),
        const SizedBox(width: 12),
        Text(
          "${pct.toStringAsFixed(0)}%",
          style: GoogleFonts.outfit(color: color, fontWeight: FontWeight.bold),
        )
      ],
    );
  }
}

class _FolderTrendChart extends StatelessWidget {
  final List<Subject> subjects;

  const _FolderTrendChart({required this.subjects});

  @override
  Widget build(BuildContext context) {
    // Merge logs
    List<AttendanceLog> allLogs = [];
    for (var s in subjects) {
      allLogs.addAll(s.logs);
    }

    // Sort
    allLogs.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    if (allLogs.isEmpty) {
      return Center(
          child: Text("No activity yet",
              style: GoogleFonts.outfit(color: Colors.white30)));
    }

    // Calculate Points
    List<FlSpot> spots = [];
    int p = 0;
    int a = 0;
    int proxy = 0;
    // Ambiguous usually counts as total but not present?
    // Wait, typical formula is (Present + Proxy) / (Present + Absent + Proxy + Ambiguous).
    // Let's stick to that.
    int ambiguous = 0;

    for (int i = 0; i < allLogs.length; i++) {
      final log = allLogs[i];
      if (log.status == AttendanceStatus.present) {
        p++;
      } else if (log.status == AttendanceStatus.absent) {
        a++;
      } else if (log.status == AttendanceStatus.proxy) {
        proxy++;
      } else if (log.status == AttendanceStatus.ambiguous) {
        ambiguous++;
      }

      // We calculate point at THIS moment
      final total = p + a + proxy + ambiguous;
      final effective = p + proxy;
      final pct = total == 0 ? 0.0 : (effective / total) * 100;

      spots.add(FlSpot(i.toDouble(), pct));
    }

    // Optimizing points? If too many points, chart might lag.
    // Basic downsampling if > 100 points?
    // For now, let's assume < 1000 logs usually. LineChart handles ~hundreds fine.

    return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return LineChart(
            LineChartData(
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (spots.length - 1).toDouble(),
                minY: 0,
                maxY: 110, // A bit of headroom
                lineBarsData: [
                  LineChartBarData(
                    spots: spots.map((s) => FlSpot(s.x, s.y)).toList(),
                    isCurved: true,
                    color: Theme.of(context).colorScheme.primary,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.1 * value),
                    ),
                  ),
                  // Optional 75% line?
                  LineChartBarData(
                    spots: [
                      const FlSpot(0, 75),
                      FlSpot((spots.length - 1).toDouble(), 75)
                    ],
                    isCurved: false,
                    color: Colors.white.withValues(alpha: 0.1),
                    barWidth: 1,
                    dashArray: [5, 5],
                    dotData: FlDotData(show: false),
                  )
                ],
                lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                        fitInsideHorizontally: true,
                        fitInsideVertically: true,
                        getTooltipColor: (_) =>
                            Colors.black.withValues(alpha: 0.8),
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((spot) {
                            return LineTooltipItem(
                                "${spot.y.toStringAsFixed(1)}%",
                                const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold));
                          }).toList();
                        }))),
          );
        });
  }
}

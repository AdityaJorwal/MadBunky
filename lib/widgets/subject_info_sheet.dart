import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../theme.dart';
import '../utils/morph_dialog.dart';
import 'attendance_indicator.dart';

class SubjectInfoSheet extends ConsumerStatefulWidget {
  final String subjectId;

  const SubjectInfoSheet({super.key, required this.subjectId});

  @override
  ConsumerState<SubjectInfoSheet> createState() => _SubjectInfoSheetState();
}

class _SubjectInfoSheetState extends ConsumerState<SubjectInfoSheet> {
  int _selectedGraphIndex = 0; // 0 = Trend, 1 = Monthly

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(attendanceProvider);
    final subject = state.subjects.firstWhere(
      (s) => s.id == widget.subjectId,
      orElse: () => Subject(
        id: 'error',
        name: 'Error',
        targetPercentage: 0,
        present: 0,
        absent: 0,
        logs: [],
      ),
    );

    if (subject.id == 'error') return const SizedBox();

    final logs = List<AttendanceLog>.from(subject.logs)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return GlassDialogContainer(
      title: 'Subject Insights',
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            side: BorderSide(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            minimumSize: const Size(0, 36),
          ),
          child: Text(
            "Close",
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ],
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header stats summary
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  CircularAttendanceIndicator(
                    percentage: subject.currentPercentage,
                    target: subject.targetPercentage.toDouble(),
                    color: calculateStatus(subject).color,
                    size: 40,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Target: ${subject.targetPercentage}%",
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          // 1. Graph Section with Toggle
          Container(
            height: 220,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // Toggle
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildToggleOption("Trend", 0),
                      _buildToggleOption("Monthly", 1),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Graph content
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: ClipRect(
                      child: _selectedGraphIndex == 0
                          ? _TrendLineChart(subject: subject, logs: logs)
                          : _MonthlyBarChart(logs: logs),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 2. History Section Title
          Text(
            "Attendance History",
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 8),

          Flexible(
            child: logs.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Text(
                        "No history yet",
                        style: GoogleFonts.outfit(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      return _buildHistoryItem(
                          context, log, index == logs.length - 1);
                    },
                  ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildToggleOption(String label, int index) {
    final isSelected = _selectedGraphIndex == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedGraphIndex = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.white.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryItem(
      BuildContext context, AttendanceLog log, bool isLast) {
    // Determine Tag Color and Label
    Color tagColor;
    String tagLabel;
    IconData tagIcon;

    // If status is proxy, force type to be visually proxy regardless of source
    // unless strictly auto/schedule/manual needs to be shown?
    // Actually, user wants "Proxy" tag if status is proxy.
    // But logs have Types.
    // If log.status == proxy, let's treat it as Proxy type for display?

    LogType effectiveType = log.type;
    if (log.status == AttendanceStatus.proxy) {
      effectiveType = LogType.proxy;
    }

    switch (effectiveType) {
      case LogType.auto:
        tagColor = const Color(0xFF9D4EDD); // Purple-ish
        tagLabel = "Auto";
        tagIcon = Icons.auto_awesome;
        break;
      case LogType.proxy:
        tagColor = const Color(0xFFFFD700); // Gold
        tagLabel = "Proxy";
        tagIcon = Icons.bolt;
        break;
      case LogType.schedule:
        tagColor = Colors.blueAccent;
        tagLabel = "Scheduled";
        tagIcon = Icons.calendar_today;
        break;
      case LogType.manual:
        tagColor = Colors.grey;
        tagLabel = "Manual";
        tagIcon = Icons.touch_app;
        break;
    }

    final isPresent = log.status == AttendanceStatus.present;
    final statusColor = isPresent ? AppTheme.pastelGreen : AppTheme.pastelRed;
    // Proxy status overrides visually if needed, but log.type tracks source.
    // If status is proxy, visually it's yellow bolt.
    final displayStatus = log.status == AttendanceStatus.proxy
        ? "Proxy"
        : (isPresent ? "Present" : "Absent");
    final displayColor = log.status == AttendanceStatus.proxy
        ? const Color(0xFFFFD700)
        : statusColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (log.scheduledDate != null) {
              // Haptic
              HapticFeedback.lightImpact();

              // Normalize date to midnight to ensure clean calendar selection
              final date = log.scheduledDate!;
              final normalizedDate = DateTime(date.year, date.month, date.day);

              // 1. Set Calendar Date
              ref.read(calendarSelectedDateProvider.notifier).state =
                  normalizedDate;
              // 2. Ensure Day View
              ref.read(calendarViewProvider.notifier).state = 0;
              // 3. Switch Tab to Calendar
              ref.read(mainTabProvider.notifier).state = 0;

              // 4. Close Sheet
              // Use microtask to ensure state updates propagate before closing
              Future.microtask(() {
                if (context.mounted) Navigator.pop(context);
              });
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Status Icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: displayColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    log.status == AttendanceStatus.proxy
                        ? Icons.bolt
                        : (isPresent ? Icons.check : Icons.close),
                    color: displayColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayStatus,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (log.scheduledDate != null) ...[
                        Text(
                          "Scheduled: ${DateFormat(log.scheduledDate!.year != log.timestamp.year ? 'MMM d, yyyy' : 'MMM d').format(log.scheduledDate!)}",
                          style: GoogleFonts.outfit(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          "Response: ${DateFormat(log.scheduledDate!.year != log.timestamp.year ? 'MMM d, yyyy, h:mm a' : 'MMM d, h:mm a').format(log.timestamp)}",
                          style: GoogleFonts.outfit(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 11,
                          ),
                        ),
                      ] else
                        Text(
                          DateFormat('MMM d, h:mm a').format(log.timestamp),
                          style: GoogleFonts.outfit(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                        ),
                      if (log.scheduledDate != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            children: [
                              Text(
                                "Tap to view on calendar",
                                style: GoogleFonts.outfit(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: 0.5),
                                  fontSize: 10,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 8,
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.5),
                              )
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                // Tag
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: tagColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: tagColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(tagIcon, size: 10, color: tagColor),
                      const SizedBox(width: 4),
                      Text(
                        tagLabel,
                        style: GoogleFonts.outfit(
                          color: tagColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrendLineChart extends StatelessWidget {
  final Subject subject;
  final List<AttendanceLog> logs;

  const _TrendLineChart({required this.subject, required this.logs});

  @override
  Widget build(BuildContext context) {
    // Generate Percentage Points
    // We walk through logs reversed (oldest first) and calculate percentage cumulative.
    List<FlSpot> spots = [];
    int p = 0;
    int a = 0;
    int proxy = 0;

    // Sort logs chronologically
    final chronologicalLogs = List<AttendanceLog>.from(logs)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp)); // Oldest first

    for (int i = 0; i < chronologicalLogs.length; i++) {
      final log = chronologicalLogs[i];
      if (log.status == AttendanceStatus.present) p++;
      if (log.status == AttendanceStatus.absent) a++;
      if (log.status == AttendanceStatus.proxy) proxy++;

      final total = p + a + proxy;
      final effectivePresent = p + proxy;
      final pct = total == 0 ? 0.0 : (effectivePresent / total) * 100;

      spots.add(FlSpot(i.toDouble(), pct));
    }

    // Handle single data point: Don't add fake points, just ensure dots are shown.
    bool showDots = spots.length == 1;

    // Add current state as last point if logs might be out of sync or missing initial state
    // Actually, spots should exactly match logs.

    if (spots.isEmpty) {
      return Center(
          child: Text("Not enough data",
              style: GoogleFonts.outfit(color: Colors.white30)));
    }

    // Forming Animation
    return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(seconds: 1),
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
              maxY: 110,
              lineBarsData: [
                LineChartBarData(
                  spots: spots
                      .map((s) => FlSpot(s.x * value, s.y))
                      .toList(), // Animate X stretch or just show?
                  // Better Animation: Reveal points
                  // actually spots.take((spots.length * value).ceil()) ?
                  // Let's just animate the opacity/scale of the whole chart or rely on implicit animations?
                  // FlChart has implicit animations if data changes.
                  // But here we want 'forming'.
                  // Let's try progressively adding spots based on 'value'
                  // spots: spots.take((spots.length * value).ceil()).toList(),
                  // This might be choppy.
                  // Standard approach: just render final spots but let the line grow?
                  // Creating a custom forming effect is complex with FlChart simple api.
                  // Let's just use the spots as is, but maybe animate the Y values from 0?
                  // spots: spots.map((s) => FlSpot(s.x, s.y * value)).toList(),

                  isCurved: true,
                  color: Theme.of(context).colorScheme.primary,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData:
                      FlDotData(show: showDots), // Show dot if single point
                  belowBarData: BarAreaData(
                    show: true,
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.1 * value),
                  ),
                ),
                // Target Line
                LineChartBarData(
                  spots: [
                    FlSpot(0, subject.targetPercentage.toDouble()),
                    FlSpot((spots.length - 1).toDouble(),
                        subject.targetPercentage.toDouble())
                  ],
                  isCurved: false,
                  color: Colors.white.withValues(alpha: 0.2),
                  barWidth: 1,
                  dashArray: [5, 5],
                  dotData: FlDotData(show: false),
                )
              ],
              lineTouchData: LineTouchData(
                  getTouchedSpotIndicator: (barData, spotIndexes) {
                    return spotIndexes.map((index) {
                      return TouchedSpotIndicatorData(
                        FlLine(
                          color: Colors.white.withValues(alpha: 0.2),
                          strokeWidth: 2,
                          dashArray: [5, 5],
                        ),
                        FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) =>
                              FlDotCirclePainter(
                            radius: 4,
                            color: Colors.white,
                            strokeWidth: 2,
                            strokeColor: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      );
                    }).toList();
                  },
                  touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) =>
                          Colors.black.withValues(alpha: 0.8),
                      tooltipBorderRadius: BorderRadius.circular(12),
                      tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final index = spot.x.toInt();
                          if (index < 0 || index >= chronologicalLogs.length) {
                             return null;
                          }
                          final log = chronologicalLogs[index];
                          final dateStr = DateFormat('MMM d').format(log.timestamp);
                          
                          return LineTooltipItem(
                              "$dateStr\n${spot.y.toStringAsFixed(1)}%",
                              const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold));
                        }).whereType<LineTooltipItem>().toList();
                      })),
            ),
          );
        });
  }
}

class _MonthlyBarChart extends StatelessWidget {
  final List<AttendanceLog> logs;

  const _MonthlyBarChart({required this.logs});

  @override
  Widget build(BuildContext context) {
    // Aggregate by Month
    Map<int, Map<String, int>> monthlyStats = {}; // MonthIndex -> {P, A}

    for (var log in logs) {
      int month = log.timestamp.month;
      monthlyStats.putIfAbsent(month, () => {'P': 0, 'A': 0});

      if (log.status == AttendanceStatus.present ||
          log.status == AttendanceStatus.proxy) {
        monthlyStats[month]!['P'] = monthlyStats[month]!['P']! + 1;
      } else if (log.status == AttendanceStatus.absent) {
        monthlyStats[month]!['A'] = monthlyStats[month]!['A']! + 1;
      }
    }

    // Convert to BarGroups
    List<BarChartGroupData> barGroups = [];
    final months = monthlyStats.keys.toList()..sort();

    // Limit to last 6 months for display sanity
    final recentMonths =
        months.length > 6 ? months.sublist(months.length - 6) : months;

    for (int i = 0; i < recentMonths.length; i++) {
      final m = recentMonths[i];
      final stats = monthlyStats[m]!;
      final p = stats['P']!.toDouble();
      final a = stats['A']!.toDouble();

      barGroups.add(BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: p,
            color: AppTheme.pastelGreen,
            width: 12,
            borderRadius: BorderRadius.circular(4),
          ),
          BarChartRodData(
            toY: a,
            color: AppTheme.pastelRed,
            width: 12,
            borderRadius: BorderRadius.circular(4),
          )
        ],
        barsSpace: 4,
      ));
    }

    // Calculate Dynamic Max Y
    double maxCount = 0;
    for (int i = 0; i < recentMonths.length; i++) {
      final m = recentMonths[i];
      final stats = monthlyStats[m]!;
      if (stats['P']! > maxCount) maxCount = stats['P']!.toDouble();
      if (stats['A']! > maxCount) maxCount = stats['A']!.toDouble();
    }
    // Add buffer and ensure minimum
    final double maxY = ((maxCount > 10 ? maxCount : 10) * 1.2).ceilToDouble();

    if (barGroups.isEmpty) {
      return Center(
          child: Text("No data",
              style: GoogleFonts.outfit(color: Colors.white30)));
    }

    return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic, // Avoid overshoot
        builder: (context, value, child) {
          return BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxY, // Dynamic max
              gridData: FlGridData(show: false),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  tooltipBorder: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1)),
                  getTooltipColor: (_) => Colors.black.withValues(alpha: 0.8),
                  tooltipBorderRadius: BorderRadius.circular(12),
                  tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final isPresent = rod.color == AppTheme.pastelGreen;
                    final statusStr = isPresent ? "Present" : "Absent";
                    return BarTooltipItem(
                      "$statusStr\n${rod.toY.round()}",
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                  show: true,
                  leftTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (val, meta) {
                            if (val.toInt() >= 0 &&
                                val.toInt() < recentMonths.length) {
                              final m = recentMonths[val.toInt()];
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  DateFormat('MMM').format(DateTime(2024, m)),
                                  style: const TextStyle(
                                      color: Colors.white54, fontSize: 10),
                                ),
                              );
                            }
                            return const Text('');
                          }))),
              borderData: FlBorderData(show: false),
              barGroups: barGroups.map((group) {
                return group.copyWith(
                    barRods: group.barRods.map((rod) {
                  return rod.copyWith(toY: rod.toY * value);
                }).toList());
              }).toList(),
            ),
          );
        });
  }
}

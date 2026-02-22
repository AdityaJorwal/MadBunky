import 'dart:ui';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../providers/providers.dart';
import '../models/models.dart';
import '../theme.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: AppBar(
              backgroundColor:
                  Theme.of(context).colorScheme.surface.withValues(alpha: 0.4),
              title: Text(
                "Analytics Hub",
                style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold, fontSize: 24),
              ),
              centerTitle: true,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                },
              ),
            ),
          ),
        ),
      ),
      body: const GlobalStatsContent(),
    );
  }
}

class GlobalStatsContent extends ConsumerStatefulWidget {
  final double? topPadding;
  const GlobalStatsContent({super.key, this.topPadding});

  @override
  ConsumerState<GlobalStatsContent> createState() => _GlobalStatsContentState();
}

class _GlobalStatsContentState extends ConsumerState<GlobalStatsContent> {
  int _trendRangeIndex = 1; // 0: Week, 1: Month, 2: All

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(attendanceProvider);
    final subjects = state.subjects;

    if (subjects.isEmpty) {
      return Center(
        child: Text(
          "No data available yet.",
          style: GoogleFonts.outfit(color: Colors.white54),
        ),
      );
    }

    // --- Prepare Data ---
    // Merge all logs
    List<AttendanceLog> allLogs = [];
    for (var s in subjects) {
      allLogs.addAll(s.logs);
    }
    allLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp)); // Newest first

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(
        top: widget.topPadding ??
            (kToolbarHeight + MediaQuery.of(context).padding.top + 16),
        bottom: 100,
        left: 16,
        right: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Heatmap Section
          Text(
            "Activity Heatmap",
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 12),
          _ActivityHeatMap(logs: allLogs),
          const SizedBox(height: 32),

          // 2. Trend Graph Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Attendance Trend",
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white70,
                ),
              ),
              _buildTrendToggle(),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 250,
            child: _GlobalTrendChart(
              logs: allLogs,
              rangeIndex: _trendRangeIndex,
            ),
          ),
          const SizedBox(height: 32),

          // 3. Comparisons Section
          Text(
            "Subject Leaderboard",
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 12),
          _SubjectComparisonList(subjects: subjects),
          const SizedBox(height: 32),

          // 4. Smart Insights / Forecast
          Text(
            "Smart Forecast",
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 12),
          _SmartForecastList(subjects: subjects),
        ],
      ),
    );
  }

  Widget _buildTrendToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _toggleBtn("Week", 0),
          _toggleBtn("Month", 1),
          _toggleBtn("All", 2),
        ],
      ),
    );
  }

  Widget _toggleBtn(String label, int index) {
    final isSelected = _trendRangeIndex == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _trendRangeIndex = index);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.white54,
          ),
        ),
      ),
    );
  }
}

// --- sub-widgets ---

class _ActivityHeatMap extends StatelessWidget {
  final List<AttendanceLog> logs;
  const _ActivityHeatMap({required this.logs});

  @override
  Widget build(BuildContext context) {
    // Generate last ~90 days grid
    // 13 weeks * 7 days = 91 squares
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Start from 90 days ago
    final startDate = today.subtract(const Duration(days: 90));

    // Map logs to dates -> Score (P=1, A=0? No. A is activity too. Absence is activity.)
    // Heatmap usually shows "Activity" (magnitude).
    // Or we want "Success" (Green vs Red)?
    // Let's do: Color = Mix of Red/Green based on daily %. Opacity = Count of classes.

    Map<DateTime, List<AttendanceLog>> dailyLogs = {};
    for (var log in logs) {
      final d =
          DateTime(log.timestamp.year, log.timestamp.month, log.timestamp.day);
      if (d.isAfter(today) || d.isBefore(startDate)) continue;
      dailyLogs.putIfAbsent(d, () => []).add(log);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate grid dimensions
          // We want rows of 7 (weeks horizontal? or days vertical?)
          // GitHub style: Columns are weeks, Rows are days (Mon-Sun).
          // Let's do that.
          // 91 days / 7 = 13 cols.
          const rows = 7;
          const cols = 14;
          final itemSize = (constraints.maxWidth - (cols - 1) * 4) / cols;

          return SizedBox(
            height: rows * itemSize + (rows - 1) * 4,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              // We need to order them correctly.
              // GridView fills row by row (col 1 item 1, col 2 item 1...).
              // Wait, standard grid is row-major.
              // GitHub graph is col-major (Week 1 Mon, Week 1 Tue...).
              // We can just render linear days? No that's ugly.
              // Let's standard GridView:
              // Just simpler: Last 90 days squares, left to right, wrapping?
              // Or custom painter?
              // Let's stick to standard grid flow: Day 1, Day 2... left to right.
              // It acts like a calendar strip.
              itemCount: 91, // Fixed 91 days
              itemBuilder: (context, index) {
                // index 0 = 90 days ago? or Today?
                // Let's make index 0 = 90 days ago.
                final day = startDate.add(Duration(days: index));
                final dayLogs = dailyLogs[day] ?? [];

                Color color = Colors.white.withValues(alpha: 0.05); // No data

                if (dayLogs.isNotEmpty) {
                  int p = dayLogs
                      .where((l) =>
                          l.status == AttendanceStatus.present ||
                          l.status == AttendanceStatus.proxy)
                      .length;

                  // Or exclude ambiguous? Let's exclude ambiguous for color calc.
                  int validTotal = dayLogs
                      .where((l) => l.status != AttendanceStatus.ambiguous)
                      .length;

                  if (validTotal > 0) {
                    double pct = p / validTotal;
                    // Gradient Red to Green
                    color = Color.lerp(
                        AppTheme.pastelRed, AppTheme.pastelGreen, pct)!;

                    // Opacity based on volume?
                    // If 1 class, lighter? If 5 classes, solid?
                    double opacity = (validTotal / 5.0).clamp(0.4, 1.0);
                    color = color.withValues(alpha: opacity);
                  } else {
                    // Only ambiguous?
                    color = Colors.grey.withValues(alpha: 0.3);
                  }
                }

                return Tooltip(
                  message:
                      "${DateFormat('MMM d').format(day)}\n${dayLogs.length} events",
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _GlobalTrendChart extends StatelessWidget {
  final List<AttendanceLog> logs;
  final int rangeIndex; // 0=Wk, 1=Mo, 2=All

  const _GlobalTrendChart({required this.logs, required this.rangeIndex});

  @override
  Widget build(BuildContext context) {
    // Filter based on range
    final now = DateTime.now();
    List<AttendanceLog> filteredLogs = List.from(logs); // Already sorted desc

    DateTime? cutoff;
    if (rangeIndex == 0) cutoff = now.subtract(const Duration(days: 7));
    if (rangeIndex == 1) cutoff = now.subtract(const Duration(days: 30));

    // Sort Ascending for graph calculation
    filteredLogs.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    if (cutoff != null) {
      filteredLogs =
          filteredLogs.where((l) => l.timestamp.isAfter(cutoff!)).toList();
    }

    // If range is "Week" or "Month" but filtered logs are empty,
    // maybe we should show empty state?
    // But calculate cumulative pct?
    // Issue: If I only take last week's logs, the pct starts from 0/0 or from previous state?
    // "Trend" usually implies "Cumulative Average UP TO that point".
    // So we need ALL logs up to that point to calc the true pct.
    // So distinct logic:
    // 1. Calculate Pct for EVERY log in history.
    // 2. Crop the display to the requested time range.

    List<FlSpot> spots = [];

    // Full calculation
    int p = 0, a = 0, proxy = 0, amb = 0;

    // Need full history sorted asc
    final fullHistory = List<AttendanceLog>.from(logs)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    for (int i = 0; i < fullHistory.length; i++) {
      final log = fullHistory[i];
      if (log.status == AttendanceStatus.present) {
        p++;
      } else if (log.status == AttendanceStatus.absent) {
        a++;
      } else if (log.status == AttendanceStatus.proxy) {
        proxy++;
      } else if (log.status == AttendanceStatus.ambiguous) {
        amb++;
      }

      // Only add spot if log is within range
      if (cutoff == null || log.timestamp.isAfter(cutoff)) {
        final total = p + a + proxy + amb;
        final effective = p + proxy;
        final pct = total == 0 ? 0.0 : (effective / total) * 100;

        // X axis: simply index in the FILTERED view?
        // Or date?
        // FlChart X as index 0..N is easiest.
        spots.add(FlSpot(spots.length.toDouble(), pct));
      }
    }

    if (spots.isEmpty) {
      return Center(
          child: Text("No data in this range",
              style: GoogleFonts.outfit(color: Colors.white30)));
    }

    return Container(
      padding: const EdgeInsets.only(right: 16, top: 16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
      ),
      child: LineChart(
        LineChartData(
            gridData: FlGridData(show: false),
            titlesData: FlTitlesData(show: false),
            borderData: FlBorderData(show: false),
            minY: 0,
            maxY: 105,
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: Theme.of(context).colorScheme.primary,
                barWidth: 4,
                isStrokeCapRound: true,
                dotData: FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.1),
                ),
              ),
            ],
            lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => Colors.black.withValues(alpha: 0.8),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        return LineTooltipItem(
                            "${spot.y.toStringAsFixed(1)}%",
                            const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold));
                      }).toList();
                    }))),
      ),
    );
  }
}

class _SubjectComparisonList extends StatelessWidget {
  final List<Subject> subjects;
  const _SubjectComparisonList({required this.subjects});

  @override
  Widget build(BuildContext context) {
    // Sort by % Descending
    final sorted = List<Subject>.from(subjects)
      ..sort((a, b) => b.currentPercentage.compareTo(a.currentPercentage));

    return Column(
      children: sorted.map((s) => _buildBar(context, s)).toList(),
    );
  }

  Widget _buildBar(BuildContext context, Subject s) {
    final pct = s.currentPercentage;
    final isSafe = pct >= s.targetPercentage;
    final color = isSafe ? AppTheme.pastelGreen : AppTheme.pastelRed;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          SizedBox(
            width: 80, // Name width
            child: Text(
              s.name,
              style: GoogleFonts.outfit(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Stack(
              children: [
                Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: (pct / 100).clamp(0.0, 1.0),
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                )
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 40,
            child: Text(
              "${pct.toStringAsFixed(0)}%",
              style: GoogleFonts.outfit(
                  color: color, fontWeight: FontWeight.bold, fontSize: 13),
              textAlign: TextAlign.end,
            ),
          )
        ],
      ),
    );
  }
}

class _SmartForecastList extends StatelessWidget {
  final List<Subject> subjects;
  const _SmartForecastList({required this.subjects});

  @override
  Widget build(BuildContext context) {
    // Sort by "Urgency" (Needed classes desc, then Bunks asc)
    // Actually, let's just show top 5 items mixed?
    // Or just list all?
    // Use a horizontal list for insights cards.

    return SizedBox(
      height: 140, // Height for cars
      child: ListView.separated(
        physics: const BouncingScrollPhysics(),
        scrollDirection: Axis.horizontal,
        itemCount: subjects.length,
        separatorBuilder: (c, i) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final s = subjects[index];
          return _buildForecastCard(context, s);
        },
      ),
    );
  }

  Widget _buildForecastCard(BuildContext context, Subject s) {
    // Calculate logic
    final total = s.present + s.absent; // Ignore amb for forecast base
    final currentPct = total == 0 ? 100.0 : (s.present / total) * 100;
    final target = s.targetPercentage;

    String title;
    String subtitle;
    Color color;
    IconData icon;

    if (currentPct >= target) {
      // Safe
      // Calculate Bunks
      if (target == 0) {
        title = "Infinity";
        subtitle = "Safe to Bunk";
        color = AppTheme.pastelGreen;
        icon = Icons.all_inclusive;
      } else {
        int bunks = 0;
        while (true) {
          double p = (s.present) / (total + bunks + 1) * 100;
          if (p < target) break;
          bunks++;
          if (bunks > 50) break;
        }
        title = "+$bunks";
        subtitle = "Safe Bunks";
        color = AppTheme.pastelGreen;
        icon = Icons.event_busy;
      }
    } else {
      // Danger
      // Calculate Needed
      final numerator = (target * total) - (100 * s.present);
      final denominator = 100 - target;
      int needed = (numerator / denominator).ceil();
      if (needed < 0) needed = 0;

      title = "$needed";
      subtitle = "Must Attend";
      color = AppTheme.pastelRed;
      icon = Icons.class_;
    }

    return Container(
      width: 110,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const Spacer(),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                    fontSize: 24, fontWeight: FontWeight.bold, color: color),
              ),
              Text(
                subtitle,
                style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: color.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            s.name,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          )
        ],
      ),
    );
  }
}

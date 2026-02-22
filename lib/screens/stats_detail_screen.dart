import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

// Reuse constants

class StatsDetailScreen extends StatefulWidget {
  const StatsDetailScreen({super.key});

  @override
  State<StatsDetailScreen> createState() => _StatsDetailScreenState();
}

class _StatsDetailScreenState extends State<StatsDetailScreen> {
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;

  // Metrics
  int _cycles = 0;
  String _batteryImpact = "CALCULATING...";

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('bg_history_log');
    final cycles = prefs.getInt('service_heartbeat_count') ?? 0;

    List<Map<String, dynamic>> data = [];
    if (jsonStr != null) {
      try {
        final List<dynamic> list = jsonDecode(jsonStr);
        data = list.cast<Map<String, dynamic>>().reversed.toList();
      } catch (e) {
        debugPrint("Error parsing stats history: $e");
      }
    }

    // Calculate Impact
    // Simple heuristic: Checks in last 60 minutes
    int recentChecks = 0;
    final now = DateTime.now();
    for (var d in data) {
      final ts = DateTime.tryParse(d['timestamp'] ?? "");
      if (ts != null && now.difference(ts).inMinutes < 60) {
        recentChecks++;
      }
    }

    String impact = "LOW";
    if (recentChecks > 20) {
      impact = "HIGH";
    } else if (recentChecks > 6) {
      impact = "MEDIUM";
    }

    if (mounted) {
      setState(() {
        _history = data;
        _cycles = cycles;
        _batteryImpact = impact;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117), // kTermBg
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 18, color: Color(0xFF7EE787)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("SYSTEM_METRICS::FULL_STATS",
            style: GoogleFonts.firaCode(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF7EE787))),
        backgroundColor: const Color(0xFF0D1117),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF58A6FF)),
            onPressed: _loadData,
          )
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF7EE787)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildMetricsGrid(),
                  const SizedBox(height: 24),
                  Text("GEO_PROXIMITY_GRAPH (Last 100 Checks)",
                      style: GoogleFonts.firaCode(
                          color: const Color(0xFF58A6FF), fontSize: 12)),
                  const SizedBox(height: 8),
                  SizedBox(height: 200, child: _buildChart()),
                  const SizedBox(height: 24),
                  Text("EVENT_LOG_MATRIX",
                      style: GoogleFonts.firaCode(
                          color: const Color(0xFF58A6FF), fontSize: 12)),
                  const SizedBox(height: 8),
                  _buildLogTable(),
                ],
              ),
            ),
    );
  }

  Widget _buildMetricsGrid() {
    return Row(
      children: [
        Expanded(
            child: _buildMetricCard(
                "HEARTBEAT_CYCLES", "$_cycles", const Color(0xFFD29922))),
        const SizedBox(width: 8),
        Expanded(
            child: _buildMetricCard(
                "TOTAL_TRACKS", "${_history.length}", const Color(0xFF39C5CF))),
        const SizedBox(width: 8),
        Expanded(
            child: _buildMetricCard("BATTERY_IMPACT", _batteryImpact,
                _getImpactColor(_batteryImpact))),
      ],
    );
  }

  Color _getImpactColor(String impact) {
    if (impact == "HIGH") {
      return const Color(0xFFF85149); // Red
    }
    if (impact == "MEDIUM") {
      return const Color(0xFFD29922); // Amber
    }
    return const Color(0xFF7EE787); // Green
  }

  Widget _buildMetricCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: GoogleFonts.firaCode(
                  fontSize: 10, color: const Color(0xFF8B949E))),
          const SizedBox(height: 4),
          Text(value,
              style: GoogleFonts.firaCode(
                  fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildChart() {
    if (_history.isEmpty) {
      return Center(
          child: Text("NO_DATA_AVAILABLE",
              style: GoogleFonts.firaCode(color: const Color(0xFF484F58))));
    }

    // Parse data for chart
    // Y = Distance (clamped to prevent skewing), X = Index
    List<FlSpot> spots = [];
    int i = 0;
    // Reverse again so oldest is left
    final chronoHistory = _history.reversed.toList();

    for (var h in chronoHistory) {
      double dist = 0;
      try {
        dist = double.parse(h['dist']?.replaceAll('m', '') ?? '0');
      } catch (_) {}

      // Clamp for visibility if needed, or logarithmic?
      // Let's just raw plot but maybe cap at 1000m for view
      if (dist > 2000) {
        dist = 2000;
      }

      spots.add(FlSpot(i.toDouble(), dist));
      i++;
    }

    return LineChart(
      LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) =>
                FlLine(color: const Color(0xFF30363D), strokeWidth: 1),
          ),
          titlesData: FlTitlesData(show: false),
          borderData: FlBorderData(
              show: true, border: Border.all(color: const Color(0xFF30363D))),
          minX: 0,
          maxX: spots.length.toDouble() - 1,
          minY: 0,
          maxY: 2200, // A bit above our clamp
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: const Color(0xFF7EE787),
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                  show: true,
                  color: const Color(0xFF7EE787).withValues(alpha: 0.1)),
            ),
          ],
          lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => const Color(0xFF161B22),
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      return LineTooltipItem(
                        "${spot.y.toInt()}m",
                        GoogleFonts.firaCode(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      );
                    }).toList();
                  }))),
    );
  }

  Widget _buildLogTable() {
    return Container(
      decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF30363D)),
          borderRadius: BorderRadius.circular(4)),
      child: Column(
        children: _history.map((h) {
          final ts = DateTime.tryParse(h['timestamp'] ?? "") ?? DateTime.now();
          final time = DateFormat("HH:mm:ss").format(ts);
          final isMatch = (h['wifi'] ?? "").toString().contains("Match");
          final isInside = (h['geo'] ?? "").toString().contains("Inside");

          Color statusColor = const Color(0xFF8B949E);
          if (isMatch) {
            statusColor = const Color(0xFF7EE787);
          } else if (isInside) {
            statusColor = const Color(0xFF39C5CF);
          }

          return Container(
            decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFF30363D)))),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: Row(
              children: [
                SizedBox(
                    width: 60,
                    child: Text(time,
                        style: GoogleFonts.firaCode(
                            color: const Color(0xFF8B949E), fontSize: 10))),
                const SizedBox(width: 8),
                Expanded(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(h['subject'] ?? "UNKNOWN",
                        style: GoogleFonts.firaCode(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                    Text("WIFI: ${h['wifi']} • GEO: ${h['geo']}",
                        style: GoogleFonts.firaCode(
                            color: statusColor, fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                )),
                Text(h['dist']?.toString() ?? "--",
                    style: GoogleFonts.firaCode(
                        color: const Color(0xFFD29922), fontSize: 11)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

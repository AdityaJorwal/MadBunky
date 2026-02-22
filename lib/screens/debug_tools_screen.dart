import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:flutter/foundation.dart'; // Unused
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/models.dart';

import '../services/notification_service.dart';
import '../services/log_service.dart';

import '../widgets/debug/console_panel.dart';
import '../widgets/debug/live_log_terminal.dart';
import '../widgets/debug/activity_graph_widget.dart';

import 'stats_detail_screen.dart'; // IMPORT NEW SCREEN

// --- Terminal Theme Colors ---
const kTermBg = Color(0xFF0D1117);
const kTermFg = Color(0xFFC9D1D9);
const kTermGreen = Color(0xFF7EE787);
const kTermAmber = Color(0xFFD29922);
const kTermRed = Color(0xFFF85149);
const kTermBlue = Color(0xFF58A6FF);
const kTermDim = Color(0xFF484F58);
const kTermBorder = Color(0xFF30363D);
const kTermCyan = Color(0xFF39C5CF);

class DebugToolsScreen extends ConsumerStatefulWidget {
  const DebugToolsScreen({super.key});

  @override
  ConsumerState<DebugToolsScreen> createState() => _DebugToolsScreenState();
}

class _DebugToolsScreenState extends ConsumerState<DebugToolsScreen>
    with TickerProviderStateMixin {
  // State
  Timer? _monitorTimer;
  Map<String, dynamic> _sysStats = {};
  List<String> _liveLogs = [];
  final ScrollController _logScrollController = ScrollController();
  final bool _autoScroll = true;

  // Simulated Graph Data
  final List<double> _activityData = List.filled(30, 0.0, growable: true);
  final Random _rnd = Random();

  @override
  void initState() {
    super.initState();
    _refreshStats();
    _monitorTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _refreshStats();
      _loadRecentLogs();
      _updateGraph();
    });
    _loadRecentLogs();
  }

  @override
  void dispose() {
    _monitorTimer?.cancel();
    _logScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentLogs() async {
    final logs = await LogService().getLogs();
    if (!mounted) return;

    final newLogs = logs.split('\n').reversed.take(100).toList(); // Last 100

    // Check if new logs arrived to trigger scroll
    if (_autoScroll &&
        newLogs.length != _liveLogs.length &&
        _logScrollController.hasClients) {
      // Ideally we'd scroll to top (since reverse list)
      // But typically builder handles it if we insert at 0.
    }

    setState(() {
      _liveLogs = newLogs;
    });
  }

  void _updateGraph() {
    // Simulate "Activity" based on logs or random noise for "Hacker" feel
    // In a real app, this would be CPU usage or request count
    double val = _rnd.nextDouble() * 0.3;
    if (_liveLogs.isNotEmpty && _liveLogs.first.contains("TE")) {
      val += 0.5; // Spike on log
    }
    setState(() {
      _activityData.add(val);
      if (_activityData.length > 30) _activityData.removeAt(0);
    });
  }

  Future<void> _refreshStats() async {
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();
    final prefs = await SharedPreferences.getInstance();
    // await prefs.reload(); // Can be expensive to do every second, removed for perf.

    // Battery
    final battery = Battery();
    final batteryLevel = await battery.batteryLevel;
    final batteryState = await battery.onBatteryStateChanged.first;

    // Permissions Status
    final locStatus = await Permission.location.status;
    final notifStatus = await Permission.notification.status;

    // --- UPTIME FIX ---
    String uptimeStr = "00:00:00";
    final startIso = prefs.getString('service_start_time_iso');
    if (startIso != null) {
      final startDate = DateTime.parse(startIso);
      final diff = DateTime.now().difference(startDate);
      uptimeStr =
          "${diff.inHours.toString().padLeft(2, '0')}:${(diff.inMinutes % 60).toString().padLeft(2, '0')}:${(diff.inSeconds % 60).toString().padLeft(2, '0')}";
    } else {
      // Fallback or legacy (this can be removed effectively since we set it in background_service now)
      uptimeStr = prefs.getString('service_start_time') ?? '00:00:00';
    }
    // ------------------

    // --- Geofence Logic ---
    String locCoords = "SCANNING...";
    String nearestGeo = "NONE";
    String geoDist = "--";
    String geoStatus = "UNKNOWN";
    bool isInside = false;

    if (locStatus.isGranted) {
      try {
        // Only fetch if granted. Short timeout to prevent lag
        // Using last known if available to be faster
        Position? pos = await Geolocator.getLastKnownPosition();
        pos ??= await Geolocator.getCurrentPosition()
            .timeout(const Duration(milliseconds: 500));

        locCoords =
            "${pos.latitude.toStringAsFixed(4)},${pos.longitude.toStringAsFixed(4)}";

        final locsStr = prefs.getString('campusLocations');
        if (locsStr != null) {
          final List<dynamic> locsList = jsonDecode(locsStr);
          double minDistance = double.infinity;
          String minName = "";
          double minRadius = 0;

          for (var l in locsList) {
            final lat = l['lat'];
            final lng = l['lng'];
            final rad = l['radius'];
            final name = l['name'];

            final d = Geolocator.distanceBetween(
                pos.latitude, pos.longitude, lat, lng);
            if (d < minDistance) {
              minDistance = d;
              minName = name;
              minRadius = (rad as num).toDouble();
            }
          }

          if (minName.isNotEmpty) {
            nearestGeo = minName;
            geoDist = "${minDistance.toInt()}m";
            if (minDistance <= minRadius) {
              isInside = true;
              geoStatus = "LOCKED_IN";
            } else {
              geoStatus = "OUTSIDE_PERIMETER";
            }
          }
        } else {
          nearestGeo = "NO_DATA";
        }
      } catch (e) {
        locCoords = "GPS_OFFLINE";
      }
    } else {
      locCoords = "PERM_DENIED";
    }
    // ----------------------

    if (mounted) {
      setState(() {
        _sysStats = {
          'bg_service': isRunning,
          'battery_level': batteryLevel,
          'battery_state':
              batteryState.toString().split('.').last.toUpperCase(),
          'uptime': uptimeStr, // NEW UPTIME
          'heartbeat': prefs.getInt('service_heartbeat_count') ?? 0,
          'wifi_ssid': prefs.getString('service_last_wifi_scan') ?? 'N/A',
          'geofence_count':
              (jsonDecode(prefs.getString('campusLocations') ?? '[]') as List)
                  .length,
          'perm_loc': locStatus.isGranted,
          'perm_notif': notifStatus.isGranted,
          'loc_coords': locCoords,
          'geo_nearest': nearestGeo,
          'geo_dist': geoDist,
          'geo_status': geoStatus,
          'is_inside': isInside,
        };
      });
    }
  }

  void _addLog(String msg) {
    setState(() {
      _liveLogs.insert(0, "[TE] $msg"); // Local echo
    });
  }

  @override
  Widget build(BuildContext context) {
    final fontMono = GoogleFonts.firaCode();

    return Scaffold(
      backgroundColor: kTermBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ROW 1: System Matrix
                    SizedBox(
                      height: 140, // Fixed height for status cards
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 2,
                            child: ConsolePanel(
                              title: "SYSTEM_CORE",
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildStatRow(
                                      "BATTERY",
                                      "${_sysStats['battery_level'] ?? '--'}% [${_sysStats['battery_state'] ?? '..'}]",
                                      kTermGreen),
                                  _buildStatRow("UPTIME",
                                      "${_sysStats['uptime']}", kTermBlue),
                                  _buildStatRow(
                                      "HEARTBEAT",
                                      "${_sysStats['heartbeat'] ?? 0} CYCLES",
                                      kTermAmber),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 3,
                            child: ConsolePanel(
                              title: "GEO_RADAR",
                              isError: _sysStats['is_inside'] == false &&
                                  _sysStats['geo_status'] ==
                                      'LOCKED_IN', // logic check
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildStatRow("COORDS",
                                      "${_sysStats['loc_coords']}", kTermCyan),
                                  _buildStatRow(
                                      "TARGET",
                                      "${_sysStats['geo_nearest']}",
                                      kTermAmber),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      _buildStatRow("DIST",
                                          "${_sysStats['geo_dist']}", kTermFg),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 4, vertical: 2),
                                        color: _sysStats['is_inside'] == true
                                            ? kTermGreen
                                            : kTermRed,
                                        child: Text(
                                          _sysStats['geo_status'] ?? "SCANNING",
                                          style: GoogleFonts.firaCode(
                                              fontSize: 10,
                                              color: Colors.black,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      )
                                    ],
                                  )
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // ROW 2: Graphs & Wifi
                    SizedBox(
                      height: 120,
                      child: Row(
                        children: [
                          Expanded(
                            child: ActivityGraphWidget(
                              dataPoints: _activityData,
                              label: "CPU_LOAD_SIM",
                              color: kTermBlue,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ConsolePanel(
                              title: "NETWORK_LNK",
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("WIFI_SSID:",
                                      style: fontMono.copyWith(
                                          fontSize: 10, color: kTermDim)),
                                  Text("${_sysStats['wifi_ssid']}",
                                      style: fontMono.copyWith(
                                          fontSize: 14,
                                          color: kTermGreen,
                                          fontWeight: FontWeight.bold)),
                                  const Spacer(),
                                  Text("BG_SERVICE:",
                                      style: fontMono.copyWith(
                                          fontSize: 10, color: kTermDim)),
                                  Row(
                                    children: [
                                      Icon(Icons.circle,
                                          size: 8,
                                          color: _sysStats['bg_service'] == true
                                              ? kTermGreen
                                              : kTermRed),
                                      const SizedBox(width: 6),
                                      Text(
                                          _sysStats['bg_service'] == true
                                              ? "RUNNING"
                                              : "STOPPED",
                                          style: fontMono.copyWith(
                                              fontSize: 12, color: kTermFg)),
                                    ],
                                  )
                                ],
                              ),
                            ),
                          )
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // ROW 3: Control Deck
                    ConsolePanel(
                      title: "COMMAND_DECK",
                      height: 140,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildCmdBtn("SRV_RST", kTermBlue, _restartService),
                          _buildCmdBtn("GEO_CHK", kTermCyan,
                              _refreshStats), // Just refreshes UI for now
                          _buildCmdBtn(
                              "NOTIF_TST", kTermGreen, _testNotification),
                          _buildCmdBtn("LOG_CLR", kTermRed, _clearLogs),
                          _buildCmdBtn("FULL_STATS", kTermAmber, () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const StatsDetailScreen()));
                          }),
                          _buildCmdBtn("SHARE_LOGS", const Color(0xFFC9D1D9),
                              _shareLogs),
                          // Crash app removed
                          _buildCmdBtn(
                              "TEST_CLASS", kTermRed, _injectTestSession),
                          _buildCmdBtn("OCR_LOGS", kTermAmber, _showOcrLogs),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // ROW 4: Live Terminal
                    SizedBox(
                      height: 400, // Tall terminal
                      child: ConsolePanel(
                        title: "LIVE_TERMINAL_FEED",
                        child: LiveLogTerminal(
                            logs: _liveLogs,
                            scrollController: _logScrollController,
                            autoScroll: _autoScroll),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: kTermBg,
        border: Border(bottom: BorderSide(color: kTermBorder)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                size: 18, color: kTermGreen),
            onPressed: () => Navigator.pop(context),
          ),
          Text("DEV_CONSOLE::MASTER",
              style: GoogleFonts.firaCode(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: kTermGreen)),
          const Spacer(),
          // Blink indicator
          _BlinkingCursor(),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color valColor) {
    return Row(
      children: [
        Text(label, style: GoogleFonts.firaCode(fontSize: 10, color: kTermDim)),
        const SizedBox(width: 6),
        Expanded(
            child: Text(value,
                style: GoogleFonts.firaCode(fontSize: 11, color: valColor),
                overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  Widget _buildCmdBtn(String label, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();
          onTap();
        },
        child: Container(
          width: 80,
          height: 40,
          decoration: BoxDecoration(
            border: Border.all(color: color.withValues(alpha: 0.5)),
            color: color.withValues(alpha: 0.1),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.firaCode(
                fontSize: 10, fontWeight: FontWeight.bold, color: color),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  // Actions
  Future<void> _restartService() async {
    _addLog("CMD > STOPPING_SERVICE...");
    final s = FlutterBackgroundService();
    s.invoke('stop');
    await Future.delayed(const Duration(seconds: 1));
    await s.startService();
    _addLog("CMD > SERVICE_RESTART_SIGNAL_SENT");
  }

  Future<void> _shareLogs() async {
    await LogService().shareLogs();
  }

  void _testNotification() {
    NotificationService().showInstantNotification(
        id: 9999,
        title: "DEBUG_TEST",
        body: "Test Protocol Initiated @ ${DateTime.now().second}");
    _addLog("CMD > NOTIFICATION_DISPATCHED");
  }

  void _showOcrLogs() {
    _addLog("CMD > OCR LOGS NOT AVAILABLE");
  }

  Future<void> _clearLogs() async {
    await LogService().clearLogs();
    _addLog("CMD > LOGS_PURGED");
  }

  Future<void> _injectTestSession() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final start = now.add(const Duration(seconds: 5));
    final end = start.add(const Duration(minutes: 1));

    final testSession = ClassSession(
        id: "TEST_SESSION_ID",
        subjectName: "Debug Logic",
        subjectId: "TEST_SUBJECT_ID",
        startTime: start,
        endTime: end,
        colorValue: Colors.red.toARGB32(),
        teacherName: "System",
        status: AttendanceStatus.pending,
        isConcrete: true);

    // Load existing
    List<ClassSession> sessions = [];
    final sStr = prefs.getString('sessions');
    if (sStr != null) {
      sessions = (jsonDecode(sStr) as List)
          .map((x) => ClassSession.fromJson(x))
          .toList();
    }
    sessions.add(testSession);

    // Save
    final encoded = jsonEncode(sessions.map((x) => x.toJson()).toList());
    await prefs.setString('sessions', encoded);

    // Force Background Service Update
    final service = FlutterBackgroundService();
    service.invoke('update');

    _addLog("CMD > T-MINUS 5s : ${start.toIso8601String()}");

    // Show quick feedback
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Test Class Scheduled (Starts in 5s)")),
      );
    }
  }
}

// Blinking cursor widget
class _BlinkingCursor extends StatefulWidget {
  @override
  _BlinkingCursorState createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(width: 8, height: 16, color: kTermGreen),
    );
  }
}

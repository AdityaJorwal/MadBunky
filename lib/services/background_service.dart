import 'dart:async';
import 'dart:isolate'; // Added for Isolate.current
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:battery_plus/battery_plus.dart';
import 'package:permission_handler/permission_handler.dart'; // Added

import '../models/models.dart';
import 'notification_service.dart';

import 'live_activity_service.dart';
import 'log_service.dart';
import 'package:intl/intl.dart'; // Added for DateFormat

// Top-level entry point (Safe for Background Service)
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
  }

  // 0. MASTER TRY-CATCH
  try {
    // Vital for Plugins
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    // Initialize Prefs early for status
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    await prefs.setString('service_status', "Starting (TopLevel)...");
    debugPrint("BG Service: MARKER 1 - Started (TopLevel)");

    // Register Port for Background Communication
    final ReceivePort port = ReceivePort();
    IsolateNameServer.removePortNameMapping('madbunky_bg_service');
    IsolateNameServer.registerPortWithName(port.sendPort, 'madbunky_bg_service');
    port.listen((message) {
      if (message is String && message == 'update') {
        if (MadBackgroundService._interruptSleep != null &&
            !MadBackgroundService._interruptSleep!.isCompleted) {
          MadBackgroundService._interruptSleep!.complete();
        }
      } else if (message is Map<String, dynamic>) {
        // Handle manual status update from notification isolate
        final sessionId = message['sessionId'] as String?;
        final statusIndex = message['statusIndex'] as int?;
        if (sessionId != null && statusIndex != null) {
          final status = AttendanceStatus.values[statusIndex];
          LiveActivityService().manuallyUpdateStatus(sessionId, status);
          debugPrint("BG Service Port: Received Status Update for $sessionId");
          
          if (MadBackgroundService._interruptSleep != null &&
              !MadBackgroundService._interruptSleep!.isCompleted) {
            MadBackgroundService._interruptSleep!.complete();
          }
        }
      }
    });

    // Initialize Logging (Robust)
    try {
      await LogService().init();
      await LogService()
          .log("BG Service: Starting (Isolate ${Isolate.current.debugName})");
    } catch (e) {
      debugPrint("BG Service: LogService Init Failed: $e");
      await prefs.setString('service_status', "LogService Error: $e");
    }

    MadBackgroundService._isServiceRunning = true;

    // 1. GATEKEEPER CHECK (BOOT START)
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        if (!await Permission.notification.isGranted) {
          // Basic check
        }
      } catch (e) {
        debugPrint("BG Service: Permission check failed: $e");
      }
    }

    // Initialize NotificationPlugin for this Isolate
    try {
      await LogService().log("BG Service: Initializing Notifications...");
      await NotificationService().init(isolateName: 'madbunky_bg_port');
    } catch (e) {
      debugPrint("BG Service: Notification Init Failed: $e");
      await prefs.setString('service_status', "NotifService Error: $e");
    }

    try {
      await LiveActivityService().init();
    } catch (e) {
      debugPrint("BG Service: LiveActivity Init Failed: $e");
    }

    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });

      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
    }

    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    service.on('update').listen((event) async {
      await LogService().log("BG Service: Received UPDATE signal");
      // Force settings reload
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();

      // Trigger a check immediately by interrupting sleep
      if (MadBackgroundService._interruptSleep != null &&
          !MadBackgroundService._interruptSleep!.isCompleted) {
        MadBackgroundService._interruptSleep!.complete();
      }
    });

    service.on('manual_status_update').listen((event) async {
      if (event != null) {
        final sessionId = event['sessionId'] as String?;
        final statusIndex = event['statusIndex'] as int?;
        if (sessionId != null && statusIndex != null) {
          final status = AttendanceStatus.values[statusIndex];
          LiveActivityService().manuallyUpdateStatus(sessionId, status);
          debugPrint(
              "BG Service: Received Manual Status Update for $sessionId -> $status");

          // Force instant refresh of loop to pick up new state from disk/memory
          // and prevent overwriting the visual update
          final prefs = await SharedPreferences.getInstance();
          await prefs.reload();

          if (MadBackgroundService._interruptSleep != null &&
              !MadBackgroundService._interruptSleep!.isCompleted) {
            MadBackgroundService._interruptSleep!.complete();
          }
        }
      }
    });

    // 2. MAIN LOOP (Smart Loop)
    await LogService().log("BG Service: Handing over to Smart Loop");
    await prefs.setString('service_status', "Starting Smart Loop...");

    // UPTIME FIX: Record start time
    if (!prefs.containsKey('service_start_time_iso')) {
      await prefs.setString(
          'service_start_time_iso', DateTime.now().toIso8601String());
    }

    // Call the complex loop that handles sessions, sleep, and triggers
    await MadBackgroundService._backgroundLoop(service);
  } catch (e, stack) {
    debugPrint("BG Service: FATAL ERROR: $e");
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('service_status', "FATAL: $e");
    try {
      await LogService().error("BG Service Fatal Crash", stack);
    } catch (_) {}
  }
}

class MadBackgroundService {
  static Completer<void>? _interruptSleep;
  // ignore: prefer_final_fields
  static bool _isServiceRunning = false;

  // HISTORY TRACKING HELPER
  static Future<void> _addToHistory(SharedPreferences prefs, String subject,
      String wifiStatus, String geoStatus, String distance) async {
    final historyJson = prefs.getString('bg_history_log') ?? '[]';
    List<dynamic> history = [];
    try {
      history = jsonDecode(historyJson);
    } catch (_) {}

    // Add new entry
    history.add({
      'timestamp': DateTime.now().toIso8601String(),
      'subject': subject,
      'wifi': wifiStatus,
      'geo': geoStatus,
      'dist': distance
    });

    // Cap at 100
    if (history.length > 100) {
      history = history.sublist(history.length - 100);
    }

    await prefs.setString('bg_history_log', jsonEncode(history));
  }

  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    // Android Notification Channel for the Foreground Service
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'auto_attendance_service', // id
      'Attendance Services Active', // title
      description: 'Running in background to check attendance',
      importance: Importance.low,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    if (defaultTargetPlatform == TargetPlatform.android) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart, // Uses Top-Level Function
        autoStart: false, // Must be false to avoid crashing without permissions on boot/start
        isForegroundMode: true,
        notificationChannelId: 'auto_attendance_service',
        initialNotificationTitle: 'Attendance Services Active',
        initialNotificationContent: 'Optimizing background monitoring...',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false, // Must be false to avoid premature launch
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    return true;
  }

  static Future<void> _performHeartbeatCheck(SharedPreferences prefs) async {
    // Validates WiFi/Geo status just for the "SERVICES" debug panel
    await LogService().log("BG Service: Heartbeat Check...");

    // Manual Extraction
    final enabledGeo = prefs.getBool('enableGeofence') ?? false;
    final enabledWifi = prefs.getBool('enableWifiTrigger') ?? false;
    final campusSsids = prefs.getStringList('campusSsids') ?? [];

    if (!enabledGeo && !enabledWifi) {
      await prefs.setString('service_status', "Idle (Features Disabled)");
      return;
    }

    await prefs.setString('service_status', "Checking...");

    if (enabledWifi) {
      bool hasLoc = await Permission.location.isGranted;
      if (hasLoc) {
        try {
          final info = NetworkInfo();
          String? wifiName = await info.getWifiName();
          await prefs.setString('service_last_wifi_scan', wifiName ?? "NULL");

          if (wifiName != null) {
            wifiName = wifiName.replaceAll('"', '');
            if (campusSsids.contains(wifiName)) {
              await prefs.setString('service_wifi_status', "MATCH");
            } else {
              await prefs.setString('service_wifi_status', "NO MATCH");
            }
          } else {
            await prefs.setString(
                'service_wifi_status', "NULL (Not Connected?)");
          }
        } catch (e) {
          await prefs.setString('service_wifi_status', "ERROR: $e");
        }
      } else {
        await prefs.setString('service_wifi_status', "SKIPPED (No Perm)");
      }
    }
  }

  static Future<void> _backgroundLoop(ServiceInstance service) async {
    debugPrint("BG Service: Starting Smart Loop");

    while (_isServiceRunning) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.reload();

        final enabledGeo = prefs.getBool('enableGeofence') ?? false;
        final enabledWifi = prefs.getBool('enableWifiTrigger') ?? false;
        final enabledSync = false;
        final enabledLive = prefs.getBool('enableLiveActivity') ?? false;

        if (!enabledGeo && !enabledWifi && !enabledSync && !enabledLive) {
          await prefs.setString(
              'service_status', "Stopped: All features disabled");
          debugPrint("BG Service: All features disabled. Sleeping long.");
          // Sleep for an hour or until "update" signal
          await _smartDelay(const Duration(hours: 1));
          continue;
        }

        await prefs.setString('service_status', "Running: Loop Active");

        // --- VISIBILITY CHECK (HEARTBEAT) ---
        // Ensure we update status even if no active sessions, so user can debug.
        try {
          await _performHeartbeatCheck(prefs);
        } catch (e) {
          debugPrint("BG Service: Heartbeat check failed: $e");
        }

        // --- HEARTBEAT TRACE ---
        const heartbeatKey = 'service_last_heartbeat';
        const countKey = 'service_heartbeat_count';
        await prefs.setString(heartbeatKey, DateTime.now().toIso8601String());
        final currentCount = prefs.getInt(countKey) ?? 0;
        await prefs.setInt(countKey, currentCount + 1);
        // -----------------------

        if (service is AndroidServiceInstance) {
          await _updateServiceNotification(
              service, prefs, "Active • Monitoring...");
        }

        final now = DateTime.now();

        debugPrint("BG Service: Loop Tick...");

        // Sync Check Removed

        // --- SESSION LOGIC ---
        // Cleanup ended sessions first
        await _finalizeEndedSessions(prefs, service);

        final sessionsJson = prefs.getString('sessions');
        List<ClassSession> activeSessions = [];
        List<ClassSession> allSessions = [];
        ClassSession? nextSession;

        if (sessionsJson != null) {
          final List<dynamic> decodedS = jsonDecode(sessionsJson);
          allSessions = decodedS.map((x) => ClassSession.fromJson(x)).toList();
          final sessions = allSessions;

          // Find All Active Sessions
          try {
            activeSessions = sessions.where((s) {
              return !s.isCancelled &&
                  now.isAfter(s.startTime) &&
                  now.isBefore(s.endTime);
            }).toList();
          } catch (_) {}

          // If no active, find Next
          if (activeSessions.isEmpty) {
            try {
              final upcoming =
                  sessions.where((s) => s.startTime.isAfter(now)).toList();
              upcoming.sort((a, b) => a.startTime.compareTo(b.startTime));
              if (upcoming.isNotEmpty) nextSession = upcoming.first;
            } catch (_) {}
          } else {
            // Also find next upcoming session even if we have active ones,
            // to ensure we wake up if a new overlap starts.
            try {
              final upcoming =
                  sessions.where((s) => s.startTime.isAfter(now)).toList();
              upcoming.sort((a, b) => a.startTime.compareTo(b.startTime));
              if (upcoming.isNotEmpty) nextSession = upcoming.first;
            } catch (_) {}
          }
        }

        Duration sleepDuration =
            const Duration(minutes: 10); // Default to sync interval

        if (activeSessions.isNotEmpty) {
          // --- ACTIVE TRACKING ---
          debugPrint(
              "BG Service: Active Sessions Found: ${activeSessions.length}");

          // 1. Sync Live Activities (Start new, Update existing, End stale)
          // 1. Sync Live Activities (Start new, Update existing, End stale)
          try {
            await LiveActivityService()
                .syncActiveSessions(activeSessions, allSessions);
          } catch (e) {
            debugPrint("BG Service: LiveActivity sync failed: $e");
          }

          // 2. Perform Checks for ALL active sessions
          for (final session in activeSessions) {
            try {
              await _performActiveCheck(
                  prefs, session, enabledWifi, enabledGeo, service);
            } catch (e) {
              debugPrint(
                  "BG Service: Check failed for ${session.subjectName}: $e");
            }
          }

          // 3. Determine Sleep Duration
          // We want to check again reasonably soon.
          // Base it on the session that ends soonest OR standard interval.
          // Sorting by end time is good, but let's stick to simple logic:
          // Min valid check interval across all sessions.

          List<int> proposedIntervals = [];

          for (final session in activeSessions) {
            final duration = session.endTime.difference(session.startTime);

            // Adjust for Buffer Logic to match _performActiveCheck
            final int bufferMinutes = duration.inMinutes >= 40 ? 10 : 2;
            final validDuration =
                duration - Duration(minutes: bufferMinutes * 2);

            // USER REQUEST: 5 Segments (Power Saver)
            // "divided into 5 segments ... if geofence identified at least one time that will trigger mark"
            final isBatterySaver = prefs.getBool('enableBatterySaver') ?? false;
            final int segments = isBatterySaver
                ? 3
                : 5; // Check less often if battery saver is on
            int segMinutes = (validDuration.inMinutes / segments).floor();

            if (segMinutes < 1) {
              segMinutes = 1; // Align with _performActiveCheck minimum
            }
            proposedIntervals.add(segMinutes);
          }
          proposedIntervals.sort();
          int chosenMinutes = proposedIntervals.isNotEmpty
              ? proposedIntervals.first
              : 5; // Default to 5 if no segments found

          sleepDuration = Duration(minutes: chosenMinutes);

          // 4. Constraint: Don't sleep past the End Time of ANY active session (plus buffer)
          for (final session in activeSessions) {
            final timeToEnd = session.endTime.difference(now);
            // Wake up 1 second after end to finalize immediately
            Duration wakeTime = timeToEnd + const Duration(seconds: 1);
            if (wakeTime < sleepDuration) {
              sleepDuration = wakeTime;
            }
          }

          // 5. Constraint: Don't sleep past the START Time of the NEXT session (Overlapping start)
          if (nextSession != null) {
            final timeToNext = nextSession.startTime.difference(now);
            if (timeToNext.isNegative) {
              // Should technically be active, but maybe just transitioning.
            } else if (timeToNext < sleepDuration) {
              sleepDuration =
                  timeToNext; // Wake up exactly when next one starts
              debugPrint(
                  "BG Service: Reducing sleep to wake for Next Session start: ${nextSession.subjectName}");
            }
          }

          // Ensure non-negative
          if (sleepDuration.isNegative) {
            sleepDuration = const Duration(seconds: 5);
          }
        } else if (nextSession != null) {
          // --- WAITING FOR NEXT ---
          // Ensure any previous activity is cleared
          await LiveActivityService().syncActiveSessions([], allSessions);

          // CLEAR STATUS INDICATORS
          await prefs.setString(
              'service_wifi_status', "Standby (Waiting for Class)");
          await prefs.setString('geo_status', "Standby");

          final timeToNext = nextSession.startTime.difference(now);
          debugPrint(
              "BG Service: Next Session in ${timeToNext.inMinutes} mins");

          // Update notification
          await _updateServiceNotification(service, prefs,
              "Waiting • Next: ${nextSession.subjectName} @ ${nextSession.startTime.hour}:${nextSession.startTime.minute.toString().padLeft(2, '0')}");

          // Sleep until next session OR next sync
          // If timeToNext is large (> 10 mins), we must wake up for sync
          // Sleep logic simplified (Sync Removed)
          sleepDuration =
              timeToNext.isNegative ? const Duration(seconds: 5) : timeToNext;
        } else {
          // --- NO MORE SESSIONS ---
          // Ensure any previous activity is cleared
          await LiveActivityService().syncActiveSessions([], allSessions);

          await prefs.setString('service_wifi_status', "Standby (No Classes)");
          await prefs.setString('geo_status', "Standby");

          debugPrint("BG Service: No active or upcoming sessions.");
          await _updateServiceNotification(
              service, prefs, "Idle • No upcoming classes");
          sleepDuration = const Duration(minutes: 30); // Sleep long
        }

        // --- SMART SLEEP ---
        debugPrint(
            "BG Service: Sleeping for ${sleepDuration.inSeconds} seconds...");
        await _smartDelay(sleepDuration);
      } catch (e) {
        debugPrint("BG Service Error: $e");
        await _smartDelay(const Duration(minutes: 1)); // Backoff
      }
    }
  }

  static Future<void> _smartDelay(Duration duration) async {
    _interruptSleep = Completer<void>();

    // OEM BATTERY OPTIMIZATION:
    // Prevent aggressive spinning. If sleep duration is less than 30 seconds,
    // bump it to 30s to prevent Xiaomi/Samsung from killing the process.
    Duration safeDuration = duration < const Duration(seconds: 30)
        ? const Duration(seconds: 30)
        : duration;

    // Fast-path: if we are in standby (no classes for hours), enforce a minimum of 15 min sleep
    // to keep background footprint negligible.
    if (safeDuration.inMinutes > 30) {
      safeDuration = const Duration(
          minutes:
              15); // Wake occasionally to refresh notification/system state
    }

    debugPrint(
        "BG Service: SmartDelay initiated for ${safeDuration.inSeconds} seconds.");
    await Future.any([
      Future.delayed(safeDuration),
      _interruptSleep!.future,
    ]);
  }

  static Future<void> _performActiveCheck(
      SharedPreferences prefs,
      ClassSession activeSession,
      bool enabledWifi,
      bool enabledGeo,
      ServiceInstance service) async {
    // Check Frequency Throttling
    final now = DateTime.now();
    final lastCheckStr = prefs.getString('last_bg_check_${activeSession.id}');

    // 0. EARLY EXIT: If already marked present (Trust Mode), stop wasting battery
    final isAutoMarked =
        prefs.getBool('session_auto_marked_${activeSession.id}') ?? false;
    if (isAutoMarked) {
      // We already caught them once. No need to keep pinging GPS.
      debugPrint(
          "BG Service: Skipping check - Already Marked Present (Power Saver)");
      if (service is AndroidServiceInstance) {
        // Just keep the notification chill
      }
      return;
    }

    // 1. BUFFER ZONES (Start/End Buffer)
    // User Request: "start 10 and last 10 minutes will not take location"
    final sessionDuration =
        activeSession.endTime.difference(activeSession.startTime);

    // Fallback for short classes: If class is < 40 mins, 10+10 consumes it all.
    // So if < 40 mins, usage smaller buffer (e.g. 2 mins).
    final int bufferMinutes = sessionDuration.inMinutes >= 40 ? 10 : 2;

    final validStart =
        activeSession.startTime.add(Duration(minutes: bufferMinutes));
    final validEnd =
        activeSession.endTime.subtract(Duration(minutes: bufferMinutes));

    if (now.isBefore(validStart)) {
      debugPrint(
          "BG Service: Skipping check - Start Buffer Zone (Wait ${validStart.difference(now).inMinutes}m)");
      return;
    }
    if (now.isAfter(validEnd)) {
      debugPrint(
          "BG Service: Skipping check - End Buffer Zone (Class effectively over)");
      return;
    }

    // 2. SEGMENTATION (5 Segments)
    // "divided into 5 segments ... if geofence identified at least one time that will trigger mark"
    final validDuration = validEnd.difference(validStart);
    int segmentMinutes = (validDuration.inMinutes / 5).floor();
    if (segmentMinutes < 1) segmentMinutes = 1;

    final checkInterval = Duration(minutes: segmentMinutes);

    if (lastCheckStr != null) {
      final lastCheck = DateTime.parse(lastCheckStr);
      // STRICT CHECK: Only proceed if enough time has passed since last check
      // This prevents "Sync" or other wake-ups from triggering a location check too early.
      if (now.difference(lastCheck) < checkInterval) {
        debugPrint(
            "BG Service: Skipping check (Debounce Active). Next check in ${(checkInterval - now.difference(lastCheck)).inMinutes} min");
        if (service is AndroidServiceInstance) {
          await _updateServiceNotification(
              service, prefs, "Active • Waiting for interval...");
        }
        return;
      }
    }

    bool present = false;
    bool checkValid = false; // Initialize flag

    // Wifi Check
    if (enabledWifi) {
      bool hasLoc = await Permission.location.isGranted;
      bool isLocServiceEnabled =
          await Permission.location.serviceStatus.isEnabled; // Check Service

      if (hasLoc) {
        if (!isLocServiceEnabled) {
          debugPrint(
              "BG Service: Location Permission granted, but Location Services are OFF. WiFi Name might be null.");
          await prefs.setString(
              'service_wifi_status', "Warn: Loc Services OFF");
        }

        try {
          final ssids = prefs.getStringList('campusSsids') ?? [];
          final info = NetworkInfo();
          String? wifiName = await info.getWifiName();

          // remove quotes if present
          if (wifiName != null) {
            wifiName = wifiName.replaceAll('"', '');
          }

          await prefs.setString('service_last_wifi_scan', wifiName ?? "NULL");

          debugPrint("BG Service: Current WiFi: $wifiName"); // Debug

          // If we successfully reasoned about Wifi, it's valid if we don't need Geofence backup
          // If we find a match, it's definitely valid (and present).
          // If we don't find a match, it's valid ONLY if Geofence is disabled.
          // (If Geofence is enabled, we need to check that before deciding 'Absent')
          checkValid = !enabledGeo;

          if (wifiName != null && wifiName != "<unknown ssid>") {
            if (ssids.contains(wifiName)) {
              present = true;
              checkValid = true; // Definitely valid if found
              await prefs.setString('service_wifi_status', "Match: $wifiName");
              debugPrint("BG Service: WiFi Match Found!");

              // BATTERY SAVER: WiFi Priority
              if (prefs.getBool('enableBatterySaver') ?? false) {
                enabledGeo = false;
                debugPrint(
                    "BG Service: Battery Saver - WiFi Found. Skipping Geofence.");
                await _updateServiceNotification(
                    service, prefs, "Active • WiFi • Optimized");
              }
            } else {
              await prefs.setString(
                  'service_wifi_status', "No Match: $wifiName");
            }
          } else {
            await prefs.setString('service_wifi_status', "No Name / Unknown");
          }
        } catch (e) {
          debugPrint("Wifi check error: $e");
          await prefs.setString('service_wifi_status', "Error: $e");
          checkValid = false;
        }
      } else {
        debugPrint(
            "BG Service: WiFi check skipped - Location Permission missing");
        await prefs.setString(
            'service_wifi_status', "Skipped: No Loc Permission");
      }
    }

    // Capture Wifi Status for Log
    String logWifiStatus = prefs.getString('service_wifi_status') ?? "N/A";

    String currentAction = "Active Tracking";
    if (enabledWifi && !present) {
      currentAction = "Verifying Location...";
    } else if (enabledWifi && present) {
      currentAction = "Verified via WiFi";
    }

    // Geofence Check (Only if Wifi didn't verify)
    String logGeoStatus = "Skipped (WiFi Verified)";
    String logCoords = "N/A";

    if (!present && enabledGeo) {
      if (await Permission.location.isGranted) {
        // Corrected Key Name: campusLocations
        final locsStr = prefs.getString('campusLocations');
        if (locsStr != null) {
          try {
            final List<dynamic> locsList = jsonDecode(locsStr);
            final locations =
                locsList.map((x) => LocationItem.fromJson(x)).toList();

            debugPrint("BG Service: Checking ${locations.length} Geofences...");
            // Update Status: Tracking
            if (service is AndroidServiceInstance) {
              await _updateServiceNotification(
                  service, prefs, "Active • Geofence • Tracking Location...");
            }

            // 1. Try Last Known (Fastest & Battery Friendly)
            Position? pos = await Geolocator.getLastKnownPosition();

            // 2. If null, force current with timeout
            // 2. If null, force current with timeout
            // BATTERY SAVER: Dynamic Accuracy
            final isBatterySaver = prefs.getBool('enableBatterySaver') ?? false;
            final targetAccuracy = isBatterySaver
                ? LocationAccuracy.medium // ~100m (Cell/WiFi)
                : LocationAccuracy.high; // ~10m (GPS)

            // ignore: unnecessary_null_comparison
            pos ??= await Geolocator.getCurrentPosition(
                    locationSettings:
                        LocationSettings(accuracy: targetAccuracy))
                .timeout(const Duration(seconds: 15));

            debugPrint(
                "BG Service: Position: ${pos.latitude}, ${pos.longitude}");

            logCoords =
                "${pos.latitude.toStringAsFixed(5)},${pos.longitude.toStringAsFixed(5)}";
            logGeoStatus = "Outside";

            for (var loc in locations) {
              // Check if this location is specific to certain subjects
              if (loc.subjectIds.isNotEmpty) {
                if (!loc.subjectIds.contains(activeSession.subjectId)) {
                  // Mismatch: This location doesn't apply to this subject
                  continue;
                }
              }

              final dist = Geolocator.distanceBetween(
                  pos.latitude, pos.longitude, loc.lat, loc.lng);
              debugPrint("Dist: ${dist.toStringAsFixed(1)}m / ${loc.radius}m");
              // Check valid once we have a distance
              checkValid = true;

              if (dist <= loc.radius) {
                present = true;
                debugPrint("BG Service: Entered Geofence: ${loc.name}");
                logGeoStatus = "Inside ${loc.name} (${dist.toInt()}m)";

                // --- ENTRY ALERT CHECK ---
                final alertsEnabled =
                    prefs.getBool('enableGeofenceAlerts') ?? true;
                if (alertsEnabled) {
                  final hasNotifiedEntry =
                      prefs.getBool('notified_entry_${activeSession.id}') ??
                          false;
                  if (!hasNotifiedEntry) {
                    await NotificationService().showInstantNotification(
                      id: activeSession.id.hashCode + 999, // Unique ID
                      title: "You reached campus 📍",
                      body:
                          "Don't forget to mark attendance for ${activeSession.subjectName}",
                      ongoing: false,
                    );
                    await LogService().log(
                        "[TRACE] Notification Pushed: Geofence Entry Alert");
                    await prefs.setBool(
                        'notified_entry_${activeSession.id}', true);
                  }
                }
                // -------------------------
                break;
              }
            }
          } catch (e) {
            debugPrint("Location check error: $e");
            // Do not set checkValid = true, so this attempt won't count against the user
          }
        }
      } else {
        debugPrint(
            "BG Service: Geofence check skipped - Location Permission missing");
        logGeoStatus = "Skipped (No Perm)";
      }
    }

    // Determine Running Stats
    // Determine Running Stats
    // Removed unused currentPresence/currentTotal vars

    // Read current stats before increment (to see previous state) - actually we want AFTER increment
    // Let's do it after logic below.

    // Update Stats ONLY if the check was valid (i.e. we actually know where the user is)
    if (checkValid || present) {
      await _incrementTotalChecks(prefs, activeSession.id);
      if (present) {
        await _incrementPresence(prefs, activeSession.id);

        // --- INSTANT MARK LOGIC (Trust Mode) ---
        // If we found them present, just mark it immediately.
        if (activeSession.status == AttendanceStatus.pending) {
          await _markAttendanceInPrefs(prefs, activeSession.subjectId!,
              activeSession.id, AttendanceStatus.present);
          // Also flag as auto-marked for UI logic
          await prefs.setBool('session_auto_marked_${activeSession.id}', true);
          // Update object for next steps
          activeSession =
              activeSession.copyWith(status: AttendanceStatus.present);
        }
        // ---------------------------------------
      }
    }

    // Fetch updated stats for notification
    final totalChecks = prefs.getInt('total_checks_${activeSession.id}') ?? 1;
    final presenceCount =
        prefs.getInt('presence_count_${activeSession.id}') ?? (present ? 1 : 0);

    // Minimize Main Service Notification to generic text
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: "Attendance Services Active",
        content: "Background monitoring active",
      );
    }

    // Check Preference
    final showStats =
        prefs.getBool('enableBackgroundStatusNotification') ?? true;

    if (showStats) {
      // Construct rich stats for the Live Activity Notification
      final statsString = "$currentAction • $presenceCount/$totalChecks checks";
      try {
        // Determine Source for UI
        String source = "Auto";
        if (logWifiStatus.toLowerCase().contains("match")) source = "WiFi";
        if (logGeoStatus.toLowerCase().contains("inside")) source = "Geofence";

        await LiveActivityService().updateActivityForSession(activeSession,
            stats: statsString, isAutoChoice: present, source: source);
        // Success: Minimize Main Service Notification (or keep context)
        if (service is AndroidServiceInstance) {
          // USER REQUEST: Show tracing details in Background Notification
          // Format: "Traced by WiFi • 3/5 Checks" or "Tracking: Subject • Geo • 1/5"
          String statusMsg =
              "Active • $source • $presenceCount/$totalChecks Checks";
          if (present) {
            statusMsg =
                "Verified by $source • $presenceCount/$totalChecks Checks";
          } else {
            statusMsg =
                "Tracking • $source • $presenceCount/$totalChecks Checks";
          }

          await _updateServiceNotification(service, prefs, statusMsg);
        }
      } catch (e) {
        debugPrint("Rich Notification Failed: $e");
        if (service is AndroidServiceInstance) {
          await _updateServiceNotification(service, prefs,
              "Active • ${activeSession.subjectName} • $statsString");
        }
      }
    } else {
      // If disabled, ensure we remove any existing rich notification
      int idToCancel = activeSession.id.hashCode;
      if (activeSession.templateId != null &&
          activeSession.templateId!.isNotEmpty) {
        idToCancel = activeSession.templateId.hashCode;
      }
      try {
        await NotificationService().cancelType(idToCancel);
      } catch (_) {}
    }

    // --- DETAILED LOGGING FOR DEBUG CONSOLE ---
    // Reuse existing vars if possible, but they are final above.
    // Calculate pct again for clarity or reuse logic?
    // Let's just use the ones defined at line 701/702
    double pct = 0;
    if (totalChecks > 0) pct = (presenceCount / totalChecks) * 100;

    String checkResult = present ? "PRESENT" : "ABSENT";
    if (!checkValid && !present) checkResult = "INVALID/SKIPPED";

    final traceLog = "[TRACE] Class: ${activeSession.subjectName}\n"
        "   > Time: ${DateFormat('HH:mm:ss').format(now)}\n"
        "   > WiFi: $logWifiStatus\n"
        "   > Geo: $logGeoStatus @ $logCoords\n"
        "   > Result: $checkResult\n"
        "   > Stats: $presenceCount/$totalChecks (${pct.toStringAsFixed(1)}%)";

    await LogService().log(traceLog);

    // RECORD HISTORY FOR GRAPH
    await _addToHistory(prefs, activeSession.subjectName, logWifiStatus,
        logGeoStatus, logCoords);
    // ------------------------------------------

    await prefs.setString(
        'last_bg_check_${activeSession.id}', now.toIso8601String());
  }

  static Future<void> _finalizeEndedSessions(
      SharedPreferences prefs, ServiceInstance service) async {
    try {
      final sessionsJson = prefs.getString('sessions');
      if (sessionsJson == null) return;
      List<dynamic> sessionList = jsonDecode(sessionsJson);
      List<ClassSession> sessions =
          sessionList.map((x) => ClassSession.fromJson(x)).toList();

      final now = DateTime.now();
      bool dataChanged = false;

      for (var session in sessions) {
        // Check if session is pending and has ENDED (or is ending right now 1s grace)
        if (session.status == AttendanceStatus.pending &&
            now.add(const Duration(seconds: 5)).isAfter(session.endTime)) {
          final totalKey = 'total_checks_${session.id}';
          final presenceKey = 'presence_count_${session.id}';
          final totalChecks = prefs.getInt(totalKey); // Null if never checked

          debugPrint(
              "BG Service: Finalizing Session Check: ${session.subjectName}");

          if (totalChecks != null && totalChecks > 0) {
            final presence = prefs.getInt(presenceKey) ?? 0;
            final pct = presence / totalChecks;

            debugPrint(
                "Stats for ${session.subjectName}: $presence/$totalChecks checks (${(pct * 100).toStringAsFixed(1)}%)");

            // Threshold: 30% (Very forgiving for WiFi/Geo glitches)
            AttendanceStatus finalStatus = (pct >= 0.3)
                ? AttendanceStatus.present
                : AttendanceStatus.pending;

            await LogService().log(
                "[TRACE] FINALIZING: ${session.subjectName}\n"
                "   > Final Stats: $presence/$totalChecks checks (${(pct * 100).toStringAsFixed(1)}%)\n"
                "   > Decision: ${finalStatus == AttendanceStatus.present ? 'MARKED PRESENT' : 'LEFT PENDING'}");

            if (finalStatus == AttendanceStatus.present) {
              debugPrint("Decision: MARK PRESENT (>=30%)");
              await _markAttendanceInPrefs(prefs, session.subjectId!,
                  session.id, AttendanceStatus.present);

              // Mark as Auto-Marked to suppress "Class Finished"
              await prefs.setBool('session_auto_marked_${session.id}', true);

              // Determine Service Name (Improved Heuristic)
              final wifiStatus = prefs.getString('service_wifi_status') ?? "";
              final geoStatus = prefs.getString('geo_status') ?? "";

              String serviceName = "Smart Attendance"; // Default
              if (wifiStatus.contains("Match")) {
                serviceName = "WiFi";
              } else if (geoStatus.contains("Inside")) {
                serviceName = "Geofence";
              }

              // Trigger Notification Immediately
              try {
                await NotificationService().showInstantNotification(
                  id: session.id.hashCode,
                  title: "Marked Present: ${session.subjectName}",
                  body:
                      "Automatically marked Present by $serviceName service. Tap if incorrect.",
                  ongoing: false,
                  // Show buttons to allow user to change mind
                  showCompletionActions: true,
                  status: AttendanceStatus.present,
                  payload: jsonEncode({
                    // Ensure payload allows action handling
                    'subjectId': session.subjectId,
                    'sessionId': session.id,
                    'action': 'auto_mark_review'
                  }),
                );
                await LogService().log(
                    "[TRACE] Notification Pushed: Auto-Marked Present for ${session.subjectName} by $serviceName");
              } catch (e) {
                debugPrint("Notification Error: $e");
              }
              dataChanged = true;
            } else {
              debugPrint("Decision: DO NOT MARK (Threshold 30% not met)");
              // Below Threshold - Potential Bunk
              final alertsEnabled =
                  prefs.getBool('enableGeofenceAlerts') ?? true;
              final geofenceEnabled = prefs.getBool('enableGeofence') ?? false;
              final wifiEnabled = prefs.getBool('enableWifiTrigger') ?? false;

              if ((geofenceEnabled || wifiEnabled) && alertsEnabled) {
                await NotificationService().showInstantNotification(
                  id: session.id.hashCode,
                  title: "Did you bunk ${session.subjectName}? 🤔",
                  body:
                      "Attendance not verified (<30% detected). Tap to correct.",
                  ongoing: false,
                  showCompletionActions:
                      true, // Allow user to correct it anyway
                  payload: jsonEncode(
                      {'sessionId': session.id, 'action': 'check_bunk'}),
                );
              }
            }
            // Cleanup stats only after processing
            await prefs.remove(totalKey);
            await prefs.remove(presenceKey);
            await prefs.remove('last_bg_check_${session.id}');
          } else {
            debugPrint(
                "BG Service: Session ended but no checks recorded for ${session.subjectName} (Was service running?)");
            // If we have no data, we do nothing. Safe fallback.
          }
        }
      }

      if (dataChanged) {
        await prefs.setBool('bg_data_changed', true);
        service.invoke('bg_data_changed');
      }
    } catch (e) {
      debugPrint("BG Service: Error in finalizeEndedSessions: $e");
    }
  }

  static Future<void> _markAttendanceInPrefs(SharedPreferences prefs,
      String subjectId, String sessionId, AttendanceStatus status) async {
    // 1. Update Subjects
    final sj = prefs.getString('subjects');
    if (sj != null) {
      List<dynamic> sl = jsonDecode(sj);
      List<Subject> subjects = sl.map((x) => Subject.fromJson(x)).toList();
      final idx = subjects.indexWhere((s) => s.id == subjectId);
      if (idx != -1) {
        final s = subjects[idx];
        final newLog = AttendanceLog(
            timestamp: DateTime.now(),
            status: status,
            type: LogType.auto,
            relatedSessionId: sessionId);
        int p = s.present;
        if (status == AttendanceStatus.present) p++;
        subjects[idx] = s.copyWith(present: p, logs: [...s.logs, newLog]);
        await prefs.setString(
            'subjects', jsonEncode(subjects.map((x) => x.toJson()).toList()));
      }
    }
    // 2. Update Sessions
    final sej = prefs.getString('sessions');
    if (sej != null) {
      List<dynamic> sel = jsonDecode(sej);
      List<ClassSession> sessions =
          sel.map((x) => ClassSession.fromJson(x)).toList();
      final sIdx = sessions.indexWhere((s) => s.id == sessionId);
      if (sIdx != -1) {
        sessions[sIdx] = sessions[sIdx].copyWith(status: status);
        await prefs.setString(
            'sessions', jsonEncode(sessions.map((x) => x.toJson()).toList()));
      }
    }
  }

  static Future<void> _incrementPresence(
      SharedPreferences prefs, String sessionId) async {
    final key = 'presence_count_$sessionId';
    final current = prefs.getInt(key) ?? 0;
    await prefs.setInt(key, current + 1);
  }

  static Future<void> _incrementTotalChecks(
      SharedPreferences prefs, String sessionId) async {
    final key = 'total_checks_$sessionId';
    final current = prefs.getInt(key) ?? 0;
    await prefs.setInt(key, current + 1);
  }

  static Future<void> _updateServiceNotification(
      ServiceInstance service, SharedPreferences prefs, String status) async {
    if (service is! AndroidServiceInstance) return;

    final enabled = prefs.getBool('enableBackgroundStatusNotification') ?? true;
    if (enabled) {
      await service.setForegroundNotificationInfo(
        title: "Attendance Services Active",
        content: status,
      );
    } else {
      // Generic fallback
      await service.setForegroundNotificationInfo(
        title: "Attendance Services Active",
        content: "Monitoring schedule...",
      );
    }
  }
}

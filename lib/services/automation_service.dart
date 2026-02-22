import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart'; // Added
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import 'background_service.dart'; // Import explicitly

final automationProvider = Provider<AutomationService>((ref) {
  return AutomationService(ref);
});

class AutomationService {
  final Ref ref;
  Timer? _uiSyncTimer;

  AutomationService(this.ref) {
    _init();
  }

  Future<void> _init() async {
    // 1. Initialize Background Service System
    await MadBackgroundService.initialize();

    // 2. Initial Sync & Start/Stop based on current settings
    final settings = ref.read(settingsProvider);
    _handleSettingsChange(settings);

    // 3. Listen to Settings changes
    ref.listen(settingsProvider, (previous, next) {
      _handleSettingsChange(next);
    });

    // 4. Listen to Attendance changes (to update Outbox for BG service)
    ref.listen(attendanceProvider, (prev, next) {
      // Debounce or just update Outbox
      _updateSyncOutbox(next);
    });

    // 5. Start UI Sync Loop (to finalize attendance if BG marked it, or process Incoming Sync)
    _startUiSync();
  }

  Future<void> _updateSyncOutbox(AttendanceState state) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settings = ref.read(settingsProvider);
      final profile = ref.read(userProfileProvider);

      final fullData = {
        'version': 2,
        'timestamp': DateTime.now().toIso8601String(),
        'attendance': {
          'subjects': state.subjects.map((e) => e.toJson()).toList(),
          'groups': state.groups.map((e) => e.toJson()).toList(),
          'schedule': state.schedule.map((e) => e.toJson()).toList(),
          'sessions': state.sessions.map((e) => e.toJson()).toList(),
        },
        'settings': {
          // Essential settings for sync
          'campusSsids': settings.campusSsids,
          'campusLocations':
              settings.campusLocations.map((l) => l.toJson()).toList(),
          // Add others if needed
        },
        'profile': profile.toJson(),
      };

      await prefs.setString('sync_outbox', jsonEncode(fullData));

      // Wake up Background Service to process potential changes (e.g. Schedule update)
      FlutterBackgroundService().invoke('update');
    } catch (e) {
      debugPrint("Error updating sync outbox: $e");
    }
  }

  void _handleSettingsChange(AppSettings settings) {
    // Sync Settings to Prefs so Background Service can read them
    _syncSettingsToPrefs(settings).then((_) async {
      // Remove '|| true' to respect user settings
      // Also check permissions before starting to avoid crashes
      if (settings.enableGeofence || settings.enableWifiTrigger) {
        bool hasPermissions = false;
        // Basic check: If using Geofence/WiFi we need location
        if (await Permission.location.isGranted) {
          hasPermissions = true;
        }

        final service = FlutterBackgroundService();
        if (hasPermissions) {
          // Double check actual permission status before action
          if (await Permission.location.isGranted) {
            if (await service.isRunning()) {
              debugPrint(
                  "AutomationService: Updating Background Service settings");
              service.invoke('update');
            } else {
              debugPrint(
                  "AutomationService: Starting Background Service (Settings Enabled + Permissions OK)");
              await service.startService();
            }
          } else {
            debugPrint(
                "AutomationService: Permission revoked, stopping service");
            if (await service.isRunning()) {
              service.invoke("stopService");
            }
          }
        } else {
          debugPrint(
              "AutomationService: Cannot start Background Service - Missing Permissions");
        }
      } else {
        // Stop service if features disabled
        final service = FlutterBackgroundService();
        if (await service.isRunning()) {
          service.invoke("stopService");
        }
      }
    });
  }

  Future<void> _syncSettingsToPrefs(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('enableGeofence', settings.enableGeofence);
    await prefs.setBool('enableWifiTrigger', settings.enableWifiTrigger);
    // Persist Sync Toggle if we add one.

    await prefs.setStringList('campusSsids', settings.campusSsids);
    await prefs.setString('campusLocations',
        jsonEncode(settings.campusLocations.map((e) => e.toJson()).toList()));
  }

  void _startUiSync() {
    _uiSyncTimer?.cancel();

    // Listen for events ONLY - No Polling
    FlutterBackgroundService().on('bg_data_changed').listen((event) async {
      debugPrint("UI Sync: Received 'bg_data_changed' signal");
      _processBgChanges();
    });

    // Also perform ONE initial check on startup
    _processBgChanges();
  }

  Future<void> _processBgChanges() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Check for basic BG changes (Attendance Marked)
    if (prefs.getBool('bg_data_changed') == true) {
      debugPrint("UI Sync: Detected background change, reloading...");

      // Check Sync Inbox first!
      final inbox = prefs.getStringList('sync_inbox') ?? [];
      if (inbox.isNotEmpty) {
        debugPrint(
            "UI Sync: Processing ${inbox.length} inbox items from Sync...");
        for (final item in inbox) {
          try {
            Map<String, dynamic> data = jsonDecode(item);
            // Extract 'attendance' part if wrapped in full payload
            if (data.containsKey('attendance')) {
              // Check if it's the full structure
              await ref
                  .read(attendanceProvider.notifier)
                  .mergeSyncData(AttendanceState.fromJson(data['attendance']));
            } else {
              // Maybe direct attendance map?
              await ref
                  .read(attendanceProvider.notifier)
                  .mergeSyncData(AttendanceState.fromJson(data));
            }
          } catch (e) {
            debugPrint("Error processing sync inbox item: $e");
          }
        }
        await prefs.setStringList('sync_inbox', []);
      } else {
        // Just reload from disk if no specific inbox items (e.g. BG marked attendance locally)
        await ref.read(attendanceProvider.notifier).reload();
      }

      await prefs.setBool('bg_data_changed', false);
    }
  }

  void dispose() {
    _uiSyncTimer?.cancel();
  }
}

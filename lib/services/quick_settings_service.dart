import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:quick_settings/quick_settings.dart' as qs;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/notification_service.dart';

class QuickSettingsService {
  static final QuickSettingsService _instance =
      QuickSettingsService._internal();
  factory QuickSettingsService() => _instance;
  QuickSettingsService._internal();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    debugPrint("Initializing QuickSettings Service...");

    qs.QuickSettings.setup(
      onTileClicked: onTileClicked,
      onTileAdded: onTileAdded,
      onTileRemoved: onTileRemoved,
    );

    _initialized = true;
  }
}

@pragma("vm:entry-point")
qs.Tile? onTileClicked(qs.Tile tile) {
  debugPrint("Quick Settings Tile Clicked!");
  _processClick(tile);
  // Return null to indicate no immediate change (since we can't await data)
  // Ideally we would return a "Loading..." tile here if we could.
  return null;
}

Future<void> _processClick(qs.Tile tile) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();

  final sessionsJson = prefs.getString('sessions');
  List<ClassSession> sessions = [];
  if (sessionsJson != null) {
    final List<dynamic> decoded = jsonDecode(sessionsJson);
    sessions = decoded.map((e) => ClassSession.fromJson(e)).toList();
  }

  final subjectsJson = prefs.getString('subjects');
  List<Subject> subjects = [];
  if (subjectsJson != null) {
    final List<dynamic> decoded = jsonDecode(subjectsJson);
    subjects = decoded.map((e) => Subject.fromJson(e)).toList();
  }

  final now = DateTime.now();

  // Find ACTIVE session
  ClassSession? activeSession;
  try {
    final matches = sessions.where((s) =>
        !s.isCancelled && now.isAfter(s.startTime) && now.isBefore(s.endTime));
    if (matches.isNotEmpty) activeSession = matches.first;
  } catch (_) {}

  // Note: We cannot update the tile asynchronously via return here.
  // If the package supports background updates via other means, we should use that.
  // For now, we perform the data updates but can't reflect it on the tile immediately.

  if (activeSession != null) {
    final session = activeSession;
    if (session.status == AttendanceStatus.pending ||
        session.status == AttendanceStatus.absent) {
      final sessIdx = sessions.indexWhere((s) => s.id == session.id);
      if (sessIdx != -1) {
        sessions[sessIdx] = session.copyWith(status: AttendanceStatus.present);
        await prefs.setString(
            'sessions', jsonEncode(sessions.map((e) => e.toJson()).toList()));
      }

      if (session.subjectId != null) {
        final subIdx = subjects.indexWhere((s) => s.id == session.subjectId);
        if (subIdx != -1) {
          final sub = subjects[subIdx];
          final newSubject = sub.copyWith(present: sub.present + 1, logs: [
            ...sub.logs,
            AttendanceLog(
                timestamp: now,
                status: AttendanceStatus.present,
                type: LogType.manual,
                relatedSessionId: session.id)
          ]);
          subjects[subIdx] = newSubject;
          await prefs.setString(
              'subjects', jsonEncode(subjects.map((e) => e.toJson()).toList()));
        }
      }
      NotificationService.triggerReload();
    }
  }
}

@pragma("vm:entry-point")
qs.Tile? onTileAdded(qs.Tile tile) {
  return qs.Tile(
    label: "MadBunky",
    contentDescription: "Mark Attendance",
    tileStatus: qs.TileStatus.inactive,
    drawableName: "ic_launcher",
  );
}

@pragma("vm:entry-point")
void onTileRemoved() {
  // No-op
}

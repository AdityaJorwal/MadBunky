import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // Added for NotificationResponse
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/log_service.dart';
import '../services/notification_service.dart';
import '../services/widget_service.dart';
import '../theme.dart';

import '../utils/globals.dart';
import '../utils/morph_dialog.dart'; // Added for GlassDialogContainer
import '../services/live_activity_service.dart'; // Added for LiveActivityService
import 'package:flutter/foundation.dart'; // Added for defaultTargetPlatform
export 'schedule_log_provider.dart'; // [NEW] Exporting new provider
import '../services/pdf_service.dart';
import 'package:google_sign_in/google_sign_in.dart'; // Added
import '../services/google_calendar_service.dart'; // Added
import '../services/auth_service.dart'; // Added
import '../services/google_drive_service.dart'; // Added
import '../services/backup_service.dart'; // Added

final pdfServiceProvider = Provider<PdfService>((ref) {
  return PdfService();
});

// --- Google Calendar Providers ---
final googleCalendarServiceProvider = Provider<GoogleCalendarService>((ref) {
  final authService = ref.watch(authServiceProvider);
  return GoogleCalendarService(authService.googleSignIn);
});

final userGoogleAccountProvider = StreamProvider<GoogleSignInAccount?>((ref) {
  final service = ref.watch(googleCalendarServiceProvider);
  service.init(); // Ensure init attempts silent sign-in

  // Emit current value immediately (even if null) so UI doesn't hang in 'loading'
  return (() async* {
    yield service.currentUser;
    yield* service.onCurrentUserChanged;
  })();
});

// --- Shared Preferences Provider ---
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

// --- Auth Providers ---
final authServiceProvider = Provider<AuthService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return AuthService(prefs);
});

final authStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

final authRestorationProvider = FutureProvider<void>((ref) async {
  final authService = ref.read(authServiceProvider);
  await authService.restoreSession();
});

// --- Backup & Drive Providers ---
final googleDriveServiceProvider = Provider<GoogleDriveService>((ref) {
  final authService = ref.watch(authServiceProvider);
  return GoogleDriveService(authService.googleSignIn);
});

final backupServiceProvider = Provider<BackupService>((ref) {
  final driveService = ref.watch(googleDriveServiceProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return BackupService(driveService, prefs);
});

// --- Settings Provider ---
class SettingsNotifier extends StateNotifier<AppSettings> {
  final SharedPreferences prefs;
  final BackupService backupService;

  SettingsNotifier(this.prefs, this.backupService) : super(AppSettings()) {
    _loadSettings();
  }

  void _loadSettings() {
    final themeIndex = prefs.getInt('themeMode') ?? 2;
    int themePresetIndex = prefs.getInt('themePreset') ?? 0;

    if (themePresetIndex >= ThemePreset.values.length) {
      themePresetIndex = 0;
    }

    final useMaterialYou = prefs.getBool('useMaterialYou') ?? true;
    final showCalendar = prefs.getBool('showCalendar') ?? true;
    final enableNotifications = prefs.getBool('enableNotifications') ?? true;
    final enableSmartBunking = prefs.getBool('enableSmartBunking') ?? true;
    final enableGeofence = prefs.getBool('enableGeofence') ?? false;
    final enableWifiTrigger = prefs.getBool('enableWifiTrigger') ?? false;
    final enableHolidayAwareness =
        prefs.getBool('enableHolidayAwareness') ?? false;
    final enableLiveActivity = prefs.getBool('enableLiveActivity') ?? false;
    final enableClassAlerts = prefs.getBool('enableClassAlerts') ?? true;
    final enableSilentNotifications =
        prefs.getBool('enableSilentNotifications') ?? false;
    final enableBackgroundStatusNotification =
        prefs.getBool('enableBackgroundStatusNotification') ?? true;

    final customThemeColor = prefs.getInt('customThemeColor');
    final isNeon = prefs.getBool('isNeon') ?? false; // Added

    // Load SSIDs
    final campusSsids = prefs.getStringList('campusSsids') ?? [];

    // Load Locations (JSON List)
    final locationsJson = prefs.getString('campusLocations');
    List<LocationItem> campusLocations = [];
    if (locationsJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(locationsJson);
        campusLocations = decoded.map((e) => LocationItem.fromJson(e)).toList();
      } catch (e) {
        debugPrint("Error loading locations: $e");
      }
    }

    // Migration attempt (Optional: if old keys exist, migrate them)
    // Checking literal old keys
    if (campusLocations.isEmpty && prefs.containsKey('campusLat')) {
      final lat = prefs.getDouble('campusLat');
      final lng = prefs.getDouble('campusLng');
      final rad = prefs.getDouble('campusGeofenceRadius') ?? 200.0;
      if (lat != null && lng != null) {
        campusLocations.add(LocationItem(
          name: "Main Campus",
          lat: lat,
          lng: lng,
          radius: rad,
        ));
      }
    }
    if (campusSsids.isEmpty && prefs.containsKey('campusSsid')) {
      final ssid = prefs.getString('campusSsid');
      if (ssid != null) {
        campusSsids.add(ssid);
      }
    }

    state = AppSettings(
      themeMode: ThemeType.values[themeIndex],
      themePreset: ThemePreset.values[themePresetIndex],
      useMaterialYou: useMaterialYou,
      showCalendar: showCalendar,
      enableNotifications: enableNotifications,
      enableSmartBunking: enableSmartBunking,
      enableGeofence: enableGeofence,
      enableWifiTrigger: enableWifiTrigger,
      enableHolidayAwareness: enableHolidayAwareness,
      enableLiveActivity: enableLiveActivity,
      enableClassAlerts: enableClassAlerts,
      enableSilentNotifications: enableSilentNotifications,
      enableBackgroundStatusNotification: enableBackgroundStatusNotification,
      enableGeofenceAlerts: prefs.getBool('enableGeofenceAlerts') ?? true,
      enableBatterySaver: prefs.getBool('enableBatterySaver') ?? false,
      campusSsids: campusSsids,
      campusLocations: campusLocations,
      customThemeColor: customThemeColor,

      autoSyncGoogleCalendar:
          prefs.getBool('autoSyncGoogleCalendar') ?? false, // Added
      isNeon: isNeon, // Added
    );
  }

  Future<void> toggleAutoSyncGoogleCalendar(bool value) async {
    state = state.copyWith(autoSyncGoogleCalendar: value);
    await prefs.setBool('autoSyncGoogleCalendar', value);
  }

  Future<void> updateThemeMode(ThemeType theme) async {
    state = state.copyWith(themeMode: theme);
    await prefs.setInt('themeMode', theme.index);
  }

  Future<void> updateThemePreset(ThemePreset preset) async {
    final bool shouldUseMaterialYou = (preset == ThemePreset.system);
    state = state.copyWith(
        themePreset: preset, useMaterialYou: shouldUseMaterialYou);
    await prefs.setInt('themePreset', preset.index);
    await prefs.setBool('useMaterialYou', shouldUseMaterialYou);
  }

  Future<void> setCustomThemeColor(Color color) async {
    state = state.copyWith(
        customThemeColor: color.toARGB32(), themePreset: ThemePreset.custom);
    await prefs.setInt('customThemeColor', color.toARGB32());
    await prefs.setInt('themePreset', ThemePreset.custom.index);
  }

  Future<void> toggleNeon(bool value) async {
    state = state.copyWith(isNeon: value);
    await prefs.setBool('isNeon', value);
  }

  Future<void> toggleMaterialYou(bool value) async {
    state = state.copyWith(useMaterialYou: value);
    await prefs.setBool('useMaterialYou', value);
  }

  Future<void> toggleCalendar(bool value) async {
    state = state.copyWith(showCalendar: value);
    await prefs.setBool('showCalendar', value);
  }

  Future<void> toggleBackgroundStatusNotification(bool value) async {
    state = state.copyWith(enableBackgroundStatusNotification: value);
    await prefs.setBool('enableBackgroundStatusNotification', value);
    FlutterBackgroundService().invoke("update");
  }

  Future<void> toggleGeofenceAlerts(bool value) async {
    state = state.copyWith(enableGeofenceAlerts: value);
    await prefs.setBool('enableGeofenceAlerts', value);
    FlutterBackgroundService().invoke("update");
  }

  Future<void> toggleBatterySaver(bool value) async {
    debugPrint("SettingsNotifier: Toggling Battery Saver to $value");
    state = state.copyWith(enableBatterySaver: value);
    try {
      final success = await prefs.setBool('enableBatterySaver', value);
      debugPrint(
          "SettingsNotifier: Persisted 'enableBatterySaver' = $value, success: $success");
    } catch (e) {
      debugPrint("SettingsNotifier: Error persisting 'enableBatterySaver': $e");
    }

    try {
      FlutterBackgroundService().invoke("update");
    } catch (e) {
      debugPrint("Error updating BG Service: $e");
    }
  }

  void toggleAutoBackup(bool enable) {
    state = state.copyWith(enableAutoBackup: enable);
    prefs.setBool('enableAutoBackup', enable);
    if (enable) {
      backupService.triggerAutoBackup();
    }
  }

  // --- Multi-SSID Logic ---

  Future<void> addCampusSsid(String ssid) async {
    if (state.campusSsids.contains(ssid)) return;
    final newSsids = [...state.campusSsids, ssid];
    state = state.copyWith(campusSsids: newSsids);
    await prefs.setStringList('campusSsids', newSsids);
  }

  Future<void> removeCampusSsid(String ssid) async {
    final newSsids = state.campusSsids.where((s) => s != ssid).toList();
    state = state.copyWith(campusSsids: newSsids);
    await prefs.setStringList('campusSsids', newSsids);
  }

  // --- Multi-Location Logic ---

  Future<void> addCampusLocation(LocationItem item) async {
    final newLocations = [...state.campusLocations, item];
    state = state.copyWith(campusLocations: newLocations);
    await _saveLocations(newLocations);
  }

  Future<void> updateCampusLocation(LocationItem item) async {
    final index = state.campusLocations.indexWhere((l) => l.id == item.id);
    if (index != -1) {
      final newLocations = List<LocationItem>.from(state.campusLocations);
      newLocations[index] = item;
      state = state.copyWith(campusLocations: newLocations);
      await _saveLocations(newLocations);
    }
  }

  Future<void> removeCampusLocation(String id) async {
    final newLocations =
        state.campusLocations.where((l) => l.id != id).toList();
    state = state.copyWith(campusLocations: newLocations);
    await _saveLocations(newLocations);
  }

  Future<void> _saveLocations(List<LocationItem> locations) async {
    final jsonString = jsonEncode(locations.map((e) => e.toJson()).toList());
    await prefs.setString('campusLocations', jsonString);
  }

  Future<void> toggleNotifications(bool value) async {
    state = state.copyWith(enableNotifications: value);
    await prefs.setBool('enableNotifications', value);
    if (!value) {
      await NotificationService().cancelAll();
      if (state.enableLiveActivity) {
        toggleLiveActivity(false);
      }
    }
  }

  Future<void> toggleClassAlerts(bool value) async {
    state = state.copyWith(enableClassAlerts: value);
    await prefs.setBool('enableClassAlerts', value);
  }

  Future<void> toggleSilentNotifications(bool value) async {
    state = state.copyWith(enableSilentNotifications: value);
    await prefs.setBool('enableSilentNotifications', value);
  }

  Future<void> toggleSmartBunking(bool value) async {
    state = state.copyWith(enableSmartBunking: value);
    await prefs.setBool('enableSmartBunking', value);
  }

  Future<void> toggleGeofence(bool value) async {
    state = state.copyWith(enableGeofence: value);
    await prefs.setBool('enableGeofence', value);
    if (value) {
      await FlutterBackgroundService().startService();
    }
    FlutterBackgroundService().invoke("update");
  }

  Future<void> toggleWifiTrigger(bool value) async {
    state = state.copyWith(enableWifiTrigger: value);
    await prefs.setBool('enableWifiTrigger', value);
    if (value) {
      await FlutterBackgroundService().startService();
    }
    FlutterBackgroundService().invoke("update");
  }

  Future<void> toggleHolidayAwareness(bool value) async {
    state = state.copyWith(enableHolidayAwareness: value);
    await prefs.setBool('enableHolidayAwareness', value);
  }

  Future<void> toggleLiveActivity(bool value) async {
    if (value) {
      // 1. Ask for Notification Permission first
      final nStatus = await Permission.notification.request();
      if (!nStatus.isGranted) {
        return; // Do not enable if permission denied
      }

      // 2. Ask for Battery Optimization (Background Activity)
      // This is less critical to block enabling, but good to ask
      final bStatus = await Permission.ignoreBatteryOptimizations.status;
      if (!bStatus.isGranted) {
        await Permission.ignoreBatteryOptimizations.request();
      }
    }

    state = state.copyWith(enableLiveActivity: value);
    await prefs.setBool('enableLiveActivity', value);

    if (value) {
      await FlutterBackgroundService().startService();
    }
    FlutterBackgroundService().invoke("update");
    if (!value) {
      await NotificationService().cancelAll();
    }
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((
  ref,
) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final backupService = ref.watch(backupServiceProvider);
  return SettingsNotifier(prefs, backupService);
});

// --- Debug Log Provider (Temporary) ---
class DebugLogNotifier extends StateNotifier<List<String>> {
  DebugLogNotifier() : super([]);

  void addLog(String message) {
    final time =
        DateTime.now().toIso8601String().split('T').last.split('.').first;
    state = ["[$time] $message", ...state];
  }

  void clear() {
    state = [];
  }
}

final debugLogsProvider =
    StateNotifierProvider<DebugLogNotifier, List<String>>((ref) {
  return DebugLogNotifier();
});

// --- User Profile Provider ---
class UserProfileNotifier extends StateNotifier<UserProfile> {
  final SharedPreferences prefs;

  UserProfileNotifier(this.prefs)
      : super(const UserProfile(name: '', institute: '')) {
    _loadProfile();
  }

  void _loadProfile() {
    final name = prefs.getString('userName') ?? '';
    final institute = prefs.getString('userInstitute') ?? '';
    state = UserProfile(name: name, institute: institute);
  }

  Future<void> updateProfile(String name, String institute) async {
    state = UserProfile(name: name, institute: institute);
    // Persist
    await prefs.setString('userName', name);
    await prefs.setString('userInstitute', institute);
  }
}

final userProfileProvider =
    StateNotifierProvider<UserProfileNotifier, UserProfile>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return UserProfileNotifier(prefs);
});

// --- Saved Schedule Provider ---
class SavedScheduleNotifier extends StateNotifier<List<File>> {
  SavedScheduleNotifier() : super([]) {
    _init();
  }

  Future<void> _init() async {
    await _migrateOldSchedule();
    await _loadSchedules();
  }

  Future<void> _migrateOldSchedule() async {
    final dir = await getApplicationDocumentsDirectory();
    final oldFile = File('${dir.path}/saved_schedule.jpg');
    if (await oldFile.exists()) {
      final newDir = Directory('${dir.path}/schedules');
      if (!await newDir.exists()) {
        await newDir.create(recursive: true);
      }
      // Move to new location with default name
      await oldFile.rename('${newDir.path}/My Schedule.jpg');
    }
  }

  Future<void> _loadSchedules() async {
    final dir = await getApplicationDocumentsDirectory();
    final scheduleDir = Directory('${dir.path}/schedules');

    if (!await scheduleDir.exists()) {
      await scheduleDir.create(recursive: true);
      state = [];
      return;
    }

    final List<FileSystemEntity> entities = scheduleDir.listSync();
    final List<File> files = entities
        .whereType<File>()
        .where((f) =>
            f.path.toLowerCase().endsWith('.jpg') ||
            f.path.toLowerCase().endsWith('.png'))
        .toList();

    // Sort by modification time desc
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

    state = files;
  }

  Future<void> save(String sourcePath, String name) async {
    final dir = await getApplicationDocumentsDirectory();
    final scheduleDir = Directory('${dir.path}/schedules');
    if (!await scheduleDir.exists()) {
      await scheduleDir.create(recursive: true);
    }

    // Sanitize name
    final safeName = name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '');
    final target = File('${scheduleDir.path}/$safeName.jpg');

    await File(sourcePath).copy(target.path);
    await _loadSchedules();
  }

  Future<void> delete(File file) async {
    if (await file.exists()) {
      await file.delete();
      await _loadSchedules();
    }
  }

  Future<void> rename(File file, String newName) async {
    if (await file.exists()) {
      final dir = file.parent;
      final safeName = newName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '');
      final newPath = '${dir.path}/$safeName.jpg';
      await file.rename(newPath);
      await _loadSchedules();
    }
  }

  Future<void> notifyChanged() async {
    await _loadSchedules();
  }
}

final savedScheduleProvider =
    StateNotifierProvider<SavedScheduleNotifier, List<File>>((ref) {
  return SavedScheduleNotifier();
});

// --- Main Tab Provider (Navigation Control) ---
final mainTabProvider = StateProvider<int>((ref) => 0);

final madnessScoreProvider = Provider<double>((ref) {
  final attendance = ref.watch(attendanceProvider);

  double totalWeightedScore = 0;
  double totalWeight = 0;

  for (final subject in attendance.subjects) {
    if (subject.total == 0) continue;

    final target = subject.targetPercentage;
    final currentPct = subject.currentPercentage;
    final isSafe = currentPct >= target;

    final double P = subject.present.toDouble();
    final double X = subject.proxy.toDouble();
    final double A = subject.absent.toDouble();
    final double total = subject.total.toDouble();

    // User Criteria:
    // 1. Proxy: Always in favour (2x).
    // 2. Present: Above Target (Safe) -> Against (-1). Below Target (Danger) -> In favour (+1).
    // 3. Absent: Above Target (Safe) -> In favour (+1). Below Target (Danger) -> Against (-1).

    double rawSubjectScore = 0;

    if (isSafe) {
      // Safe Zone: Laziness/Efficiency is rewarded
      // Proxy (+2), Absent (+1), Present (-1: Simp penalty)
      rawSubjectScore = (2.0 * X) + (1.0 * A) - (1.0 * P);
    } else {
      // Danger Zone: Attendance is rewarded
      // Proxy (+2), Present (+2), Absent (-2: Penalty)
      rawSubjectScore = (2.0 * X) + (2.0 * P) - (2.0 * A);
    }

    // Normalization Logic
    // Max Possible Raw Score (100% Proxy): 2 * total
    // Min Possible Raw Score (Depends on context, but mapped to -total for 0%)
    // Range Width = 3 * total.
    // Shifted Score = Raw + total. (Range 0 to 3*total).

    double normalizedSubjectScore =
        ((rawSubjectScore + total) / (3.0 * total)) * 100;

    // Clamp to 0-100 just in case
    normalizedSubjectScore = normalizedSubjectScore.clamp(0.0, 100.0);

    // Weight by Subject Importance (Total Classes)
    // More classes = More impact on overall %
    double weight = total > 0 ? (total / 10.0) : 0.5; // Scale via 10 classes
    if (weight > 2.0) weight = 2.0; // Cap weight

    totalWeightedScore += normalizedSubjectScore * weight;
    totalWeight += weight;
  }

  if (totalWeight == 0 || attendance.subjects.isEmpty) return 0.0;

  return totalWeightedScore / totalWeight;
});

// --- Attendance Provider ---
class AttendanceState {
  final List<Subject> subjects;
  final List<Group> groups;
  final List<ScheduleTemplate> schedule; // Templates
  final List<ClassSession> sessions; // Concrete sessions
  final Set<String>
      expandedGroupIds; // UI State persisted in memory (or prefs if we want)

  AttendanceState({
    this.subjects = const [],
    this.groups = const [],
    this.schedule = const [],
    this.sessions = const [],
    this.expandedGroupIds = const {},
  });

  Map<String, dynamic> toJson() => {
        'subjects': subjects.map((e) => e.toJson()).toList(),
        'groups': groups.map((e) => e.toJson()).toList(),
        'schedule': schedule.map((e) => e.toJson()).toList(),
        'sessions': sessions.map((e) => e.toJson()).toList(),
      };

  factory AttendanceState.fromJson(Map<String, dynamic> json) {
    return AttendanceState(
      subjects: json['subjects'] != null
          ? (json['subjects'] as List).map((e) => Subject.fromJson(e)).toList()
          : [],
      groups: json['groups'] != null
          ? (json['groups'] as List).map((e) => Group.fromJson(e)).toList()
          : [],
      schedule: json['schedule'] != null
          ? (json['schedule'] as List)
              .map((e) => ScheduleTemplate.fromJson(e))
              .toList()
          : [],
      sessions: json['sessions'] != null
          ? (json['sessions'] as List)
              .map((e) => ClassSession.fromJson(e))
              .toList()
          : [],
    );
  }

  AttendanceState copyWith({
    List<Subject>? subjects,
    List<Group>? groups,
    List<ScheduleTemplate>? schedule,
    List<ClassSession>? sessions,
    Set<String>? expandedGroupIds,
  }) {
    return AttendanceState(
      subjects: subjects ?? this.subjects,
      groups: groups ?? this.groups,
      schedule: schedule ?? this.schedule,
      sessions: sessions ?? this.sessions,
      expandedGroupIds: expandedGroupIds ?? this.expandedGroupIds,
    );
  }
}

class AttendanceNotifier extends StateNotifier<AttendanceState>
    with WidgetsBindingObserver {
  final SharedPreferences prefs;
  final BackupService backupService; // Added

  // Universal Undo/Redo history
  final List<AttendanceState> _undoStack = [];
  final List<AttendanceState> _redoStack = [];

  // Scoped Undo/Redo (Per Subject Link)
  // Map<SubjectID, List<SubjectSnapshot>>
  final Map<String, List<Subject>> _subjectUndoStack = {};
  final Map<String, List<Subject>> _subjectRedoStack = {};

  bool _isFirstLoad = true; // NEW: Track first load to force notification sync

  StreamSubscription? _actionSub;

  Timer? _liveActivityTimer;

  AttendanceNotifier(this.prefs, this.backupService)
      : super(AttendanceState(
            subjects: [], groups: [], schedule: [], sessions: [])) {
    // Register Lifecycle Observer
    WidgetsBinding.instance.addObserver(this);

    loadData(); // Public method
    _startLiveActivityTimer();
    // Subscribe to notification actions
    _actionSub =
        NotificationService.actionStream.listen(handleBackgroundAction);
  }

  @override
  void dispose() {
    _liveActivityTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _actionSub?.cancel();
    super.dispose();
  }

  Future<void> mergeSyncData(AttendanceState newState) async {
    _registerUndo();
    // Intelligent merging logic
    // We want to merge updated items while preserving local changes if possible.
    // For now, let's assume "latest wins" or "merge lists".

    // Merging Subjects (Union by ID)
    final Map<String, Subject> mergedSubjects = {
      for (var s in state.subjects) s.id: s
    };
    for (var s in newState.subjects) {
      if (mergedSubjects.containsKey(s.id)) {
        // Conflict resolution: prefer the one with more logs? Or newer?
        // Let's take the incoming state as truth for sync (Server/Peer wins)
        mergedSubjects[s.id] = s;
      } else {
        mergedSubjects[s.id] = s;
      }
    }

    // Merging Groups
    final Map<String, Group> mergedGroups = {
      for (var g in state.groups) g.id: g
    };
    for (var g in newState.groups) {
      mergedGroups[g.id] = g;
    }

    // Merging Schedule Templates
    final Map<String, ScheduleTemplate> mergedSchedule = {
      for (var s in state.schedule) s.id: s
    };
    for (var s in newState.schedule) {
      mergedSchedule[s.id] = s;
    }

    // Merging Sessions
    final Map<String, ClassSession> mergedSessions = {
      for (var s in state.sessions) s.id: s
    };
    for (var s in newState.sessions) {
      mergedSessions[s.id] = s;
    }

    state = state.copyWith(
      subjects: mergedSubjects.values.toList(),
      groups: mergedGroups.values.toList(),
      schedule: mergedSchedule.values.toList(),
      sessions: mergedSessions.values.toList(),
    );

    await _saveData();
    debugPrint("Sync Merge Completed.");
  }

  void _startLiveActivityTimer() async {
    // Replaced the battery-draining 1-second periodic timer.
    // We now rely purely on Android's native Chronometer for real-time countdowns.
    // We run a single check here on provider initialization to ensure State/Notification sync.

    final enableLiveActivity = prefs.getBool('enableLiveActivity') ?? false;
    if (!enableLiveActivity) return;

    final now = DateTime.now();
    // Find currently ongoing session
    ClassSession? ongoingSession;
    try {
      ongoingSession = state.sessions.cast<ClassSession?>().firstWhere(
            (s) =>
                s != null &&
                s.startTime.isBefore(now) &&
                s.endTime.isAfter(now) &&
                !s.isCancelled,
            orElse: () => null,
          );
    } catch (_) {}

    if (ongoingSession != null) {
      await LiveActivityService().updateActivityForSession(ongoingSession);
    } else {
      await LiveActivityService().updateActivityForSession(null);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint(
          "App Resumed: Forcing Reload to sync with Background Service...");
      reload();
    }
  }

  void handleBackgroundAction(NotificationResponse response) async {
    debugPrint(
        "AttendanceNotifier: Handling background action ${response.actionId} - Reloading from disk...");

    // Removed artificial delay as background write is awaited.
    await reload();

    // Parse Payload to Map safely
    Map<String, dynamic> payloadMap = {};
    if (response.payload != null) {
      try {
        payloadMap = jsonDecode(response.payload!);
      } catch (_) {
        // Fallback for non-JSON payloads (should be rare now)
        if (response.payload == 'ask_bunking') {
          payloadMap = {'action': 'ask_bunking'};
        } else {
          debugPrint(
              "Warning: Could not parse payload as JSON: ${response.payload}");
        }
      }
    }

    // Handle Smart Bunking Check
    if (payloadMap['action'] == 'ask_bunking') {
      final context = navigatorKey.currentState?.overlay?.context;
      if (context != null) {
        if (!context.mounted) return;
        showMorphDialog(
          context: context,
          builder: (ctx) => GlassDialogContainer(
            title: "Bunking Today?",
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                },
                child: const Text("No, I'm here"),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  markDayAsAbsent();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: const Text("All classes marked as Absent 🛌"),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ));
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.pastelRed,
                  foregroundColor: Colors.white,
                ),
                child: const Text("Yes, Mass Bunk"),
              ),
            ],
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                "You seem to be away from campus. Would you like to mark all remaining classes as Absent?",
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        );
      }
      return;
    }

    // --- OPTIMISTIC UPDATE (Fix Flicker) ---
    // Update local state immediately so Timer/UI reflects change even if disk reload is stale
    if (payloadMap.containsKey('sessionId')) {
      final sid = payloadMap['sessionId'];
      final action = response.actionId;
      AttendanceStatus? newStatus;
      if (action == 'mark_present') newStatus = AttendanceStatus.present;
      if (action == 'mark_absent') newStatus = AttendanceStatus.absent;
      if (action == 'mark_proxy') newStatus = AttendanceStatus.proxy;

      if (newStatus != null) {
        // Fix: Use markAttendance to ensure Subject Stats (Present/Absent counts) are also updated!
        // Previously we only updated the Session status, causing stats to desync (e.g. -1 present).
        try {
          final session = state.sessions.firstWhere((s) => s.id == sid);
          debugPrint(
              "AttendanceNotifier: Action $action -> Updating session $sid to $newStatus");
          await markAttendance(session.startTime, null, session, newStatus);
        } catch (e) {
          debugPrint("Could not find session $sid for manual action: $e");
        }
      }
    }

    // Show visual feedback if app is in foreground
    try {
      final context = navigatorKey.currentState?.overlay?.context;
      if (context != null) {
        String message = "Attendance Updated";
        if (response.actionId == 'mark_present') {
          message = "Marked Present via Notification";
        } else if (response.actionId == 'mark_absent') {
          message = "Marked Absent via Notification";
        } else if (response.actionId == 'mark_proxy') {
          message = "Marked Proxy via Notification";
        }

        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }

      // Explicit Confirmation Notification (User Requested Loop: Action -> App -> Notification)
      if (payloadMap.isNotEmpty) {
        final templateId = payloadMap['templateId'];
        final sessionId = payloadMap['sessionId'];

        int notificationId = 99999;
        if (templateId != null && (templateId as String).isNotEmpty) {
          notificationId = templateId.hashCode;
        } else if (sessionId != null) {
          notificationId = sessionId.hashCode;
        }

        String statusText = "Updated";
        if (response.actionId == 'mark_present') statusText = "Present ✅";
        if (response.actionId == 'mark_absent') statusText = "Absent ❌";
        if (response.actionId == 'mark_proxy') statusText = "Proxy 🙋‍♂️";

        // Update the notification one last time from Main Isolate to confirm Sync
        // Use Rich Notification if session found
        ClassSession? associatedSession;
        try {
          associatedSession = state.sessions.firstWhere((s) {
            if (s.id == sessionId) return true;
            if (s.templateId == templateId && templateId != null) return true;
            return false;
          });
        } catch (_) {}

        if (associatedSession != null) {
          final now = DateTime.now();
          final start = associatedSession.startTime;
          final end = associatedSession.endTime;
          final total = end.difference(start).inMinutes;
          final elapsed = now.difference(start).inMinutes;
          int currentlyProgress = 0;
          if (total > 0) {
            currentlyProgress = ((elapsed / total) * 100).toInt().clamp(0, 100);
          }

          String remainingStr = "";
          Duration remaining = end.difference(now);
          if (remaining.isNegative) remaining = Duration.zero;
          if (remaining.inHours > 0) {
            remainingStr =
                "${remaining.inHours}h ${remaining.inMinutes.remainder(60)}m left";
          } else {
            remainingStr = "${remaining.inMinutes}m left";
          }

          await NotificationService().showInstantNotification(
            id: notificationId, // Keep Sticky ID
            title: "Ongoing: ${associatedSession.subjectName}",
            body: "$remainingStr • $currentlyProgress% • Status: $statusText",
            ongoing: true, // Keep it sticky as requested
            showProgress: true,
            progress: currentlyProgress,
            maxProgress: 100,
            indeterminate: false,
            payload: response.payload!, // Pass original JSON string
            when: start.millisecondsSinceEpoch,
            subjectName: associatedSession.subjectName,
            teacherName: associatedSession.teacherName,
            sessionStartTime: TimeOfDay.fromDateTime(start),
            sessionEndTime: TimeOfDay.fromDateTime(end),
            status:
                associatedSession.status, // Should be updated in state by now
            useChronometer: true,
            chronometerCountDown: true,
          );
        } else {
          // Fallback if session not found in state (rare)
          await NotificationService().flutterLocalNotificationsPlugin.show(
                notificationId,
                "Class Updated",
                "Marked as $statusText",
                NotificationDetails(
                  android: AndroidNotificationDetails(
                    'class_channel_config_v5',
                    'Class Notifications',
                    importance: Importance.max,
                    priority: Priority.high,
                    ongoing: false,
                    autoCancel: true,
                  ),
                ),
              );
        }
      }
    } catch (e) {
      debugPrint("Could not show snackbar or update notification: $e");
    }
  }

  // ... (Load Data helpers remain same) ...

  Future<void> loadData() async {
    await prefs.reload();
    final subjectsJson = prefs.getString('subjects');
    final groupsJson = prefs.getString('groups');
    final scheduleJson = prefs.getString('schedule');
    final sessionsJson = prefs.getString('sessions');

    List<Subject> loadedSubjects = [];
    if (subjectsJson != null) {
      final List<dynamic> decoded = jsonDecode(subjectsJson);
      loadedSubjects = decoded.map((e) => Subject.fromJson(e)).toList();
    }

    List<Group> loadedGroups = [];
    if (groupsJson != null) {
      final List<dynamic> decoded = jsonDecode(groupsJson);
      loadedGroups = decoded.map((e) => Group.fromJson(e)).toList();
    }

    List<ScheduleTemplate> loadedSchedule = [];
    if (scheduleJson != null) {
      final List<dynamic> decoded = jsonDecode(scheduleJson);
      loadedSchedule =
          decoded.map((e) => ScheduleTemplate.fromJson(e)).toList();
    }

    List<ClassSession> loadedSessions = [];
    if (sessionsJson != null) {
      final List<dynamic> decoded = jsonDecode(sessionsJson);
      loadedSessions = decoded.map((e) => ClassSession.fromJson(e)).toList();
    }

    // Deduplicate Sessions (Fix for Ghost Entries)
    loadedSessions = _deduplicateSessions(loadedSessions);

    state = AttendanceState(
      subjects: loadedSubjects,
      groups: loadedGroups,
      schedule: loadedSchedule,
      sessions: loadedSessions,
    );

    // Force Migration OR First Load Cleanup: Cancel all old notifications and re-schedule
    // This ensures that on App Startup, we have a clean slate matching "Reschedule All" behavior.
    final bool migrated = prefs.getBool('migrated_to_payload_v3') ?? false;

    if (!migrated || _isFirstLoad) {
      debugPrint("Fresh Notification Sync (First Load or Migration)...");
      await NotificationService().cancelAll();
      _isFirstLoad = false;
      if (!migrated) {
        await prefs.setBool('migrated_to_payload_v3', true);
      }
    }

    // Always Schedule (Now on clean slate if first load)
    for (var item in loadedSchedule) {
      await _scheduleNotification(item);
    }

    // 2. Schedule specific Sessions (Today/Future override) logic - critical for Action reliability
    final now = DateTime.now();
    final pendingSessions = loadedSessions.where((s) =>
            s.status == AttendanceStatus.pending &&
            !s.isCancelled &&
            s.endTime.isAfter(now) // Only future/ongoing
        );

    for (var session in pendingSessions) {
      await _scheduleSessionNotification(session);
    }

    try {
      // Also load backup path if needed?
    } catch (e) {
      debugPrint("Error loading data: $e");
    }
  }

  Future<void> importSchedule(List<ScheduleTemplate> newTemplates) async {
    _registerUndo();
    final updatedSchedule = [...state.schedule, ...newTemplates];
    state = state.copyWith(schedule: updatedSchedule);
    await _saveData();
    // Schedule notifications for new templates
    for (var item in newTemplates) {
      await _scheduleNotification(item);
    }
  }

  Future<void> importSessions(List<ClassSession> newSessions) async {
    _registerUndo();
    final updatedSessions = [...state.sessions, ...newSessions];
    state = state.copyWith(sessions: updatedSessions);
    await _saveData();
    for (var session in newSessions) {
      await _scheduleSessionNotification(session);
    }
  }

  Future<void> reload() async {
    await prefs.reload();
    await loadData();
  }

  int _lastUpdateTime = 0;

  Future<void> _saveData() async {
    // Lamport Clock Logic:
    // Ensure the new timestamp is strictly greater than the last known timestamp (local or remote).
    // This solves the issue where a device with a lagging clock cannot update a device with a leading clock.
    int now = DateTime.now().millisecondsSinceEpoch;
    if (now <= _lastUpdateTime) {
      now = _lastUpdateTime + 1;
    }
    _lastUpdateTime = now;
    final subjectsJson = jsonEncode(
      state.subjects.map((e) => e.toJson()).toList(),
    );
    final groupsJson = jsonEncode(state.groups.map((e) => e.toJson()).toList());
    final scheduleJson =
        jsonEncode(state.schedule.map((e) => e.toJson()).toList());
    final sessionsJson =
        jsonEncode(state.sessions.map((e) => e.toJson()).toList());
    await prefs.setString('subjects', subjectsJson);
    await prefs.setString('groups', groupsJson);
    await prefs.setString('schedule', scheduleJson);
    await prefs.setString('sessions', sessionsJson);
    try {
      await WidgetService.updateMyDayWidget(state.sessions, state.schedule,
          subjects: state.subjects);
    } catch (e) {
      debugPrint("Failed to update widget: $e");
    }

    // Trigger Background Service Update (Wake up/Sync)
    try {
      FlutterBackgroundService().invoke('update');
      // Trigger Auto-Backup
      backupService.triggerAutoBackup();
    } catch (e) {
      debugPrint("Failed to invoke BG service update or backup: $e");
    }

    // Update Live Activity (iOS)
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        final now = DateTime.now();
        ClassSession? activeSession;
        try {
          // Find currently active session
          activeSession = state.sessions.firstWhere((s) =>
              !s.isCancelled &&
              now.isAfter(s.startTime) &&
              now.isBefore(s.endTime) &&
              s.status !=
                  AttendanceStatus
                      .present && // Optional: End activity if marked present?
              // Actually users might want to see it until class ends.
              // But maybe update status?
              // Let's just show active session regardless of status,
              // but the Live Activity display logic (in native) handles status text.
              true);
        } catch (_) {}

        // Pass to Service (it handles null by ending activity)
        // We need to import LiveActivityService or use a helper.
        // Ideally we inject it, but singleton is used.
        await LiveActivityService().updateActivityForSession(activeSession);
      } catch (e) {
        debugPrint("Failed to update Live Activity: $e");
      }
    }
  }

  // --- Sync Helpers ---

  // --- Universal Undo Helpers ---

  void _registerUndo() {
    // Limit stack size
    if (_undoStack.length >= 20) {
      _undoStack.removeAt(0);
    }
    // Create a DEEP snapshot to prevent reference mutation issues
    final snapshot = AttendanceState(
      subjects:
          state.subjects.map((s) => s.copyWith(logs: List.of(s.logs))).toList(),
      groups: state.groups
          .map((g) => g.copyWith(subjectIds: List.of(g.subjectIds)))
          .toList(),
      schedule: List.of(state.schedule),
      sessions: List.of(state.sessions),
    );
    _undoStack.add(snapshot);
    _redoStack.clear();
  }

  Future<void> undo() async {
    if (_undoStack.isNotEmpty) {
      final previousState = _undoStack.removeLast();
      _redoStack.add(state);
      state = previousState;
      await _saveData();
    }
  }

  Future<void> redo() async {
    if (_redoStack.isNotEmpty) {
      final nextState = _redoStack.removeLast();
      _undoStack.add(state);
      state = nextState;
      await _saveData();
    }
  }

  Future<List<String>> rescheduleAllNotifications() async {
    // Cancel all first
    await NotificationService().cancelAll();

    List<String> logs = [];
    // Re-schedule all active templates (Weekly Default)
    for (var item in state.schedule) {
      if (item.subjectName.isNotEmpty) {
        String result = await _scheduleNotification(item);
        logs.add(result);
      }
    }

    // NEW: Re-schedule specific Sessions (Today/Future override)
    final now = DateTime.now();
    final pendingSessions = state.sessions.where((s) =>
            s.status == AttendanceStatus.pending &&
            !s.isCancelled &&
            s.endTime.isAfter(now) // Only future/ongoing
        );

    for (var session in pendingSessions) {
      String result = await _scheduleSessionNotification(session);
      logs.add(result);
    }

    debugPrint(
        "Manual Reschedule Complete. Templates: ${state.schedule.length}, Sessions: ${pendingSessions.length}");
    logs.add(
        "Processed ${state.schedule.length} templates & ${pendingSessions.length} active sessions.");
    return logs;
  }

  // --- Actions ---

  Future<void> addSubject(Subject subject, {String? groupId}) async {
    _registerUndo();
    final newSubjects = [...state.subjects, subject];
    List<Group> newGroups = state.groups;

    if (groupId != null) {
      newGroups = state.groups.map((g) {
        if (g.id == groupId) {
          return g.copyWith(subjectIds: [...g.subjectIds, subject.id]);
        }
        return g;
      }).toList();
    }

    state = state.copyWith(subjects: newSubjects, groups: newGroups);
    await _saveData();
  }

  Future<void> deleteSubject(String id) async {
    _registerUndo();

    // Cleanup Notifications linked to this Subject
    final linkedTemplates = state.schedule.where((t) => t.subjectId == id);
    for (final t in linkedTemplates) {
      await NotificationService().cancelType(t.id.hashCode);
    }
    final linkedSessions = state.sessions.where((s) => s.subjectId == id);
    for (final s in linkedSessions) {
      await NotificationService().cancelType(s.id.hashCode);
    }

    // Remove from subjects list
    final newSubjects = state.subjects.where((s) => s.id != id).toList();
    // Remove form groups
    final newGroups = state.groups.map((g) {
      return g.copyWith(
        subjectIds: g.subjectIds.where((sid) => sid != id).toList(),
      );
    }).toList();

    state = state.copyWith(subjects: newSubjects, groups: newGroups);
    await _saveData();
  }

  Future<void> updateSubject(
    Subject subject, {
    bool registerUndo =
        true, // Default to true for internal consistency, though manual calls might pass false to skip
  }) async {
    if (registerUndo) {
      _registerUndo();
      // Save Scoped Undo Snapshot
      _saveSubjectHistory(subject.id);
    }

    final newSubjects =
        state.subjects.map((s) => s.id == subject.id ? subject : s).toList();
    state = state.copyWith(subjects: newSubjects);
    await _saveData();
  }

  Future<void> logManualAttendance(
    String subjectId,
    AttendanceStatus status, {
    LogType type = LogType.manual,
    DateTime? timestamp,
  }) async {
    // 1. Save Scoped Undo Snapshot
    _saveSubjectHistory(subjectId);

    // 1.5 Global Undo Registration (Keep existing behavior if desired, or make optional)
    _registerUndo();

    final subject = state.subjects.firstWhere((s) => s.id == subjectId);
    final now = timestamp ?? DateTime.now();

    List<AttendanceLog> logs = [...subject.logs];
    int newPresent = subject.present;
    int newAbsent = subject.absent;
    int newProxy = subject.proxy;
    int newAmbiguous = subject.ambiguous;

    // Deduplication Removed: Always add new log
    logs.add(AttendanceLog(
      timestamp: now,
      status: status,
      type: type,
    ));

    // Increment the NEW status count
    if (status == AttendanceStatus.present) {
      newPresent++;
    } else if (status == AttendanceStatus.absent) {
      newAbsent++;
    } else if (status == AttendanceStatus.proxy) {
      newProxy++;
    } else if (status == AttendanceStatus.ambiguous) {
      newAmbiguous++;
    }

    // 2. Update Session Status (Sync UI)
    // Find a relevant session (Ongoing or recently finished) to update its status visually
    List<ClassSession> newSessions = state.sessions;
    bool sessionUpdated = false;

    // We look for a pending session for this subject that is either:
    // a) Currently ongoing (start < now < end)
    // b) Recently finished (within 30 mins) - covers "Auto-Attendance Complete" case
    try {
      final sessionIndex = newSessions.indexWhere((s) {
        if (s.subjectId != subjectId) return false;
        if (s.status != AttendanceStatus.pending) {
          return false; // Already marked
        }

        // Time check
        if (s.startTime.year != now.year ||
            s.startTime.month != now.month ||
            s.startTime.day != now.day) {
          return false;
        }

        // Active/Recent Check
        final isOngoing = s.startTime.isBefore(now) && s.endTime.isAfter(now);
        final isRecentlyFinished =
            now.isAfter(s.endTime) && now.difference(s.endTime).inMinutes < 60;
        final isAboutToStart = s.startTime.isAfter(now) &&
            s.startTime.difference(now).inMinutes < 15;

        return isOngoing || isRecentlyFinished || isAboutToStart;
      });

      if (sessionIndex != -1) {
        final newSession = newSessions[sessionIndex].copyWith(status: status);
        newSessions = List.from(newSessions); // Copy list
        newSessions[sessionIndex] = newSession;
        sessionUpdated = true;

        // Cancel notification for this session since it's now handled
        NotificationService().cancelType(newSession.id.hashCode);
      }
    } catch (e) {
      debugPrint("Error syncing session status: $e");
    }

    final updatedSubject = subject.copyWith(
      present: newPresent,
      absent: newAbsent,
      proxy: newProxy,
      ambiguous: newAmbiguous,
      logs: logs,
    );

    // Batch Update State
    final newSubjects = state.subjects
        .map((s) => s.id == subjectId ? updatedSubject : s)
        .toList();

    state = state.copyWith(
        subjects: newSubjects, sessions: sessionUpdated ? newSessions : null);
    await _saveData();
  }

  Future<void> updateAttendanceLog(
    String subjectId,
    String logId,
    AttendanceStatus newStatus,
  ) async {
    final subject = state.subjects.firstWhere((s) => s.id == subjectId);
    final logIndex = subject.logs.indexWhere((l) => l.id == logId);

    if (logIndex == -1) return;

    final oldLog = subject.logs[logIndex];
    if (oldLog.status == newStatus) return; // No change

    // 1. Revert old status
    int newPresent = subject.present;
    int newAbsent = subject.absent;
    int newProxy = subject.proxy;
    int newAmbiguous = subject.ambiguous;

    switch (oldLog.status) {
      case AttendanceStatus.present:
        newPresent--;
        break;
      case AttendanceStatus.absent:
        newAbsent--;
        break;
      case AttendanceStatus.proxy:
        newProxy--;
        break;
      case AttendanceStatus.ambiguous:
      case AttendanceStatus
            .pending: // usually Pending doesn't count towards stats, but Ambiguous might
        if (oldLog.status == AttendanceStatus.ambiguous) newAmbiguous--;
        break;
    }

    // 2. Apply new status
    switch (newStatus) {
      case AttendanceStatus.present:
        newPresent++;
        break;
      case AttendanceStatus.absent:
        newAbsent++;
        break;
      case AttendanceStatus.proxy:
        newProxy++;
        break;
      case AttendanceStatus.ambiguous:
        newAmbiguous++;
        break;
      case AttendanceStatus.pending:
        break; // Pending usually doesn't count
    }

    // 3. Update Log
    final updatedLogs = List<AttendanceLog>.from(subject.logs);
    updatedLogs[logIndex] = oldLog.copyWith(status: newStatus);

    final updatedSubject = subject.copyWith(
      present: newPresent,
      absent: newAbsent,
      proxy: newProxy,
      ambiguous: newAmbiguous,
      logs: updatedLogs,
    );

    await updateSubject(updatedSubject, registerUndo: true);
  }

  // Helper methods delegating to logManualAttendance
  Future<void> incrementPresent(String id) =>
      logManualAttendance(id, AttendanceStatus.present);
  Future<void> incrementAbsent(String id) =>
      logManualAttendance(id, AttendanceStatus.absent);
  Future<void> incrementAmbiguous(String id) =>
      logManualAttendance(id, AttendanceStatus.pending, type: LogType.proxy);

  Future<void> removeAmbiguous(String subjectId, int count) async {
    _registerUndo();
    final newSubjects = state.subjects.map((s) {
      if (s.id == subjectId) {
        int toRemove = count;
        if (s.ambiguous < toRemove) toRemove = s.ambiguous;

        return s.copyWith(ambiguous: s.ambiguous - toRemove);
      }
      return s;
    }).toList();

    // Note: We might also want to find and remove 'pending' logs if we track them explicitly.
    // For now, reducing the counter is sufficient for the Stats.

    state = state.copyWith(subjects: newSubjects);
    await _saveData();
  }

  Future<void> markDayAsAbsent() async {
    final now = DateTime.now();
    final todaySchedule =
        state.schedule.where((s) => s.dayOfWeek == now.weekday).toList();

    _registerUndo();
    // Use a batch update or sequential logic
    // We only want to one registerUndo, but calling incrementAbsent triggers one each time.
    // So we will manually modify state.
    // ACTUALLY, calling incrementAbsent is safer for logic re-use.
    // We can just squash undo stack later or accept multiple undos.
    // For simplicity, let's just loop. The user can undo one by one or we can group?
    // User requested "Smart". Grouped undo is better but harder.
    // Let's stick to simple loop.

    int markedCount = 0;
    for (var item in todaySchedule) {
      if (item.subjectId == null) continue;

      final subject = state.subjects.firstWhere((s) => s.id == item.subjectId);

      // Check if already logged for today
      final hasLogToday = subject.logs.any((l) =>
          l.timestamp.year == now.year &&
          l.timestamp.month == now.month &&
          l.timestamp.day == now.day);

      if (!hasLogToday) {
        // Mark Absent
        await incrementAbsent(item.subjectId!);
        markedCount++;
      }
    }
    debugPrint("Mass Bunk: Marked $markedCount classes as absent.");
  }

  // Replaced logic for undoLastChange and redoLastChange with new undo() / redo()

  Future<void> addGroup(Group group) async {
    _registerUndo();
    state = state.copyWith(groups: [...state.groups, group]);
    await _saveData();
  }

  Future<void> deleteGroup(String groupId) async {
    _registerUndo();
    state = state.copyWith(
      groups: state.groups.where((g) => g.id != groupId).toList(),
    );
    await _saveData();
  }

  Future<void> updateGroup(Group group) async {
    _registerUndo();
    final newGroups =
        state.groups.map((g) => g.id == group.id ? group : g).toList();
    state = state.copyWith(groups: newGroups);
    await _saveData();
  }

  Future<void> toggleGroupExpansion(String groupId) async {
    _registerUndo();
    state = state.copyWith(
      groups: state.groups
          .map((g) =>
              g.id == groupId ? g.copyWith(isExpanded: !g.isExpanded) : g)
          .toList(),
    );
    await _saveData();
  }

  Future<void> moveSubjectToGroup(
      String subjectId, String? targetGroupId) async {
    _registerUndo();
    // 1. Remove from any existing group
    final newGroups = state.groups.map((g) {
      if (g.subjectIds.contains(subjectId)) {
        return g.copyWith(
          subjectIds: g.subjectIds.where((sid) => sid != subjectId).toList(),
        );
      }
      return g;
    }).toList();

    // 2. Add to target group if specified
    if (targetGroupId != null) {
      final index = newGroups.indexWhere((g) => g.id == targetGroupId);
      if (index != -1) {
        newGroups[index] = newGroups[index].copyWith(
          subjectIds: [...newGroups[index].subjectIds, subjectId],
        );
      }
    }

    state = state.copyWith(groups: newGroups);
    await _saveData();
  }

  Future<void> moveSubjectsToGroup(
      Iterable<String> subjectIds, String? targetGroupId) async {
    _registerUndo();
    // 1. Remove all from any existing groups
    List<Group> newGroups = state.groups.map((g) {
      return g.copyWith(
        subjectIds:
            g.subjectIds.where((sid) => !subjectIds.contains(sid)).toList(),
      );
    }).toList();

    // 2. Add to target group if specified
    if (targetGroupId != null) {
      final index = newGroups.indexWhere((g) => g.id == targetGroupId);
      if (index != -1) {
        newGroups[index] = newGroups[index].copyWith(
          subjectIds: [...newGroups[index].subjectIds, ...subjectIds],
        );
      }
    }

    state = state.copyWith(groups: newGroups);
    await _saveData();
  }

  // --- Schedule Methods ---

  Future<String> _scheduleNotification(ScheduleTemplate item) async {
    final enableNotifications = prefs.getBool('enableNotifications') ?? true;
    final enableLiveActivity = prefs.getBool('enableLiveActivity') ?? false;
    final enableSilentNotifications =
        prefs.getBool('enableSilentNotifications') ?? false;

    // Helper for time formatting using Intl (Robust AM/PM)
    String formatTime(TimeOfDay t) {
      final now = DateTime.now();
      final dt = DateTime(now.year, now.month, now.day, t.hour, t.minute);
      return DateFormat.jm().format(dt);
    }

    if (!enableNotifications) return "Notifications Disabled";

    // 1. Calculate next standard instance (Repeating)
    final now = DateTime.now();
    debugPrint(
        "SCHEDULING: Item ${item.subjectName} (${item.dayOfWeek}) at ${item.startTime}");
    var scheduleDate = DateTime(now.year, now.month, now.day,
        item.startTime.hour, item.startTime.minute);

    // If we are currently IN the class, we will trigger an Ongoing notification immediately
    // and schedule the repeating one for NEXT week to avoid double-firing today.
    bool currentlyOngoing = false;
    if (item.hasTime) {
      final todayStart = DateTime(now.year, now.month, now.day,
          item.startTime.hour, item.startTime.minute);
      final todayEnd = DateTime(
          now.year, now.month, now.day, item.endTime.hour, item.endTime.minute);
      if (now.isAfter(todayStart) && now.isBefore(todayEnd)) {
        currentlyOngoing = true;
        debugPrint(
            "Class ${item.subjectName} is ONGOING. Triggering immediate notification.");

        // Resolve Session Link for Actions
        String resolvedSessionId = "";
        try {
          final existing = state.sessions.firstWhere((s) =>
              s.templateId == item.id &&
              s.startTime.year == now.year &&
              s.startTime.month == now.month &&
              s.startTime.day == now.day);
          resolvedSessionId = existing.id;
        } catch (_) {
          // No session exists? We should ideally create one or at least generate an ID that the Action handler can use to create it.
          // For now, let's rely on NotificationService's fallback to Create if we don't have one,
          // BUT providing a generated ID helps consistency if we can persist it.
          // Actually, let's just use empty if not found, OR we can try to find by fuzzy logic locally.
        }

        // Calculate progress
        int progress = 0;
        if (enableLiveActivity) {
          final total = todayEnd.difference(todayStart).inMinutes;
          final elapsed = now.difference(todayStart).inMinutes;
          if (total > 0) {
            progress = ((elapsed / total) * 100).toInt().clamp(0, 100);
          }
        }

        await NotificationService().showInstantNotification(
          id: item.id.hashCode,
          title: "Class: ${item.subjectName}",
          body:
              "Ongoing: ${item.subjectName} (${formatTime(item.startTime)} - ${formatTime(item.endTime)})",
          ongoing: enableLiveActivity,
          showProgress: enableLiveActivity,
          progress: progress,
          maxProgress: 100,
          indeterminate: false,
          when: todayStart.millisecondsSinceEpoch,
          payload: jsonEncode({
            'subjectId': item.subjectId,
            'templateId': item.id,
            if (resolvedSessionId.isNotEmpty) 'sessionId': resolvedSessionId,
            'liveUpdate': enableLiveActivity,
          }),
          silentMode: enableSilentNotifications,
        );

        // Removed misplaced block
      }
    }

    // Check if this class is already completed for today
    bool isCompletedToday = false;
    try {
      final todaySession = state.sessions.firstWhere((s) {
        // 1. Robust Match: Check by Template ID (Timezone Independent)
        if (item.id.isNotEmpty && s.templateId == item.id) {
          return true;
        }

        if (s.subjectId != item.subjectId) {
          return false;
        }
        if (s.startTime.year != now.year ||
            s.startTime.month != now.month ||
            s.startTime.day != now.day) {
          return false;
        }

        // 2. Fuzzy match time (within 30 minutes) as fallback for legacy sessions
        final scheduledTime = DateTime(now.year, now.month, now.day,
            item.startTime.hour, item.startTime.minute);
        final diff = s.startTime.difference(scheduledTime).abs();
        return diff.inMinutes <= 30;
      });

      if (todaySession.status != AttendanceStatus.pending ||
          todaySession.isCancelled) {
        isCompletedToday = true;
      }
    } catch (_) {
      // No matching session found
    }

    // Adjust to correct day of week
    while (scheduleDate.weekday != item.dayOfWeek) {
      scheduleDate = scheduleDate.add(const Duration(days: 1));
    }

    // If scheduleDate is in past OR it's currently ongoing (meaning we handle it today manually),
    // OR it's already completed today: move repeating schedule to next week. (Deterministic One-Notification logic)
    if (scheduleDate.isBefore(now) || currentlyOngoing || isCompletedToday) {
      scheduleDate = scheduleDate.add(const Duration(days: 7));
    }
    debugPrint(
        "FINAL SCHEDULE DATE for ${item.subjectName}: $scheduleDate (Ongoing: $currentlyOngoing, CompletedToday: $isCompletedToday)");

    final timeRange =
        "${formatTime(item.startTime)} - ${formatTime(item.endTime)}";

    int? durationMinutes;
    if (item.hasTime) {
      final startMin = item.startTime.hour * 60 + item.startTime.minute;
      final endMin = item.endTime.hour * 60 + item.endTime.minute;
      durationMinutes = endMin - startMin;
      if (durationMinutes < 0) {
        durationMinutes += 24 * 60;
      }
    }

    final payload = jsonEncode({
      'subjectId': item.subjectId,
      'templateId': item.id,
      'liveUpdate': enableLiveActivity,
    });

    // Clear standard recurring slot before re-scheduling to avoid duplicates
    await NotificationService().cancelType(item.id.hashCode);

    // Schedule Recurring Notification (Standard)
    await NotificationService().scheduleClassNotification(
      id: item.id.hashCode,
      title: "Class: ${item.subjectName}",
      body: "Time for ${item.subjectName} ($timeRange)",
      scheduledTime: scheduleDate,
      payload: payload,
      durationMinutes: durationMinutes,
      sessionStartTime: item.startTime,
      sessionEndTime: item.endTime,
      subjectName: item.subjectName,
      teacherName: item.teacherName,
      ongoing: enableLiveActivity, // Pass sticky preference
      showProgress:
          enableLiveActivity, // Show progress bar if Live Activity enabled
      indeterminate: true, // Start indeterminate until actual update
      progress: 0,
      silentMode: enableSilentNotifications,
    );

    // Schedule End Notification handled centrally in NotificationService
    // Removed duplicate logic

    return "Scheduled Template: ${item.subjectName} for $scheduleDate (Ongoing: $currentlyOngoing)";
  }

  // New: Schedule directly from a ClassSession (Source of Truth for Today)
  Future<String> _scheduleSessionNotification(ClassSession session) async {
    final enableNotifications = prefs.getBool('enableNotifications') ?? true;
    final enableLiveActivity = prefs.getBool('enableLiveActivity') ?? false;
    final enableSilentNotifications =
        prefs.getBool('enableSilentNotifications') ?? false;

    if (!enableNotifications) return "Notifications Disabled";

    // Helper for formatting
    String formatTime(DateTime dt) {
      return DateFormat.jm().format(dt);
    }

    // 1. Check validity
    final now = DateTime.now();
    if (session.startTime.isBefore(now) && session.endTime.isBefore(now)) {
      return "Skipped (Past): ${session.subjectName}";
    }

    // 2. Determine Trigger Time
    // If ongoing, trigger NOW. If future, trigger at startTime.
    bool currentlyOngoing = false;
    DateTime triggerTime = session.startTime;

    if (now.isAfter(session.startTime) && now.isBefore(session.endTime)) {
      currentlyOngoing = true;
      triggerTime = now.add(const Duration(seconds: 2)); // Immediate
    }

    // 3. Calculate Progress
    int progress = 0;
    if (currentlyOngoing && enableLiveActivity) {
      final total = session.endTime.difference(session.startTime).inMinutes;
      final elapsed = now.difference(session.startTime).inMinutes;
      if (total > 0) {
        progress = ((elapsed / total) * 100).toInt().clamp(0, 100);
      }
    }

    final timeRange =
        "${formatTime(session.startTime)} - ${formatTime(session.endTime)}";
    final payload = jsonEncode({
      'subjectId': session.subjectId,
      'sessionId': session.id, // Use Session ID
      'liveUpdate': enableLiveActivity,
    });

    final durationMinutes =
        session.endTime.difference(session.startTime).inMinutes;

    // 4. Schedule (One-shot)
    await NotificationService().scheduleClassNotification(
      id: session.id.hashCode, // Unique ID based on Session
      title: "Class: ${session.subjectName}",
      when: session.startTime.millisecondsSinceEpoch,
      body: currentlyOngoing
          ? "Ongoing: ${session.subjectName} ($timeRange)"
          : "Time for ${session.subjectName} ($timeRange)",
      scheduledTime: triggerTime,
      payload: payload,
      durationMinutes: durationMinutes,
      sessionStartTime: TimeOfDay.fromDateTime(session.startTime),
      sessionEndTime: TimeOfDay.fromDateTime(session.endTime),
      subjectName: session.subjectName,
      teacherName: session.teacherName,
      isRepeating: false, // One-shot
      ongoing: enableLiveActivity,
      showProgress: enableLiveActivity,
      indeterminate: !currentlyOngoing &&
          enableLiveActivity, // Only indeterminate if future
      progress: progress,
      silentMode: enableSilentNotifications,
    );

    // Schedule End Notification handled centrally in NotificationService

    return "Scheduled Session: ${session.subjectName} for $triggerTime";
  }

  // Export Schedule to MBweektemplate
  Future<void> exportScheduleToMBWeekTemplate(String name) async {
    try {
      final scheduleJson = state.schedule.map((t) => t.toJson()).toList();
      final jsonString = jsonEncode(scheduleJson);

      // Filename format: Name_StartDay-EndDay.MBweektemplate
      // Heuristic for start/end day: find min and max day in schedule
      int minDay = 7;
      int maxDay = 1;
      if (state.schedule.isNotEmpty) {
        minDay = state.schedule
            .map((s) => s.dayOfWeek)
            .reduce((a, b) => a < b ? a : b);
        maxDay = state.schedule
            .map((s) => s.dayOfWeek)
            .reduce((a, b) => a > b ? a : b);
      }

      String dayName(int d) {
        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        if (d >= 1 && d <= 7) return days[d - 1];
        return '';
      }

      final filename =
          "${name}_${dayName(minDay)}-${dayName(maxDay)}.MBweektemplate";

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$filename');
      await file.writeAsString(jsonString);

      // ignore: deprecated_member_use
      await Share.shareXFiles([XFile(file.path)], text: 'My Week Schedule');
    } catch (e) {
      debugPrint("Error exporting schedule: $e");
    }
  }

  // Import Schedule from MBweektemplate
  Future<List<ScheduleTemplate>> importScheduleFromMBWeekTemplate() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['MBweektemplate'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final jsonString = await file.readAsString();
        final List<dynamic> decoded = jsonDecode(jsonString);
        return decoded.map((e) => ScheduleTemplate.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint("Error importing MBweektemplate: $e");
    }
    return [];
  }

  Future<void> importScheduleForWeek(
      List<ScheduleTemplate> templates, DateTime weekStart) async {
    _registerUndo();

    // We want to apply these templates to a specific week.
    // This is similar to duplicateWeekSchedule, but instead of copying form existing sessions,
    // we generate sessions from these templates for the target week.

    final newSessions = <ClassSession>[];

    for (int i = 0; i < 7; i++) {
      final targetDate = weekStart.add(Duration(days: i));
      // Filter templates for this weekday
      // Note: PdfService returns 1=Mon...7=Sun
      // DateTime.weekday returns 1=Mon...7=Sun
      final dayTemplates =
          templates.where((t) => t.dayOfWeek == targetDate.weekday);

      for (final t in dayTemplates) {
        // Create Subject if it doesn't exist
        String? subjectId = t.subjectId;
        if (subjectId == null || subjectId.isEmpty) {
          // PdfService returns empty string IDs
          final existingSubject = state.subjects.cast<Subject?>().firstWhere(
                (s) => s!.name.toLowerCase() == t.subjectName.toLowerCase(),
                orElse: () => null,
              );

          if (existingSubject != null) {
            subjectId = existingSubject.id;
          } else {
            // Create new Subject
            final newSubject = Subject(
              name: t.subjectName,
              colorValue: t.colorValue,
              logs: [],
            );
            state = state.copyWith(subjects: [...state.subjects, newSubject]);
            subjectId = newSubject.id;
          }
        }

        final startDateTime = DateTime(targetDate.year, targetDate.month,
            targetDate.day, t.startTime.hour, t.startTime.minute);
        final endDateTime = DateTime(targetDate.year, targetDate.month,
            targetDate.day, t.endTime.hour, t.endTime.minute);

        newSessions.add(ClassSession(
          subjectName: t.subjectName,
          subjectId: subjectId,
          startTime: startDateTime,
          endTime: endDateTime,
          colorValue: t.colorValue,
          hasTime: t.hasTime,
        ));
      }
    }

    // Merge with existing sessions (append)
    state = state.copyWith(sessions: [...state.sessions, ...newSessions]);
    await _saveData();

    // Schedule Notifications for new sessions
    for (final s in newSessions) {
      await _scheduleSessionNotification(s);
    }
  }

  // Debug: Test Notification
  Future<void> testNotification() async {
    await NotificationService().showTestNotification();
  }

  Future<void> addScheduleItem(ScheduleTemplate item) async {
    _registerUndo();
    // Ensure Subject exists and link it
    String? subjectId = item.subjectId;

    if (subjectId == null) {
      final existingSubject = state.subjects.cast<Subject?>().firstWhere(
            (s) => s!.name.toLowerCase() == item.subjectName.toLowerCase(),
            orElse: () => null,
          );

      if (existingSubject != null) {
        subjectId = existingSubject.id;
      } else {
        // Lazy Creation: Generate ID but do NOT create Subject yet.
        // It will be created upon first attendance action.
        subjectId = const Uuid().v4();
      }
    }

    final newItem = item.copyWith(subjectId: subjectId);

    state = state.copyWith(schedule: [...state.schedule, newItem]);
    await _saveData();
    await _scheduleNotification(newItem);
  }

  Future<void> updateScheduleItem(ScheduleTemplate item) async {
    _registerUndo();
    final newSchedule =
        state.schedule.map((s) => s.id == item.id ? item : s).toList();
    state = state.copyWith(schedule: newSchedule);
    await _saveData();
    await _scheduleNotification(item);
  }

  Future<void> deleteScheduleItem(String id) async {
    _registerUndo();

    // 1. Find the item to be deleted to use for fuzzy matching cleanup
    final itemToDelete = state.schedule.firstWhere(
      (s) => s.id == id,
      orElse: () => ScheduleTemplate(
          // Dummy fallback if not found (shouldn't happen)
          id: 'error',
          subjectName: '',
          startTime: const TimeOfDay(hour: 0, minute: 0),
          endTime: const TimeOfDay(hour: 0, minute: 0),
          dayOfWeek: 1,
          colorValue: 0),
    );

    // 2. Remove from Schedule
    final newSchedule = state.schedule.where((s) => s.id != id).toList();

    // 3. [Fix Ghost Entries] Remove linked sessions
    // Matches by Template ID OR Fuzzy Match (Subject + Time) logic used in getDisplayItemsForDay
    // 3. [Fix Ghost Entries] Remove linked sessions and cancel their notifications
    final List<ClassSession> deletedSessions = [];
    final newSessions = state.sessions.where((s) {
      // Explicit Link
      if (s.templateId == id) {
        deletedSessions.add(s);
        return false;
      }

      // Fuzzy Link (Legacy sessions or untracked links)
      if (itemToDelete.id != 'error') {
        bool sameSubject = (s.subjectId == itemToDelete.subjectId) ||
            (s.subjectId == null && s.subjectName == itemToDelete.subjectName);
        bool sameTime = s.startTime.hour == itemToDelete.startTime.hour &&
            s.startTime.minute == itemToDelete.startTime.minute;

        // If it matches exactly logic-wise, we treat it as an instance of this template and remove it.
        // NOTE: We only remove if it falls on the same Weekday?
        // Sessions have full dates. Schedule is DoW.
        if (sameSubject &&
            sameTime &&
            s.startTime.weekday == itemToDelete.dayOfWeek) {
          deletedSessions.add(s);
          return false;
        }
      }

      return true;
    }).toList();

    // Cancel notifications for sessions being removed
    for (var s in deletedSessions) {
      await NotificationService().cancelType(s.id.hashCode);
    }

    state = state.copyWith(schedule: newSchedule, sessions: newSessions);
    await _saveData();
    await NotificationService().cancelType(id.hashCode);
  }

  Future<void> deleteClassSession(
      DateTime date, ScheduleTemplate? template, ClassSession? session) async {
    await deleteBulkClassSessions(date, [(template, session)]);
  }

  Future<void> deleteBulkClassSessions(
      DateTime date, List<(ScheduleTemplate?, ClassSession?)> items) async {
    _registerUndo();
    List<ClassSession> updatedSessions = [...state.sessions];
    List<Subject> updatedSubjectsList = [...state.subjects];
    bool sessionsChanged = false;
    bool subjectsChanged = false;

    for (final item in items) {
      final template = item.$1;
      final session = item.$2;

      // resolve subjectId
      final subjectId = session?.subjectId ?? template?.subjectId;

      // Find current actual session to check status before deleting
      ClassSession? currentSession;
      if (session != null) {
        final idx = updatedSessions.indexWhere((s) => s.id == session.id);
        if (idx != -1) currentSession = updatedSessions[idx];
      }

      // Decrement stats if applicable
      if (currentSession != null &&
          currentSession.status != AttendanceStatus.pending &&
          subjectId != null) {
        final subjectIdx =
            updatedSubjectsList.indexWhere((s) => s.id == subjectId);
        if (subjectIdx != -1) {
          final subject = updatedSubjectsList[subjectIdx];
          int newPresent = subject.present;
          int newAbsent = subject.absent;
          int newProxy = subject.proxy;
          int newAmbiguous = subject.ambiguous;

          if (currentSession.status == AttendanceStatus.present) {
            newPresent--;
          }
          if (currentSession.status == AttendanceStatus.absent) {
            newAbsent--;
          }
          if (currentSession.status == AttendanceStatus.proxy) {
            newProxy--;
          }
          if (currentSession.status == AttendanceStatus.ambiguous) {
            newAmbiguous--;
          }

          updatedSubjectsList[subjectIdx] = subject.copyWith(
            present: newPresent,
            absent: newAbsent,
            proxy: newProxy,
            ambiguous: newAmbiguous,
          );
          subjectsChanged = true;
        }
      }

      // Mark as cancelled (Delete logic)
      if (session == null && template != null) {
        final startDateTime = DateTime(date.year, date.month, date.day,
            template.startTime.hour, template.startTime.minute);
        final endDateTime = DateTime(date.year, date.month, date.day,
            template.endTime.hour, template.endTime.minute);

        final newSession = ClassSession(
          subjectName: template.subjectName,
          subjectId: template.subjectId,
          startTime: startDateTime,
          endTime: endDateTime,
          colorValue: template.colorValue,
          status: AttendanceStatus
              .pending, // Reset status when creating simplified cancel?
          isCancelled: true,
          isConcrete: true,
          templateId: template.id,
          teacherName: template.teacherName,
        );
        updatedSessions.add(newSession);
        sessionsChanged = true;
      } else if (currentSession != null) {
        final sessionIndex =
            updatedSessions.indexWhere((s) => s.id == currentSession!.id);
        if (sessionIndex != -1) {
          updatedSessions[sessionIndex] = currentSession.copyWith(
              isCancelled: true,
              status: AttendanceStatus.pending); // Reset to pending to be safe
          sessionsChanged = true;
          await NotificationService().cancelType(currentSession.id.hashCode);
          await LiveActivityService().cancelActivity(currentSession.id);
        }
      }
    }

    if (sessionsChanged || subjectsChanged) {
      state = state.copyWith(
        sessions: sessionsChanged ? updatedSessions : null,
        subjects: subjectsChanged ? updatedSubjectsList : null,
      );
      await _saveData();
    }

    // Refresh notifications for affected templates
    final uniqueTemplates =
        items.map((e) => e.$1).where((t) => t != null).map((t) => t!).toSet();

    for (final template in uniqueTemplates) {
      await _scheduleNotification(template);
    }
  }

  Future<void> deleteClassSessionById(String sessionId) async {
    _registerUndo();

    final idx = state.sessions.indexWhere((s) => s.id == sessionId);
    if (idx == -1) return;
    final realSession = state.sessions[idx];

    await deleteBulkClassSessions(realSession.startTime, [(null, realSession)]);
  }

  // ALIAS
  Future<void> deleteSession(String sessionId) =>
      deleteClassSessionById(sessionId);

  Future<void> replaceSchedule(List<ScheduleTemplate> newSchedule) async {
    _registerUndo();
    await NotificationService().cancelAll();
    state = state.copyWith(schedule: newSchedule);
    await _saveData();
    for (var item in newSchedule) {
      await _scheduleNotification(item);
    }
  }

  Future<void> duplicateWeekSchedule(
      DateTime sourceWeekStart, DateTime targetWeekStart) async {
    _registerUndo();
    final newSessions = <ClassSession>[];

    for (int i = 0; i < 7; i++) {
      final targetDate = targetWeekStart.add(Duration(days: i));
      final templates =
          state.schedule.where((t) => t.dayOfWeek == targetDate.weekday);

      for (final t in templates) {
        final startDateTime = DateTime(targetDate.year, targetDate.month,
            targetDate.day, t.startTime.hour, t.startTime.minute);
        final endDateTime = DateTime(targetDate.year, targetDate.month,
            targetDate.day, t.endTime.hour, t.endTime.minute);

        newSessions.add(ClassSession(
          subjectName: t.subjectName,
          subjectId: t.subjectId,
          startTime: startDateTime,
          endTime: endDateTime,
          colorValue: t.colorValue,
          hasTime: t.hasTime,
        ));
      }
    }

    state = state.copyWith(sessions: [...state.sessions, ...newSessions]);
    await _saveData();
  }

  Future<void> markAttendance(
    DateTime date,
    ScheduleTemplate? template,
    ClassSession? session,
    AttendanceStatus newStatus,
  ) async {
    await markBulkAttendance(date, [(template, session)], newStatus);
  }

  Future<void> markBulkAttendance(
    DateTime date,
    List<(ScheduleTemplate?, ClassSession?)> items,
    AttendanceStatus newStatus,
  ) async {
    _registerUndo();
    final now = DateTime.now();
    List<ClassSession> updatedSessions = [...state.sessions];
    List<Subject> updatedSubjects = [...state.subjects];
    bool sessionsChanged = false;
    bool subjectsChanged = false;

    // ... (rest of logic same, but inside loop)
    // Actually wait, markBulkAttendance inside changes lots of things.
    // It is simpler to just registerUndo once at start (done above).

    // Original loop logic:
    for (final item in items) {
      final template = item.$1;
      final session = item.$2;

      var subjectId = session?.subjectId ?? template?.subjectId;

      // [FIX] Lazy Resolution: If ID is missing (Imported Class), resolve or create Subject
      if (subjectId == null || subjectId.isEmpty) {
        final subjectName = session?.subjectName ?? template?.subjectName;
        if (subjectName != null && subjectName.isNotEmpty) {
          // 1. Try to find existing subject by name (Case Insensitive)
          final existingIdx = updatedSubjects.indexWhere((s) =>
              s.name.trim().toLowerCase() == subjectName.trim().toLowerCase());

          if (existingIdx != -1) {
            subjectId = updatedSubjects[existingIdx].id;
          } else {
            // 2. Create New Subject
            // Generate a robust ID
            final newId = const Uuid().v4();
            final newSubject = Subject(
              id: newId,
              name: subjectName,
              colorValue: session?.colorValue ??
                  template?.colorValue ??
                  Colors.blue.toARGB32(),
              logs: [],
            );
            updatedSubjects.add(newSubject);
            subjectsChanged = true;
            subjectId = newId;

            debugPrint("Lazy Created Subject: $subjectName ($newId)");
          }
        }
      }

      if (subjectId == null) {
        debugPrint("Skipping markAttendance: No Subject ID or Name found.");
        continue;
      }

      // Update Session
      // Find actual current session if exists and check status
      ClassSession? currentSession;
      if (session != null) {
        final idx = updatedSessions.indexWhere((s) => s.id == session.id);
        if (idx != -1) currentSession = updatedSessions[idx];
      }

      // Check against current state status to see if change needed
      final actualOldStatus =
          currentSession?.status ?? AttendanceStatus.pending;
      if (actualOldStatus == newStatus) continue;

      // Determine Session ID for linking
      String relatedSessionId;
      if (currentSession != null) {
        relatedSessionId = currentSession.id;
      } else {
        // Pre-generate ID for new session
        relatedSessionId = const Uuid().v4();
      }

      // Update Subject
      int subjectIndex = updatedSubjects.indexWhere((s) => s.id == subjectId);

      // Lazy Subject Creation
      if (subjectIndex == -1) {
        final subjectName = session?.subjectName ?? template?.subjectName;
        if (subjectName != null && subjectName.isNotEmpty) {
          final newSubject = Subject(
            id: subjectId,
            name: subjectName,
            colorValue: session?.colorValue ?? template?.colorValue,
            logs: [],
          );
          updatedSubjects.add(newSubject);
          subjectIndex = updatedSubjects.length - 1;
          subjectsChanged = true;
        }
      }

      if (subjectIndex != -1) {
        final subject = updatedSubjects[subjectIndex];
        int newPresent = subject.present;
        int newAbsent = subject.absent;
        int newProxy = subject.proxy;
        int newAmbiguous = subject.ambiguous;

        // Decrement old status
        AttendanceStatus oldStatusForStats = actualOldStatus;
        if (oldStatusForStats == AttendanceStatus.present) newPresent--;
        if (oldStatusForStats == AttendanceStatus.absent) newAbsent--;
        if (oldStatusForStats == AttendanceStatus.proxy) newProxy--;
        if (oldStatusForStats == AttendanceStatus.ambiguous) newAmbiguous--;

        // Increment new status
        if (newStatus == AttendanceStatus.present) newPresent++;
        if (newStatus == AttendanceStatus.absent) newAbsent++;
        if (newStatus == AttendanceStatus.proxy) newProxy++;
        if (newStatus == AttendanceStatus.ambiguous) newAmbiguous++;

        // Calculate Scheduled Date for Log
        DateTime? logScheduledDate;
        if (session != null) {
          logScheduledDate = session.startTime;
        } else if (template != null) {
          logScheduledDate = DateTime(date.year, date.month, date.day,
              template.startTime.hour, template.startTime.minute);
        }

        final newLog = AttendanceLog(
          timestamp: now,
          status: newStatus,
          type:
              (session?.isConcrete ?? false) ? LogType.proxy : LogType.schedule,
          relatedSessionId: relatedSessionId, // Linked!
          scheduledDate: logScheduledDate,
        );

        updatedSubjects[subjectIndex] = subject.copyWith(
          present: newPresent,
          absent: newAbsent,
          proxy: newProxy,
          ambiguous: newAmbiguous,
          logs: [...subject.logs, newLog],
        );
        subjectsChanged = true;
      }

      // Update or Create Session
      if (currentSession != null) {
        // Update existing session
        final sessionIndex =
            updatedSessions.indexWhere((s) => s.id == currentSession!.id);
        if (sessionIndex != -1) {
          updatedSessions[sessionIndex] =
              currentSession.copyWith(status: newStatus);
          sessionsChanged = true;
        }
      } else if (session == null && template != null) {
        // Create new session from template
        final startDateTime = DateTime(date.year, date.month, date.day,
            template.startTime.hour, template.startTime.minute);
        final endDateTime = DateTime(date.year, date.month, date.day,
            template.endTime.hour, template.endTime.minute);

        final newSession = ClassSession(
          id: relatedSessionId, // Use the ID we generated
          subjectName: template.subjectName,
          subjectId: template.subjectId,
          startTime: startDateTime,
          endTime: endDateTime,
          colorValue: template.colorValue,
          status: newStatus,
          isConcrete: true,
          hasTime: template.hasTime,
          templateId: template.id,
          teacherName: template.teacherName,
        );
        updatedSessions.add(newSession);
        sessionsChanged = true;
      }
    }

    if (sessionsChanged || subjectsChanged) {
      state = state.copyWith(
        subjects: subjectsChanged ? updatedSubjects : null,
        sessions: sessionsChanged ? updatedSessions : null,
      );
      await _saveData();
    }
  }

  // Helper to check if a template has been "concretized" for a specific date
  ClassSession? findSessionForTemplate(
      DateTime date, ScheduleTemplate template) {
    try {
      return state.sessions.firstWhere((s) =>
          s.subjectId == template.subjectId &&
          s.startTime.year == date.year &&
          s.startTime.month == date.month &&
          s.startTime.day == date.day &&
          s.startTime.hour == template.startTime.hour &&
          s.startTime.minute == template.startTime.minute);
    } catch (_) {
      return null;
    }
  }

  List<dynamic> getDisplayItemsForDay(DateTime date) {
    // 1. Get Scheduled Templates for this weekday
    final weekday = date.weekday;
    final templates =
        state.schedule.where((t) => t.dayOfWeek == weekday).toList();

    // 2. Get Concrete Sessions for this exact date
    final sessions = state.sessions
        .where((s) =>
            s.startTime.year == date.year &&
            s.startTime.month == date.month &&
            s.startTime.day == date.day)
        .toList();

    final displayItems = <dynamic>[];
    final handledSessionIds = <String>{};

    for (final t in templates) {
      // Find matching session
      // Prefer explicit link via ID
      var matchingSession = sessions.cast<ClassSession?>().firstWhere(
            (s) => s!.templateId == t.id && t.id.isNotEmpty,
            orElse: () => null,
          );

      // Fallback to Fuzzy Link
      matchingSession ??= sessions.cast<ClassSession?>().firstWhere(
          (s) =>
              s!.subjectName == t.subjectName && // Name Match
              // Check null templateId to avoid hijacking linked sessions?
              // Original logic: (s.subjectId == t.subjectId || (s.subjectId == null...))
              // Let's stick to Name + Time match for legacy/unlinked
              (s.templateId == null || s.templateId!.isEmpty) &&
              s.startTime.hour == t.startTime.hour &&
              s.startTime.minute == t.startTime.minute,
          orElse: () => null);

      if (matchingSession != null) {
        handledSessionIds.add(matchingSession.id);
        if (!matchingSession.isCancelled) {
          displayItems.add(matchingSession);
        }
        // If cancelled, show nothing (effectively hiding the template for this day)
      } else {
        // No session override -> Show Template (Pending)
        displayItems.add(t);
      }
    }

    // Add One-Off Sessions
    for (var session in sessions) {
      if (!handledSessionIds.contains(session.id)) {
        if (!session.isCancelled) {
          displayItems.add(session);
        }
      }
    }

    return displayItems;
  }

  Future<void> createBackup() async {
    final data = getSyncData();
    final jsonString = jsonEncode(data);
    await prefs.setString('manual_backup', jsonString);

    // Also save legacy keys for safety/backward compat if needed, or just rely on unified.
    // Let's stick to unified to keep it clean.
  }

  Future<bool> restoreBackup() async {
    _registerUndo();
    // 1. Try Unified Backup
    final jsonString = prefs.getString('manual_backup');
    if (jsonString != null) {
      try {
        final data = jsonDecode(jsonString) as Map<String, dynamic>;
        await mergeSyncData(AttendanceState.fromJson(data)); // Merge/Load
        return true;
      } catch (e) {
        debugPrint("Unified restore failed: $e. Falling back to legacy.");
      }
    }

    // 2. Fallback to Legacy Keys
    final subjectsJson = prefs.getString('backup_subjects');
    // If no subjects backup, consider it failed.
    if (subjectsJson == null) return false;

    await prefs.setString('subjects', subjectsJson);
    final groupsJson = prefs.getString('backup_groups');
    if (groupsJson != null) await prefs.setString('groups', groupsJson);
    final scheduleJson = prefs.getString('backup_schedule');
    if (scheduleJson != null) await prefs.setString('schedule', scheduleJson);
    final sessionsJson = prefs.getString('backup_sessions');
    if (sessionsJson != null) await prefs.setString('sessions', sessionsJson);

    await loadData();
    return true;
  }

  // Undo most recent change global
  Future<void> undoGlobalChange() async {
    await undo();
  }

  // Redo most recent change global
  Future<void> redoGlobalChange() async {
    await redo();
  }

  // Export Backup to File (Share Sheet)

  // Import from PDF (via OCR)

  // Scoped Undo: Save Snapshot of Subject BEFORE mutation
  void _saveSubjectHistory(String subjectId) {
    try {
      final subject = state.subjects.firstWhere((s) => s.id == subjectId);
      if (!_subjectUndoStack.containsKey(subjectId)) {
        _subjectUndoStack[subjectId] = [];
      }
      _subjectUndoStack[subjectId]!.add(subject);

      // Limit stack size per subject (e.g., 10)
      if (_subjectUndoStack[subjectId]!.length > 10) {
        _subjectUndoStack[subjectId]!.removeAt(0);
      }

      // Clear Redo on new action
      if (_subjectRedoStack.containsKey(subjectId)) {
        _subjectRedoStack[subjectId]!.clear();
      }
    } catch (e) {
      debugPrint("Scoped Undo Error: Subject $subjectId not found to save.");
    }
  }

  Future<void> undoSubjectChange(String subjectId) async {
    if (_subjectUndoStack.containsKey(subjectId) &&
        _subjectUndoStack[subjectId]!.isNotEmpty) {
      final previousState = _subjectUndoStack[subjectId]!.removeLast();

      // Save current state to Redo before reverting
      try {
        final current = state.subjects.firstWhere((s) => s.id == subjectId);
        if (!_subjectRedoStack.containsKey(subjectId)) {
          _subjectRedoStack[subjectId] = [];
        }
        _subjectRedoStack[subjectId]!.add(current);
      } catch (_) {}

      await updateSubject(previousState, registerUndo: false);
    }
  }

  Future<void> redoSubjectChange(String subjectId) async {
    if (_subjectRedoStack.containsKey(subjectId) &&
        _subjectRedoStack[subjectId]!.isNotEmpty) {
      final nextState = _subjectRedoStack[subjectId]!.removeLast();

      // Save current (which is the "undo" state) back to Undo before re-applying
      try {
        final current = state.subjects.firstWhere((s) => s.id == subjectId);
        if (!_subjectUndoStack.containsKey(subjectId)) {
          _subjectUndoStack[subjectId] = [];
        }
        _subjectUndoStack[subjectId]!.add(current);
      } catch (_) {}

      await updateSubject(nextState, registerUndo: false);
    }
  }

  // --- Reordering Logic ---

  Future<void> moveSubjectsUp(Set<String> selectedIds) async {
    if (selectedIds.isEmpty) return;
    _registerUndo();

    final currentSubjects = List<Subject>.from(state.subjects);
    final sortedIndices = <int>[];

    // Find indices of selected items
    for (int i = 0; i < currentSubjects.length; i++) {
      if (selectedIds.contains(currentSubjects[i].id)) {
        sortedIndices.add(i);
      }
    }

    // Sort indices ascending to process from top down (for Up movement)
    sortedIndices.sort();

    bool changed = false;
    for (final index in sortedIndices) {
      if (index > 0) {
        final prevIndex = index - 1;
        // Only swap if the item above is NOT selected (to move block together)
        // OR simply swap. Standard "Move Up" usually swaps with neighbor.
        // If neighbor is also selected, they move together, so effectively the top-most selected moves up, pushing others.
        // Actually, if we iterate top-down:
        // Index 1 (Selected) wants to move to 0.
        // If 0 is NOT selected, swap.
        // If 0 IS selected, it (index 0) would have already tried to move to -1 (and failed/stayed).
        // So 1 moving to 0 would mean swapping with a selected item, effectively doing nothing visual if we view them as a block.
        // Correct logic: specific item moves up if the space above is available (occupied by non-selected).

        if (!selectedIds.contains(currentSubjects[prevIndex].id)) {
          final temp = currentSubjects[prevIndex];
          currentSubjects[prevIndex] = currentSubjects[index];
          currentSubjects[index] = temp;
          changed = true;
        }
      }
    }

    if (changed) {
      state = state.copyWith(subjects: currentSubjects);
      await _saveData();
    }
  }

  Future<void> moveSubjectsDown(Set<String> selectedIds) async {
    if (selectedIds.isEmpty) return;
    _registerUndo();

    final currentSubjects = List<Subject>.from(state.subjects);
    final sortedIndices = <int>[];

    for (int i = 0; i < currentSubjects.length; i++) {
      if (selectedIds.contains(currentSubjects[i].id)) {
        sortedIndices.add(i);
      }
    }

    // Sort descending to process from bottom up
    sortedIndices.sort((a, b) => b.compareTo(a));

    bool changed = false;
    for (final index in sortedIndices) {
      if (index < currentSubjects.length - 1) {
        final nextIndex = index + 1;

        if (!selectedIds.contains(currentSubjects[nextIndex].id)) {
          final temp = currentSubjects[nextIndex];
          currentSubjects[nextIndex] = currentSubjects[index];
          currentSubjects[index] = temp;
          changed = true;
        }
      }
    }

    if (changed) {
      state = state.copyWith(subjects: currentSubjects);
      await _saveData();
    }
  }

  Future<void> addClassSession(ClassSession session) async {
    try {
      _registerUndo();

      // [FIX] Auto-Create Subject if it doesn't exist
      // This prevents "Null check operator" crashes when WidgetService/UI tries to look up the subject.
      // 1. Check if Subject ID exists
      final existingSubjectById =
          state.subjects.where((s) => s.id == session.subjectId).firstOrNull;

      ClassSession finalSession = session;
      List<Subject> updatedSubjects = [...state.subjects];
      bool subjectsChanged = false;

      if (existingSubjectById == null) {
        // 2. Check if Subject Name exists (to avoid duplicates)
        final existingSubjectByName = state.subjects
            .where((s) =>
                s.name.toLowerCase() == session.subjectName.toLowerCase())
            .firstOrNull;

        if (existingSubjectByName != null) {
          // Use existing subject ID
          finalSession = session.copyWith(subjectId: existingSubjectByName.id);
        } else {
          // 3. Create NEW Subject
          final newSubject = Subject(
            id: const Uuid().v4(),
            name: session.subjectName,
            colorValue: session.colorValue,
          );
          updatedSubjects.add(newSubject);
          subjectsChanged = true;
          // Use new subject ID
          finalSession = finalSession.copyWith(subjectId: newSubject.id);
        }
      }

      if (subjectsChanged) {
        state = state.copyWith(subjects: updatedSubjects);
        // Note: _saveData() is called below, covering both sessions and subjects if we assume strict serialization order,
        // but safe to rely on the final save.
      }

      final newSessions = [...state.sessions, finalSession];
      // Sort chronologically
      newSessions.sort((a, b) => a.startTime.compareTo(b.startTime));

      state = state.copyWith(sessions: newSessions);
      await _saveData();
    } catch (e, stack) {
      debugPrint("Error saving session data: $e");
      LogService().error("Error saving session data", stack);
      rethrow; // Rethrow to show in UI
    }

    try {
      await WidgetService.updateMyDayWidget(state.sessions, state.schedule);
    } catch (e, stack) {
      debugPrint("Error updating widget (Safety Catch): $e");
      LogService().error("Error updating widget (Safety Catch)", stack);
      // Don't crash app for widget update
    }

    try {
      // Immediate Notification
      await _scheduleSessionNotification(session);
    } catch (e, stack) {
      debugPrint("Error scheduling notification: $e");
      LogService().error("Error scheduling notification", stack);
      // Don't crash for notification
    }
  }

  // [NEW] One-off Class Logic with Subject Linking
  Future<void> addOneOffClass(ClassSession session) async {
    _registerUndo();

    // 1. Ensure Subject exists or create lazily (similar to addScheduleItem)
    String? subjectId = session.subjectId;
    bool subjectsChanged = false;
    List<Subject> updatedSubjects = [...state.subjects];

    if (subjectId == null) {
      final existingSubject = updatedSubjects.cast<Subject?>().firstWhere(
            (s) => s!.name.toLowerCase() == session.subjectName.toLowerCase(),
            orElse: () => null,
          );

      if (existingSubject != null) {
        subjectId = existingSubject.id;
      } else {
        // Create new Subject
        final newSubject = Subject(
          name: session.subjectName,
          colorValue: session.colorValue,
          logs: [],
        );
        updatedSubjects.add(newSubject);
        subjectId = newSubject.id;
        subjectsChanged = true;
      }
    }

    final linkedSession = session.copyWith(subjectId: subjectId);

    // 2. Add Session
    final newSessions = [...state.sessions, linkedSession];
    newSessions.sort((a, b) => a.startTime.compareTo(b.startTime));

    state = state.copyWith(
      sessions: newSessions,
      subjects: subjectsChanged ? updatedSubjects : null,
    );

    await _saveData();
    await WidgetService.updateMyDayWidget(state.sessions, state.schedule);

    // Immediate Notification for One-Off Class
    await _scheduleSessionNotification(linkedSession);
  }

  // Pick and Parse Week Template (Step 1 of Import)
  // Returns a List of Weeks, where each Week is a List of ScheduleTemplates.
  // Single week = [ [Template1, Template2...] ]
  // Multi week = [ [Week1...], [Week2...] ]
  Future<List<List<ScheduleTemplate>>?> pickAndParseWeekTemplate() async {
    try {
      debugPrint("Opening File Picker for Schedule Import...");
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final extension = result.files.single.extension?.toLowerCase();

        debugPrint("File picked: ${file.path}, Extension: $extension");

        if (extension == 'json' || extension == 'mbweektemplate') {
          final jsonString = await file.readAsString();
          final dynamic decoded = jsonDecode(jsonString);

          if (decoded is List) {
            if (decoded.isEmpty) return [];
            // Check if it's List<List> (Multi-Week) or List<Object> (Single-Week)
            if (decoded.first is List) {
              return decoded
                  .map((week) => (week as List)
                      .map((e) => ScheduleTemplate.fromJson(e))
                      .toList())
                  .toList();
            } else {
              // Single Week (Legacy format)
              return [
                decoded.map((e) => ScheduleTemplate.fromJson(e)).toList()
              ];
            }
          }
        } else if (extension == 'mb') {
          final jsonString = await file.readAsString();
          final Map<String, dynamic> decoded = jsonDecode(jsonString);
          if (decoded.containsKey('schedule')) {
            final List<dynamic> scheduleList = jsonDecode(decoded['schedule']);
            return [
              scheduleList.map((e) => ScheduleTemplate.fromJson(e)).toList()
            ];
          }
        }
      }
    } catch (e, stack) {
      debugPrint("Error parsing schedule template: $e\n$stack");
    }
    return null;
  }

  // Apply Template to Multiple Weeks (Step 2 of Import)
  Future<void> applyTemplateToWeeks(List<List<ScheduleTemplate>> templates,
      List<DateTime> targetWeekStarts) async {
    if (templates.isEmpty || targetWeekStarts.isEmpty) return;

    final newSessions = <ClassSession>[];
    String newIdPrefix = DateTime.now().millisecondsSinceEpoch.toString();
    int counter = 0;

    // Logic:
    // If templates.length == 1: Apply that SINGLE template to ALL targetWeekStarts (Broadcast/Duplicate Mode).
    // If templates.length > 1: Apply SEQUENTIALLY starting from targetWeekStarts.first.

    final isMultiWeekImport = templates.length > 1;

    // 1. Identify Target Dates and Clear Existing Sessions
    final Set<DateTime> targetDates = {};

    if (isMultiWeekImport) {
      // Sequential application
      final startBase = targetWeekStarts.first;
      for (int i = 0; i < templates.length; i++) {
        final weekStart = startBase.add(Duration(days: 7 * i));
        for (int j = 0; j < 7; j++) {
          final d = weekStart.add(Duration(days: j));
          targetDates.add(DateTime(d.year, d.month, d.day));
        }
      }
    } else {
      // Broadcast application
      for (final start in targetWeekStarts) {
        for (int i = 0; i < 7; i++) {
          final d = start.add(Duration(days: i));
          targetDates.add(DateTime(d.year, d.month, d.day));
        }
      }
    }

    final filteredSessions = state.sessions.where((s) {
      final sDate =
          DateTime(s.startTime.year, s.startTime.month, s.startTime.day);
      return !targetDates.contains(sDate);
    }).toList();

    // 2. Generate New Sessions
    if (isMultiWeekImport) {
      // Sequential
      final startBase = targetWeekStarts.first;
      for (int i = 0; i < templates.length; i++) {
        final weekTemplate = templates[i];
        final weekStart = startBase.add(Duration(days: 7 * i));
        _generateSessionsForWeek(
            weekTemplate, weekStart, newSessions, newIdPrefix, counter);
        counter += weekTemplate.length * 7; // rough increment to keep unique
      }
    } else {
      // Broadcast (Single template to many weeks)
      final weekTemplate = templates.first;
      for (final weekStart in targetWeekStarts) {
        _generateSessionsForWeek(
            weekTemplate, weekStart, newSessions, newIdPrefix, counter);
        counter += weekTemplate.length * 7;
      }
    }

    // Update State
    final updatedSessions = [...filteredSessions, ...newSessions];
    updatedSessions.sort((a, b) => a.startTime.compareTo(b.startTime));

    state = state.copyWith(
      sessions: updatedSessions,
      schedule: isMultiWeekImport
          ? state.schedule
          : templates
              .first, // Update default schedule only if single week import (to avoid ambiguity)
    );
    await _saveData();

    // Notifications? Just schedule for all new sessions?
    // Existing logic scheduled notifications for Template.
    // We should probably rely on sessions now, but existing logic used template.
    // We'll skip notification scheduling for now to avoid complexity or loop through the applied template.
    if (!isMultiWeekImport) {
      for (final t in templates.first) {
        _scheduleNotification(t);
      }
    }

    await WidgetService.updateMyDayWidget(state.sessions, state.schedule,
        subjects: state.subjects);
  }

  void _generateSessionsForWeek(
      List<ScheduleTemplate> template,
      DateTime weekStart,
      List<ClassSession> sessions,
      String idPrefix,
      int counterOffset) {
    int localCounter = counterOffset;
    for (int dayOfWeek = 1; dayOfWeek <= 7; dayOfWeek++) {
      final targetDate = weekStart.add(Duration(days: dayOfWeek - 1));
      final dailyTemplates = template.where((t) => t.dayOfWeek == dayOfWeek);

      for (final t in dailyTemplates) {
        final startDt = DateTime(targetDate.year, targetDate.month,
            targetDate.day, t.startTime.hour, t.startTime.minute);
        final endDt = DateTime(targetDate.year, targetDate.month,
            targetDate.day, t.endTime.hour, t.endTime.minute);

        sessions.add(ClassSession(
          id: "${idPrefix}_${localCounter++}",
          subjectName: t.subjectName,
          subjectId: t.subjectId,
          startTime: startDt,
          endTime: endDt,
          colorValue: t.colorValue,
          status: AttendanceStatus.pending,
          templateId: t.id,
        ));
      }
    }
  }

  // Wrapper for backward compatibility or single-call legacy usage if any
  // Future<List<ScheduleTemplate>> importScheduleFromFile() async { ... } // Removed

  // Generate Week Schedule File (for Export/Save)
  // Supports Single-Week (default logic) or Multi-Week (if selectedWeeks is provided)
  Future<File?> generateWeekScheduleFile(
      {List<DateTime>? selectedWeeks}) async {
    try {
      String jsonString;

      if (selectedWeeks != null && selectedWeeks.isNotEmpty) {
        // Multi-Week Export: Convert Sessions of these weeks to Template Lists
        final List<List<ScheduleTemplate>> multiWeekTemplates = [];

        for (final weekStart in selectedWeeks) {
          final weekTemplates = <ScheduleTemplate>[];
          // Find sessions in this week
          final endOfWeek = weekStart.add(const Duration(days: 7));
          final sessions = state.sessions
              .where((s) =>
                  s.startTime.isAfter(
                      weekStart.subtract(const Duration(seconds: 1))) &&
                  s.startTime.isBefore(endOfWeek) &&
                  !s.isCancelled)
              .toList();

          for (final session in sessions) {
            weekTemplates.add(ScheduleTemplate(
              id: session.templateId ?? uuid.v4(),
              subjectName: session.subjectName,
              subjectId: session.subjectId,
              dayOfWeek: session.startTime.weekday,
              startTime: TimeOfDay.fromDateTime(session.startTime),
              endTime: TimeOfDay.fromDateTime(session.endTime),
              colorValue: session.colorValue,
            ));
          }
          multiWeekTemplates.add(weekTemplates);
        }
        jsonString = jsonEncode(multiWeekTemplates);
      } else {
        // Default: Export the Base Schedule Template (List<ScheduleTemplate>)
        // We wrap it in a list of lists for consistency? Or keep legacy format?
        // Let's keep legacy format for single week to avoid confusion,
        // OR wrap it to unify.
        // Existing logic exported List<ScheduleTemplate>.
        // pickAndParse handles List<Object> so legacy is fine.
        final scheduleJson = state.schedule.map((t) => t.toJson()).toList();
        jsonString = jsonEncode(scheduleJson);
      }

      final directory = await getTemporaryDirectory();

      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      String filename;
      if (selectedWeeks != null && selectedWeeks.isNotEmpty) {
        final start = selectedWeeks.first;
        final end = selectedWeeks.last.add(const Duration(days: 6));
        final f = DateFormat('dd MMM');
        filename =
            "WEEK [ ${f.format(start)} to ${f.format(end)} ].MBweektemplate";
      } else {
        filename = "WEEK [ Template ].MBweektemplate";
      }

      final file = File('${directory.path}/$filename');
      await file.writeAsString(jsonString);
      return file;
    } catch (e) {
      debugPrint("Error generating schedule file: $e");
      return null;
    }
  }

  // Save Week Schedule to Downloads/MadBunky/Week templates
  Future<String?> saveWeekScheduleToStorage(
      {List<DateTime>? selectedWeeks}) async {
    try {
      String jsonString;
      String filename;

      if (selectedWeeks != null && selectedWeeks.isNotEmpty) {
        // Multi-Week Export
        final List<List<ScheduleTemplate>> multiWeekTemplates = [];

        for (final weekStart in selectedWeeks) {
          final weekTemplates = <ScheduleTemplate>[];
          final endOfWeek = weekStart.add(const Duration(days: 7));
          final sessions = state.sessions
              .where((s) =>
                  s.startTime.isAfter(
                      weekStart.subtract(const Duration(seconds: 1))) &&
                  s.startTime.isBefore(endOfWeek) &&
                  !s.isCancelled)
              .toList();

          for (final session in sessions) {
            weekTemplates.add(ScheduleTemplate(
              id: session.templateId ?? uuid.v4(),
              subjectName: session.subjectName,
              subjectId: session.subjectId,
              dayOfWeek: session.startTime.weekday,
              startTime: TimeOfDay.fromDateTime(session.startTime),
              endTime: TimeOfDay.fromDateTime(session.endTime),
              colorValue: session.colorValue,
            ));
          }
          multiWeekTemplates.add(weekTemplates);
        }
        jsonString = jsonEncode(multiWeekTemplates);

        final start = selectedWeeks.first;
        final end = selectedWeeks.last.add(const Duration(days: 6));
        final f = DateFormat('dd MMM');
        filename =
            "WEEK [ ${f.format(start)} to ${f.format(end)} ].MBweektemplate";
      } else {
        // Single Week Export
        final scheduleJson = state.schedule.map((t) => t.toJson()).toList();
        jsonString = jsonEncode(scheduleJson);
        filename = "WEEK [ Template ].MBweektemplate";
      }

      Directory? baseDir;
      if (Platform.isAndroid) {
        baseDir = Directory('/storage/emulated/0/Download');
      } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        baseDir = await getDownloadsDirectory();
      }

      if (baseDir != null) {
        if (!await baseDir.exists() && !Platform.isAndroid) {
          await baseDir.create(recursive: true);
        }

        final saveDir = Directory('${baseDir.path}/MadBunky/Week templates');
        if (!await saveDir.exists()) {
          await saveDir.create(recursive: true);
        }

        final file = File('${saveDir.path}/$filename');
        await file.writeAsString(jsonString);
        return file.path;
      }
    } catch (e) {
      debugPrint("Error saving week schedule to storage: $e");
    }
    return null;
  }

  // Deprecated/Legacy wrapper if needed, but we will move logic to UI
  Future<void> exportWeekTemplate() async {
    final file = await generateWeekScheduleFile();
    if (file != null) {
      await Share.shareXFiles([XFile(file.path)], text: 'My Week Schedule');
    }
  }

  // Import Backup (Legacy/Manual)
  Future<bool> importBackupFromFile() async {
    _registerUndo();
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();

      if (result != null) {
        File file = File(result.files.single.path!);
        Map<String, dynamic> backupData = jsonDecode(await file.readAsString());

        if (backupData.containsKey('subjects')) {
          await prefs.setString('subjects', jsonEncode(backupData['subjects']));
        }
        if (backupData.containsKey('groups')) {
          await prefs.setString('groups', jsonEncode(backupData['groups']));
        }
        if (backupData.containsKey('schedule')) {
          await prefs.setString('schedule', jsonEncode(backupData['schedule']));
        }
        if (backupData.containsKey('sessions')) {
          await prefs.setString('sessions', jsonEncode(backupData['sessions']));
        }

        loadData(); // Reload state
        debugPrint("Backup imported successfully.");
        return true;
      }
    } catch (e, stackTrace) {
      debugPrint("Error importing backup: $e\n$stackTrace");
    }
    return false;
  }

  // Import Backup from Specific Path (via Share Intent)
  Future<bool> importBackupFromFilePath(String path) async {
    _registerUndo();
    try {
      final file = File(path);
      if (!await file.exists()) {
        debugPrint("Backup import failed: File does not exist at $path");
        return false;
      }

      final jsonString = await file.readAsString();
      if (jsonString.isEmpty) {
        debugPrint("Backup import failed: File is empty.");
        return false;
      }

      final Map<String, dynamic> backupData = jsonDecode(jsonString);

      if (backupData.containsKey('subjects')) {
        await prefs.setString('subjects', jsonEncode(backupData['subjects']));
      }
      if (backupData.containsKey('groups')) {
        await prefs.setString('groups', jsonEncode(backupData['groups']));
      }
      if (backupData.containsKey('schedule')) {
        await prefs.setString('schedule', jsonEncode(backupData['schedule']));
      }
      if (backupData.containsKey('sessions')) {
        await prefs.setString('sessions', jsonEncode(backupData['sessions']));
      }

      loadData(); // Reload state
      debugPrint("Backup imported successfully from $path");
      return true;
    } catch (e, stackTrace) {
      debugPrint("Error importing backup from path: $e\n$stackTrace");
      return false;
    }
  }

  // Import Schedule Template from Specific Path (via Share Intent)
  Future<bool> importScheduleTemplateFromFilePath(String path) async {
    _registerUndo();
    try {
      final file = File(path);
      if (!await file.exists()) return false;

      final jsonString = await file.readAsString();
      if (jsonString.isEmpty) return false;

      final dynamic decoded = jsonDecode(jsonString);
      List<dynamic> templateData;

      if (decoded is List) {
        // Check if it's a List<List> (Multi-week) or List<Object> (Single week)
        if (decoded.isNotEmpty && decoded.first is List) {
          // Flatten multi-week export or just take the first week?
          // Since we are replacing the *Base Schedule*, we likely want to flattening or picking one.
          // BUT - The user probably expects "Import Schedule" to set their standard weekly routine.
          // If they exported multiple weeks, that's usually for sharing specific variations.
          // To be safe and simple: Flatten all into one list, or assume the first list is the "Master".
          // Let's Flatten.
          templateData = decoded.expand((e) => (e as List)).toList();
        } else {
          templateData = decoded;
        }
      } else {
        return false;
      }

      final newTemplate = templateData
          .map((e) => ScheduleTemplate.fromJson(e as Map<String, dynamic>))
          .toList();

      if (newTemplate.isEmpty) return false;

      // Replace current schedule
      await prefs.setString(
          'schedule', jsonEncode(newTemplate.map((e) => e.toJson()).toList()));
      state = state.copyWith(schedule: newTemplate);

      debugPrint("Schedule Template imported successfully from $path");
      return true;
    } catch (e) {
      debugPrint("Error importing schedule template: $e");
      return false;
    }
  }

  Future<void> convertAmbiguous(
      String subjectId, int count, AttendanceStatus targetStatus) async {
    _registerUndo();
    final idx = state.subjects.indexWhere((s) => s.id == subjectId);
    if (idx == -1) return;

    final subject = state.subjects[idx];
    if (count > subject.ambiguous) return;

    int newPresent = subject.present;
    int newAbsent = subject.absent;
    int newProxy = subject.proxy;
    int newAmbiguous = subject.ambiguous - count;

    if (targetStatus == AttendanceStatus.present) newPresent += count;
    if (targetStatus == AttendanceStatus.absent) newAbsent += count;
    if (targetStatus == AttendanceStatus.proxy) newProxy += count;

    // We do not modify logs here as this is a bulk stats adjustment for "Not Sure".
    // "Not Sure" usually implies no concrete session data or manual override.
    // If we wanted to go deep, we'd find "ambiguous" logs and update them, but for now stats adjustment is sufficient as per spec.

    final updatedSubjects = [...state.subjects];
    updatedSubjects[idx] = subject.copyWith(
      present: newPresent,
      absent: newAbsent,
      proxy: newProxy,
      ambiguous: newAmbiguous,
    );

    state = state.copyWith(subjects: updatedSubjects);
    await _saveData();
  }

  // Helper: Deduplicate sessions based on Subject+Time
  List<ClassSession> _deduplicateSessions(List<ClassSession> sessions) {
    if (sessions.isEmpty) return [];

    // 1. Sort by Priority (Present/Absent/Proxy > Ambiguous > Pending)
    sessions.sort((a, b) {
      int priority(AttendanceStatus s) {
        switch (s) {
          case AttendanceStatus.present:
          case AttendanceStatus.absent:
          case AttendanceStatus.proxy:
            return 3;
          case AttendanceStatus.ambiguous:
            return 2;
          case AttendanceStatus.pending:
            return 1;
        }
      }

      return priority(b.status).compareTo(priority(a.status));
    });

    // 2. Filter Duplicates
    final uniqueSessions = <String, ClassSession>{};
    for (var session in sessions) {
      final key =
          "${session.subjectId}_${session.startTime.millisecondsSinceEpoch}";
      if (!uniqueSessions.containsKey(key)) {
        uniqueSessions[key] = session;
      }
    }

    return uniqueSessions.values.toList();
  }

  Future<void> shareBackup() async {
    try {
      final file = await _createBackupFile();
      if (file != null) {
        // ignore: deprecated_member_use
        await Share.shareXFiles([XFile(file.path)], text: 'MadBunky Backup');
      }
    } catch (e) {
      debugPrint("Error sharing backup: $e");
    }
  }

  Future<String?> saveBackupToStorage() async {
    try {
      final file = await _createBackupFile(saveToDownloads: true);
      return file?.path;
    } catch (e) {
      debugPrint("Error saving backup: $e");
      return null;
    }
  }

  Future<File?> _createBackupFile({bool saveToDownloads = false}) async {
    final data = getSyncData();
    final jsonString = jsonEncode(data);
    final now = DateTime.now();
    final f = DateFormat('yyyy-MM-dd_HH-mm');
    final filename = "MadBunky_Backup_${f.format(now)}.MBbackup";

    if (saveToDownloads) {
      Directory? baseDir;
      if (Platform.isAndroid) {
        baseDir = Directory('/storage/emulated/0/Download');
      } else {
        baseDir = await getDownloadsDirectory();
      }

      if (baseDir != null) {
        if (!await baseDir.exists() && !Platform.isAndroid) {
          await baseDir.create(recursive: true);
        }
        final saveDir = Directory('${baseDir.path}/MadBunky/Backups');
        if (!await saveDir.exists()) {
          await saveDir.create(recursive: true);
        }
        final file = File('${saveDir.path}/$filename');
        await file.writeAsString(jsonString);
        return file;
      }
    } else {
      final directory = await getTemporaryDirectory();
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      final file = File('${directory.path}/$filename');
      await file.writeAsString(jsonString);
      return file;
    }
    return null;
  }

  Map<String, dynamic> getSyncData() {
    return {
      'subjects': jsonDecode(prefs.getString('subjects') ?? '[]'),
      'groups': jsonDecode(prefs.getString('groups') ?? '[]'),
      'schedule': jsonDecode(prefs.getString('schedule') ?? '[]'),
      'sessions': jsonDecode(prefs.getString('sessions') ?? '[]'),
    };
  }
}

final attendanceProvider =
    StateNotifierProvider<AttendanceNotifier, AttendanceState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final backupService = ref.watch(backupServiceProvider);
  return AttendanceNotifier(prefs, backupService);
});

final selectedSubjectsProvider = StateProvider<Set<String>>((ref) => {});
final selectedGroupsProvider = StateProvider<Set<String>>((ref) => {});
final calendarSelectionProvider = StateProvider<Set<String>>((ref) => {});
final calendarSelectedDateProvider =
    StateProvider<DateTime>((ref) => DateTime.now());

// Secret Debug Mode Provider
final debugModeProvider = StateProvider<bool>((ref) => false);

// UI State Providers for Smooth Transitions
final calendarViewProvider =
    StateProvider<int>((ref) => 0); // 0=Day, 1=Week, 2=Month
final searchQueryProvider = StateProvider<String>((ref) => "");

final proxyEffectTriggerProvider =
    StateProvider<int>((ref) => 0); // Increment to trigger

enum CalendarMenuAction {
  duplicate,
  import, // Legacy/Backup import
  restoreBackup, // Explicit Backup import
  importPdf,
  cameraScan,
  export,
  stats
}

final calendarMenuActionProvider =
    StateProvider<CalendarMenuAction?>((ref) => null);

// Queue for shared files (PDF/Images) to be picked up by Calendar Screen
final sharedFileQueueProvider = StateProvider<String?>((ref) => null);
// --- Sync Provider ---

// --- Animation State Providers ---

enum ReorderDirection { up, down }

class ReorderEvent {
  final String id;
  final ReorderDirection direction;
  final int timestamp; // To force updates even if same move repeats

  ReorderEvent(this.id, this.direction)
      : timestamp = DateTime.now().millisecondsSinceEpoch;
}

final lastReorderEventProvider = StateProvider<ReorderEvent?>((ref) => null);

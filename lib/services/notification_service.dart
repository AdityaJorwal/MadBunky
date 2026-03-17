import 'dart:convert';
import 'dart:async';
import 'dart:isolate'; // For SendPort
import 'package:flutter/material.dart'; // For WidgetsFlutterBinding
import 'package:flutter/foundation.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'dart:ui'; // For IsolateNameServer
import '../models/models.dart';
import 'package:uuid/uuid.dart';
import 'notification_image_generator.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'live_activity_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String _mainIsolateName = 'notification_port';
  ReceivePort? _port; // Re-added

  static final StreamController<NotificationResponse> _actionController =
      StreamController.broadcast();
  static Stream<NotificationResponse> get actionStream =>
      _actionController.stream;

  static final StreamController<String> _logController =
      StreamController.broadcast();
  static Stream<String> get logStream => _logController.stream;

  // Helper to broadcast action/log from background isolate listener
  // This broadcasts to LOCAL stream AND sends to Main Isolate.
  static void broadcastAction(NotificationResponse response) {
    _actionController.add(response);
    _sendToMain(response);
  }

  // Ensure ID fits within 32-bit integer range for Android compatibility
  static int safeId(int id) {
    return id & 0x7FFFFFFF;
  }

  static void broadcastLog(String message) {
    _logController.add(message);
    _sendToMain(message);
  }

  // Use this when we just want to update the stream (e.g. inside Main Isolate) to avoid loops
  static void processAction(NotificationResponse response) {
    _actionController.add(response);
  }

  static void processLog(String message) {
    _logController.add(message);
  }

  static void _sendToMain(dynamic data) async {
    final SendPort? sendPort =
        IsolateNameServer.lookupPortByName(_mainIsolateName);
    if (sendPort != null) {
      sendPort.send(data);
    } else {
      // debugPrint("Port '$_mainIsolateName' not found for: $data");
    }
  }

  static void triggerReload() {
    broadcastAction(const NotificationResponse(
      notificationResponseType:
          NotificationResponseType.selectedNotificationAction,
      actionId: 'reload_data',
    ));
  }

  Future<void> init({String? isolateName}) async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    debugPrint("Initializing Notification Service... (Isolate: $isolateName)");

    // Setup Isolate Communication
    if (isolateName != null) {
      IsolateNameServer.removePortNameMapping(isolateName);
      _port = ReceivePort();
      IsolateNameServer.registerPortWithName(_port!.sendPort, isolateName);
      _port!.listen((dynamic data) {
        if (data is NotificationResponse) {
          debugPrint(
              "ISOLATE ($isolateName): Received Action ${data.actionId}");
          _actionController.add(data);
          _logController.add("Action: ${data.actionId}");
        } else if (data is String) {
          debugPrint("ISOLATE ($isolateName): Received Log: $data");
          _logController.add(data);
        }
      });
    }

    // iOS settings
    final DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      onDidReceiveLocalNotification: onDidReceiveLocalNotification,
      notificationCategories: [
        DarwinNotificationCategory(
          'class_category',
          actions: [
            DarwinNotificationAction.plain('mark_present', 'Present'),
            DarwinNotificationAction.plain('mark_proxy', 'Proxy'),
            DarwinNotificationAction.plain('mark_absent', 'Absent',
                options: {DarwinNotificationActionOption.destructive}),
          ],
        )
      ],
    );

    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await flutterLocalNotificationsPlugin
        .initialize(
          initializationSettings,
          onDidReceiveNotificationResponse: onNotificationTap,
          onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
        )
        .then((_) => debugPrint("Notification Service Initialized"));

    // Create Channel explicitly for Android 8+
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'class_channel_config_v5', // id
        'Class Notifications', // title
        description: 'Notifications for scheduled classes',
        importance: Importance.max,
        playSound: true,
      );
      await androidImplementation.createNotificationChannel(channel);
    }

    // Timezone init
    await _configureLocalTimeZone();
  }

  static Future<void> _configureLocalTimeZone() async {
    tz.initializeTimeZones();
    final String timeZoneName = await FlutterTimezone.getLocalTimezone();
    try {
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      debugPrint("TIMEZONE SET: $timeZoneName");
      debugPrint("CURRENT LOCAL TIME: ${tz.TZDateTime.now(tz.local)}");
    } catch (e) {
      debugPrint("Failed to set location: $e");
    }
  }

  void onDidReceiveLocalNotification(
      int id, String? title, String? body, String? payload) async {
    // Handle iOS foreground notification
  }

  static final StreamController<Map<String, dynamic>> _navigationController =
      StreamController.broadcast();
  static Stream<Map<String, dynamic>> get navigationStream =>
      _navigationController.stream;

  static void onNotificationTap(NotificationResponse response) async {
    if (response.payload != null) {
      if (response.actionId == 'mark_present' ||
          response.actionId == 'mark_absent' ||
          response.actionId == 'mark_proxy' ||
          response.actionId == 'delete_notification') {
        await handleAction(response);
        _actionController.add(response);
      } else {
        // Normal Tap: App opens automatically.
        debugPrint("Notification tapped with payload: ${response.payload}");
        try {
          final payload = jsonDecode(response.payload!);
          _navigationController.add(payload);
        } catch (e) {
          debugPrint("Error parsing notification payload for navigation: $e");
        }
      }
    }
  }

  // Static Background Handler Removed - Moved to Top Level

  static Future<void> handleAction(NotificationResponse response) async {
    try {
      if (response.payload == null) return;
      final safePayload = response.payload!;

      // Special Test Handler
      if ((response.actionId == 'mark_present' &&
              safePayload.contains('TEST_SUBJECT_ID')) ||
          (response.actionId == 'mark_absent' &&
              safePayload.contains('TEST_SUBJECT_ID'))) {
        NotificationService.broadcastLog("Bg: Test Test Action Handled!");
        return;
      }

      debugPrint("Handling action: ${response.actionId} payload: $safePayload");

      final payloadMap = jsonDecode(safePayload);
      String? subjectId = payloadMap['subjectId'];
      if (subjectId != null && subjectId.isEmpty) {
        subjectId = null; // Fix: Treat empty as null for fallback
      }
      final templateId = payloadMap['templateId'];
      final sessionId = payloadMap['sessionId'];
      // final isLiveUpdate = payloadMap['liveUpdate'] == true; // Unused here

      // Ensure TimeZone is configured in Background
      await _configureLocalTimeZone();

      final prefs = await SharedPreferences.getInstance();
      await prefs.reload(); // Critical: Force refresh from disk

      final subjectsJson = prefs.getString('subjects');
      final sessionsJson = prefs.getString('sessions');
      final scheduleJson = prefs.getString('schedule');

      if (subjectsJson == null) return;

      // Load Data
      final List<dynamic> decodedSubjects = jsonDecode(subjectsJson);
      final List<Subject> subjects =
          decodedSubjects.map((x) => Subject.fromJson(x)).toList();

      List<ClassSession> sessions = [];
      if (sessionsJson != null) {
        final List<dynamic> decodedS = jsonDecode(sessionsJson);
        sessions = decodedS.map((x) => ClassSession.fromJson(x)).toList();
      }

      List<ScheduleTemplate> schedule = [];
      if (scheduleJson != null) {
        final List<dynamic> decodedSched = jsonDecode(scheduleJson);
        schedule =
            decodedSched.map((x) => ScheduleTemplate.fromJson(x)).toList();
      }

      // 1. Try to Resolve Subject ID using Session ID (Strongest Match)
      if (subjectId == null && sessionId != null) {
        final sessionIndex = sessions.indexWhere((s) => s.id == sessionId);
        if (sessionIndex != -1) {
          subjectId = sessions[sessionIndex].subjectId;
          debugPrint("Resolved SubjectId $subjectId from SessionId $sessionId");
        }
      }

      // 2. Fallback: If subjectId is null, try to find it via templateId
      ScheduleTemplate? template;
      if (templateId != null) {
        template = schedule
            .cast<ScheduleTemplate?>()
            .firstWhere((t) => t?.id == templateId, orElse: () => null);
        if (subjectId == null && template != null) {
          subjectId = template.subjectId;
        }
      }

      // If template is still null, try to find it by SubjectId and Day (Best Effort for legacy payloads)
      if (template == null && subjectId != null) {
        final now = DateTime.now();
        template = schedule.cast<ScheduleTemplate?>().firstWhere(
            (t) =>
                t?.subjectId == subjectId &&
                t?.dayOfWeek == now.weekday &&
                // Use a generous 2 hour window
                (t!.startTime.hour - now.hour).abs() <= 2,
            orElse: () => null);
      }

      // If still null, try finding subject by name from template?
      if (subjectId == null && template != null) {
        final sub = subjects.cast<Subject?>().firstWhere(
            (s) => s?.name == template?.subjectName,
            orElse: () => null);
        if (sub != null) subjectId = sub.id;
      }

      if (subjectId == null) {
        debugPrint("SubjectId could not be resolved. Aborting action.");
        await NotificationService().showInstantNotification(
            id: 88888,
            title: "Debug Error",
            body: "Could not resolve Subject ID. Action aborted.",
            ongoing: false);
        return;
      }

      int sIdx = subjects.indexWhere((s) => s.id == subjectId);

      // Lazy Subject Creation in Background
      if (sIdx == -1) {
        // We need name and color.
        // We might have 'template' from earlier resolution.
        // If not, we can't create it efficiently without more info.
        // But 'template' should be resolved by now if we found subjectId from it, or if templateId was passed.

        String? newName;
        int? newColor;

        if (template != null) {
          newName = template.subjectName;
          newColor = template.colorValue;
        } else {
          // Try to find name from sessions if any exist? Unlikely if subject is missing.
        }

        if (newName != null && newName.isNotEmpty) {
          debugPrint(
              "Creating Lazy Subject in Background: $newName ($subjectId)");
          final newSubject = Subject(
            id: subjectId,
            name: newName,
            colorValue: newColor,
            present: 0,
            absent: 0,
          );
          subjects.add(newSubject);
          sIdx = subjects.length - 1;
        } else {
          // Abort if we can't create
          return;
        }
      }

      final subject = subjects[sIdx];
      int newPresent = subject.present;
      int newAbsent = subject.absent;
      int newProxy = subject.proxy;
      int newAmbiguous = subject.ambiguous;

      AttendanceStatus newStatus = AttendanceStatus.pending;
      LogType logType = LogType.manual;

      if (response.actionId == 'mark_present') {
        newPresent++;
        newStatus = AttendanceStatus.present;
      } else if (response.actionId == 'mark_proxy') {
        newProxy++;
        newStatus = AttendanceStatus.proxy;
        logType = LogType.proxy;
      } else if (response.actionId == 'mark_absent') {
        newAbsent++;
        newStatus = AttendanceStatus.absent;
      } else if (response.actionId == 'mark_not_sure') {
        newAmbiguous++;
        newStatus = AttendanceStatus.ambiguous;
      } else if (response.actionId == 'delete_notification') {
        // Just cancel
        await _cancelNotification(response, templateId);
        return;
      }

      if (newStatus != AttendanceStatus.pending) {
        // 1. Sync with Session (Create or Update)
        // Sessions already loaded above.

        final now = DateTime.now();

        // Resolve Session ID for linking
        String resolvedSessionId = const Uuid().v4(); // Default new ID
        ClassSession? existingSession;
        int sessionIdx = -1;

        if (sessionId != null) {
          // Precise Match via Payload (Best for Live Activities/Sessions)
          sessionIdx = sessions.indexWhere((s) => s.id == sessionId);
          if (sessionIdx != -1) {
            // Ensure subjectId linkage if missing
            // subjectId is already guaranteed non-null here due to check at line 218
            // if (subjectId == null) subjectId = sessions[sessionIdx].subjectId;
          }
        }

        if (sessionIdx == -1 && template != null) {
          // Robust match by templateId and Date
          sessionIdx = sessions.indexWhere((s) =>
              s.templateId == template!.id &&
              s.startTime.year == now.year &&
              s.startTime.month == now.month &&
              s.startTime.day == now.day);

          if (sessionIdx == -1) {
            // Fallback time match
            sessionIdx = sessions.indexWhere((s) =>
                (s.subjectId == subjectId) &&
                s.startTime.year == now.year &&
                s.startTime.month == now.month &&
                s.startTime.day == now.day &&
                s.startTime.hour == template!.startTime.hour &&
                s.startTime.minute == template.startTime.minute);
          }
        } else if (sessionIdx == -1) {
          // Fallback subject match (Last Resort)
          sessionIdx = sessions.indexWhere((s) =>
              (s.subjectId == subjectId) &&
              s.startTime.year == now.year &&
              s.startTime.month == now.month &&
              s.startTime.day == now.day);
        }

        if (sessionIdx != -1) {
          existingSession = sessions[sessionIdx];
          resolvedSessionId = existingSession.id;
        }

        // 2. Update Subject stats and logs
        final newLog = AttendanceLog(
          timestamp: DateTime.now(),
          status: newStatus,
          type: logType,
          relatedSessionId: resolvedSessionId,
        );

        subjects[sIdx] = subject.copyWith(
          present: newPresent,
          absent: newAbsent,
          proxy: newProxy,
          ambiguous: newAmbiguous,
          logs: [...subject.logs, newLog],
        );
        await prefs.setString(
            'subjects', jsonEncode(subjects.map((x) => x.toJson()).toList()));

        // 3. Update or Create Session
        if (existingSession != null) {
          sessions[sessionIdx] = existingSession.copyWith(status: newStatus);
        } else {
          // Create NEW Session using resolvedSessionId
          if (template != null) {
            sessions.add(ClassSession(
              id: resolvedSessionId, // USE PRE-GENERATED or Payload ID
              subjectName: template.subjectName,
              subjectId: template.subjectId ?? subjectId,
              // Use precise template time so it matches 'isCompletedToday' check later
              startTime: DateTime(now.year, now.month, now.day,
                  template.startTime.hour, template.startTime.minute),
              endTime: DateTime(now.year, now.month, now.day,
                  template.endTime.hour, template.endTime.minute),
              colorValue: template.colorValue,
              status: newStatus,
              isConcrete: true,
              hasTime: template.hasTime,
              templateId: template.id,
              teacherName: template.teacherName,
            ));
          } else {
            // Fallback: simple session from Subject info
            sessions.add(ClassSession(
              id: resolvedSessionId,
              subjectName: subject.name,
              subjectId: subject.id,
              startTime: now,
              endTime: now.add(const Duration(hours: 1)),
              colorValue: subject.colorValue ?? 0xFF4287F5,
              status: newStatus,
              isConcrete: true,
            ));
          }
        }
        await prefs.setString(
            'sessions', jsonEncode(sessions.map((x) => x.toJson()).toList()));

        debugPrint(
            "Handled notification action: ${response.actionId} for $subjectId");

        // Notify Background Service execution isolate about the manual update
        try {
          final SendPort? bgPort =
              IsolateNameServer.lookupPortByName('madbunky_bg_service');
          if (bgPort != null) {
            bgPort.send({
              "sessionId": resolvedSessionId,
              "statusIndex": newStatus.index,
            });
            debugPrint("Sent manual_status_update to BG Port");
          } else {
            // Fallback: If bgPort is null, we might be in the main isolate 
            // where FlutterBackgroundService() is available.
            try {
              final service = FlutterBackgroundService();
              if (await service.isRunning()) {
                service.invoke("manual_status_update", {
                  "sessionId": resolvedSessionId,
                  "statusIndex": newStatus.index,
                });
              }
            } catch (_) {
              // We are likely in a background isolate where the plugin singleton is restricted.
              // Since the port lookup also failed, we just skip the signal.
              // The update is already persisted in SharedPreferences.
            }
          }
        } catch (e) {
          debugPrint("Failed to invoke background update: $e");
        }

        // Capture the updated session for display logic
        final ClassSession updatedSession =
            (existingSession != null) ? sessions[sessionIdx] : sessions.last;

        String statusText = "Present";
        if (newStatus == AttendanceStatus.absent) statusText = "Absent";
        if (newStatus == AttendanceStatus.proxy) statusText = "Proxy";

        // Logic Change: Check if class is technically still ongoing
        final isStillGoing = DateTime.now().isBefore(updatedSession.endTime);

        // Override: specific payload OR dynamically ongoing
        final isLiveUpdate = payloadMap['liveUpdate'] == true || isStillGoing;

        if (isLiveUpdate) {
          // LIVE ACTIVITY: Update content, Keep Ongoing, Don't Confirm/Dismiss
          final now = DateTime.now();
          final start = updatedSession.startTime;
          final end = updatedSession.endTime;
          final total = end.difference(start).inSeconds;
          final elapsed = now.difference(start).inSeconds;
          double progressPct = 0.0;
          if (total > 0) progressPct = (elapsed / total).clamp(0.0, 1.0);
          final int progressInt = (progressPct * 100).toInt();

          final remaining = end.difference(now);
          String remainingStr = "";
          if (remaining.isNegative) {
            remainingStr = "Ended";
          } else if (remaining.inHours > 0) {
            remainingStr =
                "${remaining.inHours}h ${remaining.inMinutes.remainder(60)}m left";
          } else if (remaining.inMinutes > 0) {
            remainingStr = "${remaining.inMinutes}m left";
          } else {
            remainingStr = "${remaining.inSeconds}s left";
          }

          // Manually update LiveActivityService state to prevent duplicate/stale 'Completion' notifications
          if (updatedSession.id.isNotEmpty) {
            LiveActivityService()
                .manuallyUpdateStatus(updatedSession.id, newStatus);
          }

          // Re-issue Sticky Notification with updated Status text
          await NotificationService().showInstantNotification(
            id: response.id ?? 99999, // Use Response ID to update in-place
            title: "Ongoing: ${updatedSession.subjectName}",
            body: "$remainingStr • $progressInt% • Status: $statusText",
            ongoing: true, // Keep it sticky as requested
            showProgress: true,
            progress: progressInt,
            maxProgress: 100,
            indeterminate: false,
            payload: response.payload!,
            when: start.millisecondsSinceEpoch,
            // Pass Details
            subjectName: updatedSession.subjectName,
            teacherName: updatedSession.teacherName,
            sessionStartTime: TimeOfDay.fromDateTime(start),
            sessionEndTime: TimeOfDay.fromDateTime(end),
            status: newStatus,
          );
        } else {
          // STANDARD: Cancel & Show Confirmation
          // STANDARD: Cancel & Show Confirmation Sequence
          await _cancelNotification(response, templateId);

          final plugin = FlutterLocalNotificationsPlugin();
          // Reuse ID if available to "replace" vertically, else use 88888
          final int confirmId = response.id ?? 88888;

          // Countdown Sequence (3s -> Dismiss)
          for (int i = 3; i > 0; i--) {
            await plugin.show(
              safeId(confirmId),
              "You marked $statusText ($i)", // Title with countdown
              "for ${subject.name}", // Body with class name
              const NotificationDetails(
                android: AndroidNotificationDetails(
                  'class_channel_config_v5',
                  'Class Notifications',
                  importance: Importance.max,
                  priority: Priority.high,
                  onlyAlertOnce: true, // Don't buzz on updates
                  autoCancel: true,
                  timeoutAfter: 4000, // Safety net
                ),
                iOS: DarwinNotificationDetails(),
              ),
            );
            await Future.delayed(const Duration(seconds: 1));
          }

          // Final Dismiss
          await plugin.cancel(safeId(confirmId));
        }

        // Notify Main Isolate to reload UI
        final SendPort? sendPort =
            IsolateNameServer.lookupPortByName('notification_port');
        if (sendPort != null) {
          debugPrint(
              "Messaging Main Isolate to RELOAD DATA with Action: ${response.actionId}");
          // Send FULL response so Main Isolate shows correct SnackBar feedback
          sendPort.send(response);
        }
      }
    } catch (e) {
      debugPrint("Error handling notification action: $e");
      // Silenced Debug Exception Notification per user request
    }
  }

  static Future<void> _cancelNotification(
      NotificationResponse response, String? templateId) async {
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    // 1. Try canceling by ID from response
    if (response.id != null) {
      await flutterLocalNotificationsPlugin.cancel(response.id!);
      // Also cancel potential Paired Notifications (Finish/Start)
      await flutterLocalNotificationsPlugin
          .cancel(safeId(response.id! + 100000));
      await flutterLocalNotificationsPlugin
          .cancel(safeId(response.id! - 100000));
    }
    // 2. Explicitly cancel by templateId hash
    if (templateId != null) {
      await flutterLocalNotificationsPlugin.cancel(safeId(templateId.hashCode));
    }
  }

  Future<void> scheduleClassNotification({
    required int id,
    required String title,
    int? when, // Timestamp override
    required String body,
    required DateTime scheduledTime,
    required String payload,
    int? durationMinutes,
    bool isRepeating = true,
    bool ongoing = false, // Added sticky support
    // Optional params for Custom Image
    TimeOfDay? sessionStartTime,
    TimeOfDay? sessionEndTime,
    String? subjectName,
    String? teacherName,
    String? room,
    bool showProgress = false,
    int progress = 0,
    int maxProgress = 100,
    bool indeterminate = false,
    bool silentMode = false, // Added silentMode
  }) async {
    // Ensure timezone is correct / up-to-date
    await _configureLocalTimeZone();

    // Generate Image if info available
    // Check payload for 'liveUpdate' optimization
    BigPictureStyleInformation? bigPictureStyleInformation;

    // Only generate big picture if NOT a live update (to prevent flickering/lag and ensure progress bar visibility)
    // Always try to generate Big Picture if details are present (Rich UI Policy)
    // Caching in NotificationImageGenerator ensures performance.

    if (subjectName != null &&
        sessionStartTime != null &&
        sessionEndTime != null) {
      try {
        // Construct temp session for generator
        final tempSession = ClassSession(
            id: id.toString(), // deterministic ID for cache hit
            subjectName: subjectName,
            // Use dummy date, time matters for generator
            startTime: DateTime(
                2024, 1, 1, sessionStartTime.hour, sessionStartTime.minute),
            endTime: DateTime(
                2024, 1, 1, sessionEndTime.hour, sessionEndTime.minute),
            colorValue: 0,
            teacherName: teacherName ?? room);

        final imagePath =
            await NotificationImageGenerator.generateAndSave(tempSession);

        if (imagePath != null) {
          bigPictureStyleInformation = BigPictureStyleInformation(
            FilePathAndroidBitmap(imagePath),
            hideExpandedLargeIcon: true,
            contentTitle: title,
            htmlFormatContentTitle: true,
            summaryText: body,
            htmlFormatSummaryText: true,
          );
        }
      } catch (e) {
        debugPrint("Image generation failed: $e");
      }
    }

    try {
      // Explicitly cancel the ID first to ensure any existing (stale) notification or scheduled alarm is removed.
      await flutterLocalNotificationsPlugin.cancel(safeId(id));

      await flutterLocalNotificationsPlugin.zonedSchedule(
        safeId(id),
        title,
        body,
        tz.TZDateTime.from(scheduledTime, tz.local),
        NotificationDetails(
          android: AndroidNotificationDetails(
            'class_channel_config_v5',
            'Class Notifications',
            channelDescription: 'Notifications for scheduled classes',
            importance: silentMode ? Importance.low : Importance.max,
            priority: silentMode ? Priority.low : Priority.high,
            playSound: !silentMode,
            enableVibration: !silentMode,
            fullScreenIntent: true, // Aggressive Mode
            category: AndroidNotificationCategory.event,
            styleInformation: bigPictureStyleInformation,
            ongoing: ongoing, // Use parameter
            autoCancel: !ongoing, // If sticky, don't auto cancel on tap
            // Progress Bar Support
            showProgress: showProgress,
            maxProgress: maxProgress,
            progress: progress,
            indeterminate: indeterminate,
            // Added Actions
            actions: [
              const AndroidNotificationAction(
                'mark_present',
                'Present',
                icon: DrawableResourceAndroidBitmap('ic_check'),
                showsUserInterface: false,
                cancelNotification: false, // Keep sticky
              ),
              const AndroidNotificationAction(
                'mark_proxy',
                '⚡',
                icon: DrawableResourceAndroidBitmap('ic_thunder'),
                showsUserInterface: false,
                cancelNotification: false, // Keep sticky
              ),
              const AndroidNotificationAction(
                'mark_absent',
                'Absent',
                icon: DrawableResourceAndroidBitmap('ic_close'),
                showsUserInterface: false,
                cancelNotification: false, // Keep sticky
              ),
            ],
            onlyAlertOnce: true,
            when: when,
            sound: null,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            // sound: 'madbunky.wav', // Removed custom sound
            categoryIdentifier: 'class_category',
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
        matchDateTimeComponents:
            isRepeating ? DateTimeComponents.dayOfWeekAndTime : null,
      );
      debugPrint(
          "Scheduled Notification: ID=$id, Title=$title, Time=$scheduledTime, Repeating=$isRepeating, TZ=${tz.local.name}");

      // ---------------------------------------------------------
      // FINISH NOTIFICATION REMOVED (Merged into Sticky Lifecycle)
      // ---------------------------------------------------------
    } catch (e) {
      debugPrint("FAILED to schedule notification: $e");
      // Fallback to inexact if exact fails?
      // For now, failure to schedule is critical to know.
    }
  }

  Future<void> showWelcomeNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'class_channel_config_v5',
      'Class Notifications',
      channelDescription: 'Notifications for scheduled classes',
      importance: Importance.max,
      priority: Priority.high,
      // sound: RawResourceAndroidNotificationSound('bell_sound'), // Removed
    );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: DarwinNotificationDetails(),
    );
    await flutterLocalNotificationsPlugin.show(
      0,
      'Welcome to MadBunky Pro',
      'Notifications configured successfully!',
      platformChannelSpecifics,
    );
  }

  Future<void> _ensureAndroidChannel() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'class_channel_config_v5',
        'Class Notifications',
        description: 'Notifications for scheduled classes',
        importance: Importance.max,
        playSound: true,
      );
      await androidImplementation.createNotificationChannel(channel);
    }
  }

  Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    bool ongoing = false,
    bool showProgress = false,
    int progress = 0,
    int maxProgress = 100,
    bool indeterminate = false,
    int? when,
    bool silentMode = false,
    // Custom Image Params
    String? subjectName,
    String? teacherName,
    TimeOfDay? sessionStartTime,
    TimeOfDay? sessionEndTime,
    AttendanceStatus? status, // Added Status for button highlight
    bool useChronometer = false,
    bool chronometerCountDown = false,
    bool showCompletionActions = false, // New param
  }) async {
    // Ensure Channel Exists (Critical for Background Isolate)
    if (!silentMode && defaultTargetPlatform == TargetPlatform.android) {
      await _ensureAndroidChannel();
    }

    // Generate Actions based on Status
    List<AndroidNotificationAction> customActions = [];
    if (ongoing || showCompletionActions) {
      customActions = [
        AndroidNotificationAction(
          'mark_present',
          (status == AttendanceStatus.present) ? '✅ Present' : 'Present',
          icon: DrawableResourceAndroidBitmap('ic_check'),
          showsUserInterface: false,
          cancelNotification: false, // Keep sticky
        ),
        AndroidNotificationAction(
          'mark_proxy',
          (status == AttendanceStatus.proxy) ? '⚡' : '⚡',
          icon: DrawableResourceAndroidBitmap('ic_thunder'),
          showsUserInterface: false,
          cancelNotification: false, // Keep sticky
        ),
        AndroidNotificationAction(
          'mark_absent',
          (status == AttendanceStatus.absent) ? '❌ Absent' : 'Absent',
          icon: DrawableResourceAndroidBitmap('ic_close'),
          showsUserInterface: false,
          cancelNotification: false, // Keep sticky
        ),
      ];
    }
    BigPictureStyleInformation? bigPictureStyleInformation;

    if (subjectName != null &&
        sessionStartTime != null &&
        sessionEndTime != null) {
      try {
        final tempSession = ClassSession(
            id: id.toString(), // deterministic ID for cache hit
            subjectName: subjectName,
            startTime: DateTime(
                2024, 1, 1, sessionStartTime.hour, sessionStartTime.minute),
            endTime: DateTime(
                2024, 1, 1, sessionEndTime.hour, sessionEndTime.minute),
            colorValue: 0,
            teacherName: teacherName ?? 'Class');
        final imagePath =
            await NotificationImageGenerator.generateAndSave(tempSession);
        if (imagePath != null) {
          bigPictureStyleInformation = BigPictureStyleInformation(
            FilePathAndroidBitmap(imagePath),
            hideExpandedLargeIcon: true,
            contentTitle: title,
            htmlFormatContentTitle: true,
            summaryText: body,
            htmlFormatSummaryText: true,
          );
        }
      } catch (e) {
        debugPrint("Image gen error in instant notification: $e");
      }
    }
    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'class_channel_config_v5',
      'Class Notifications',
      channelDescription: 'Notifications for scheduled classes',
      importance: silentMode ? Importance.low : Importance.max,
      priority: silentMode ? Priority.low : Priority.high,
      playSound: !silentMode,
      enableVibration: !silentMode,
      ongoing: ongoing,
      autoCancel: !ongoing,
      showProgress: showProgress,
      maxProgress: maxProgress,
      progress: progress,
      indeterminate: indeterminate,
      // Chronometer Support
      usesChronometer: useChronometer,
      chronometerCountDown: chronometerCountDown,

      onlyAlertOnce: true,
      when: when, // Set timestamp explicitly
      styleInformation: bigPictureStyleInformation,
      actions: customActions,
    );
    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: DarwinNotificationDetails(),
    );

    try {
      await flutterLocalNotificationsPlugin.show(
        safeId(id),
        title,
        body,
        platformChannelSpecifics,
        payload: payload,
      );
    } catch (e) {
      debugPrint("Error showing instant notification: $e");
    }
  }

  // Test Method for User Verification
  Future<void> showTestNotification() async {
    final int id = 999;
    final String subjectId = "TEST_SUBJECT_ID";
    final payload = jsonEncode({
      'subjectId': subjectId,
      'sessionId': 'TEST_SESSION_ID',
      'liveUpdate': false,
      'action': 'test_debug'
    });

    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'class_channel_config_v5',
      'Class Notifications',
      importance: Importance.max,
      priority: Priority.high,
      actions: [
        AndroidNotificationAction('mark_present', 'Test Present',
            showsUserInterface: false, cancelNotification: false),
        AndroidNotificationAction('mark_absent', 'Test Absent',
            showsUserInterface: false, cancelNotification: false),
      ],
    );

    final NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      id,
      'Test Notification 🛠️',
      'Tap a button to test background actions.',
      platformChannelSpecifics,
      payload: payload,
    );
  }

  Future<void> requestPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      final bool? granted =
          await androidImplementation.requestNotificationsPermission();

      // Request Exact Alarms (Android 12+)
      try {
        await androidImplementation.requestExactAlarmsPermission();
      } catch (e) {
        debugPrint("Error requesting exact alarms: $e");
      }

      if (granted == true) {
        // Check if first run for notifications
        final prefs = await SharedPreferences.getInstance();
        final bool alreadyWelcomed =
            prefs.getBool('welcome_notification_shown') ?? false;
        if (!alreadyWelcomed) {
          await showWelcomeNotification();
          await prefs.setBool('welcome_notification_shown', true);
        }
      }
    }
    final iOSImplementation =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();

    if (iOSImplementation != null) {
      await iOSImplementation.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  Future<void> cancelType(int id) async {
    await flutterLocalNotificationsPlugin.cancel(safeId(id));
  }

  Future<void> cancelAll() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  // Test methods removed
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) async {
  // Critical fix: Ensure binding is initialized for plugins in background
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint("Background Action Received (Top-Level): ${response.actionId}");

  // 1. Tell Main App we started
  NotificationService.broadcastLog("Bg Start: ${response.actionId}");

  try {
    if (response.payload == null) {
      NotificationService.broadcastLog("Bg Error: Payload is null");
      return;
    }

    // Special Test Handler
    if ((response.actionId == 'mark_present' ||
            response.actionId == 'mark_absent') &&
        response.payload!.contains('TEST_SUBJECT_ID')) {
      NotificationService.broadcastLog("Bg: Test Test Action Handled!");
      NotificationService.broadcastAction(response);
      return;
    }

    // Call internal logic
    await NotificationService.handleAction(response);

    // Notify Main Isolate to reload
    NotificationService.broadcastAction(response);
    NotificationService.broadcastLog("Bg Success");
  } catch (e) {
    debugPrint("FATAL Background Error: $e");
    NotificationService.broadcastLog("Bg Error: $e");
  }
}

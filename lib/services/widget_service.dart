import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';

import 'dart:isolate';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'log_service.dart'; // Added
import '../models/models.dart';
import '../widgets/app_widget.dart';
import '../widgets/subject_summary_widget.dart';
import '../widgets/subject_card_widget_content.dart';
import '../utils/widget_id_manager.dart';

class WidgetService {
  static const String _myDayWidgetProvider = 'MyDayWidgetProvider';

  static Future<void> updateMyDayWidget(
      List<ClassSession> sessions, List<ScheduleTemplate> schedule,
      {List<Subject>? subjects}) async {
    try {
      final today = DateTime.now();

      // 1. Get concrete sessions for today (same logic)
      final todaysSessions = sessions.where((s) {
        return s.startTime.year == today.year &&
            s.startTime.month == today.month &&
            s.startTime.day == today.day;
      }).toList();

      // 2. Get templates for today
      final todaysTemplates =
          schedule.where((t) => t.dayOfWeek == today.weekday).toList();

      final displaySessions = <ClassSession>[];

      for (final t in todaysTemplates) {
        try {
          final matchingSessionIndex = todaysSessions.indexWhere((s) {
            if (t.id.isNotEmpty && s.templateId == t.id) return true;
            return (s.subjectId == t.subjectId ||
                    (s.subjectId == null && s.subjectName == t.subjectName)) &&
                s.startTime.hour == t.startTime.hour &&
                s.startTime.minute == t.startTime.minute;
          });

          if (matchingSessionIndex != -1) {
            final session = todaysSessions[matchingSessionIndex];
            if (!session.isCancelled) {
              displaySessions.add(session);
            }
          } else {
            // Create pseudo-session for template
            final startDt = DateTime(today.year, today.month, today.day,
                t.startTime.hour, t.startTime.minute);
            final endDt = DateTime(today.year, today.month, today.day,
                t.endTime.hour, t.endTime.minute);

            displaySessions.add(ClassSession(
              id: "template_${t.id}",
              subjectName: t.subjectName,
              subjectId: t.subjectId,
              startTime: startDt,
              endTime: endDt,
              colorValue: t.colorValue,
              status: AttendanceStatus.pending,
            ));
          }
        } catch (e) {
          debugPrint("Error processing template ${t.id}: $e");
        }
      }
      // Add extra sessions that are not in template
      for (var s in todaysSessions) {
        if (!displaySessions.any((ds) => ds.id == s.id)) {
          displaySessions.add(s);
        }
      }

      displaySessions.sort((a, b) => a.startTime.compareTo(b.startTime));

      // Calculate Overall Health if subjects provided
      AttendanceHealth? health;
      if (subjects != null && subjects.isNotEmpty) {
        try {
          // Find 'worst' subject? Or general status?
          int maxDeficit = 0;
          Subject? worstSubject;

          for (var s in subjects) {
            int prediction = _calculatePrediction(s);
            if (prediction < 0 && prediction.abs() > maxDeficit) {
              maxDeficit = prediction.abs();
              worstSubject = s;
            }
          }

          if (worstSubject != null) {
            health = AttendanceHealth(
                "Must attend $maxDeficit classes of ${worstSubject.name}",
                const Color(0xFFE53935), // Red
                worstSubject.currentPercentage);
          } else {
            health = AttendanceHealth(
                "On Track! Keep it up.",
                const Color(0xFF43A047), // Green
                100.0);
          }
        } catch (e) {
          debugPrint("Error calculating health: $e");
        }
      }

      // Render Image Widget - Wrapped in MaterialApp for Context
      try {
        await HomeWidget.renderFlutterWidget(
          _headlessWrapper(
            AppWidget(
              todaysSessions: displaySessions,
              overallHealth: health,
            ),
            const Size(320, 160),
          ),
          key: 'my_day_widget_image',
          logicalSize: const Size(320, 160),
          pixelRatio: 2.0,
        );
      } catch (e) {
        debugPrint("Error rendering AppWidget: $e");
      }

      // Save Data for Native List Widget (MyDayWidgetProvider)
      try {
        final nativeData = displaySessions.map((s) {
          int statusInt = 0;
          switch (s.status) {
            case AttendanceStatus.present:
              statusInt = 1;
              break;
            case AttendanceStatus.absent:
              statusInt = 2;
              break;
            case AttendanceStatus.proxy:
              statusInt = 3;
              break;
            default:
              statusInt = 0;
          }

          return {
            'id': s.id,
            'subjectName': s.subjectName,
            'startTime': s.startTime.millisecondsSinceEpoch,
            'endTime': s.endTime.millisecondsSinceEpoch,
            'status': statusInt,
            'color': s.colorValue,
          };
        }).toList();

        await HomeWidget.saveWidgetData<String>(
            'my_day_data', jsonEncode(nativeData));

        // Update Native Widget
        await HomeWidget.updateWidget(
          name: _myDayWidgetProvider,
          androidName: _myDayWidgetProvider,
        );
      } catch (e) {
        debugPrint("Error saving native widget data: $e");
      }

      // Update iOS Lock Screen Data
      try {
        await updateiOSLockScreenWidgets(displaySessions, subjects);
      } catch (e) {
        debugPrint("Error updating iOS widgets: $e");
      }
    } catch (e, stack) {
      debugPrint("CRITICAL_WIDGET_UPDATE_ERROR: $e");
      // Use fire-and-forget log to avoid blocking if init missing (WidgetService handles sync/main)
      LogService().error("CRITICAL_WIDGET_UPDATE_ERROR", stack);
      debugPrintStack(stackTrace: stack);
    }
  }

  static Future<void> updateiOSLockScreenWidgets(
      List<ClassSession> sessions, List<Subject>? subjects) async {
    // 1. Calculate 'Next Class' Info
    final now = DateTime.now();
    ClassSession? nextClass;

    // Filter for FUTURE classes
    final futureClasses = sessions.where((s) {
      if (s.isCancelled) return false;
      return s.startTime.isAfter(now);
    }).toList();

    // Also include classes currently happening? Sticky Notification covers that.
    // Lock Screen usually shows "Next Event" or "Current Event".
    // Let's Find the *very next* thing, or current if active.

    final activeClasses = sessions.where((s) {
      return !s.isCancelled &&
          now.isAfter(s.startTime) &&
          now.isBefore(s.endTime);
    }).toList();

    if (activeClasses.isNotEmpty) {
      nextClass = activeClasses.first; // Is actually current
    } else if (futureClasses.isNotEmpty) {
      futureClasses.sort((a, b) => a.startTime.compareTo(b.startTime));
      nextClass = futureClasses.first;
    }

    if (nextClass != null) {
      // Format Time
      final timeStr =
          "${nextClass.startTime.hour}:${nextClass.startTime.minute.toString().padLeft(2, '0')}";

      await HomeWidget.saveWidgetData<String>(
          'next_class_name', nextClass.subjectName);
      await HomeWidget.saveWidgetData<String>('next_class_time', timeStr);
      await HomeWidget.saveWidgetData<String>(
          'next_class_room', nextClass.teacherName ?? "Classroom");
    } else {
      await HomeWidget.saveWidgetData<String>('next_class_name', "No Classes");
      await HomeWidget.saveWidgetData<String>('next_class_time', "--:--");
      await HomeWidget.saveWidgetData<String>('next_class_room', "");
    }

    // 2. Calculate Overall Attendance %
    double avgPercent = 0.0;
    if (subjects != null && subjects.isNotEmpty) {
      double totalPercent = 0;
      int count = 0;
      for (var s in subjects) {
        if (s.total > 0) {
          totalPercent += s.currentPercentage;
          count++;
        }
      }
      if (count > 0) avgPercent = totalPercent / count;
    }

    await HomeWidget.saveWidgetData<double>(
        'avg_attendance_percent', avgPercent);

    // Trigger update for iOS
    await HomeWidget.updateWidget(
      name: 'LockScreenWidget', // Match logic in Swift
      iOSName: 'LockScreenWidget',
    );
  }

  static int _calculatePrediction(Subject s) {
    // Simplified prediction logic for widget display
    // This should match your main app logic ideally
    int attended = s.present + s.proxy;
    int total = s.total;
    int target = s.targetPercentage;

    if (total == 0) return 0;

    double current = (attended / total) * 100;
    if (current >= target) {
      // Bunkable
      int present = attended;
      int abs = s.absent;
      int bunkable = 0;
      while (true) {
        if (present + abs + bunkable == 0) break;
        if (((present) / (present + abs + bunkable + 1)) * 100 < target) break;
        bunkable++;
      }
      return bunkable;
    } else {
      // Need to attend
      int present = attended;
      int abs = s.absent;
      int needed = 0;
      while (true) {
        if (((present + needed + 1) / (present + abs + needed + 1)) * 100 >=
            target) {
          needed++;
          break;
        }
        needed++;
        if (needed > 100) break; // Safety break
      }
      return -needed;
    }
  }

  // --- Subject Stats Widget Logc ---

  static const String _subjectStatsWidgetProvider =
      'SubjectStatsWidgetProvider';

  static Future<void> updateSubjectStatsWidgets(List<Subject> subjects) async {
    // 1. Get all widget IDs that are active for this provider
    try {
      final widgetIds = await WidgetIdManager.getSubjectStatsWidgetIds();

      for (final widgetId in widgetIds) {
        // 2. Get saved configuration for this widgetId
        final subjectId =
            await WidgetIdManager.getSubjectIdForStatsWidget(widgetId);

        if (subjectId != null) {
          final subject = subjects.firstWhere(
            (s) => s.id == subjectId,
            orElse: () =>
                Subject(name: 'Unknown', id: '', colorValue: 0, logs: []),
          );

          if (subject.id.isNotEmpty) {
            await _renderSubjectStats(widgetId, subject);
          }
        }
      }
    } catch (e) {
      debugPrint("Error updating subject stats widgets: $e");
    }
  }

  static Future<void> _renderSubjectStats(int widgetId, Subject subject) async {
    await HomeWidget.renderFlutterWidget(
      _headlessWrapper(
        SubjectSummaryWidget(subject: subject),
        const Size(150, 150),
      ),
      key: 'subject_stats_image',
      logicalSize: const Size(150, 150),
      pixelRatio: 2.0,
    );

    // We update specifically by ID? HomeWidget.updateWidget doesn't easily support targeting ONE ID with specific data
    // unless we use different keys.
    // WORKAROUND: renderFlutterWidget saves the image to a file.
    // We need to tell the Native Widget to load THIS file.
    // Standard `updateWidget` broadcasts update.

    // Actually, `renderFlutterWidget` saves to a filename 'subject_stats_image'.
    // If we have multiple widgets, they will overwrite each other's image file if we use same key!
    // FIX: Use unique key per widgetId.

    final key = 'subject_stats_$widgetId';
    await HomeWidget.renderFlutterWidget(
      _headlessWrapper(
        SubjectSummaryWidget(subject: subject),
        const Size(150, 150),
      ),
      key: key,
      logicalSize: const Size(150, 150),
      pixelRatio: 2.0,
    );

    // Update the widget
    // We need to pass the filename to the native side so it knows which image to load.
    await HomeWidget.saveWidgetData<String>('filename_$widgetId', key);

    // Trigger update for this widget
    // We can't trigger partial update easily from Flutter for just one ID.
    // But we can trigger global update, and Native side will read 'filename_$id' for each ID.
    await HomeWidget.updateWidget(
      name: _subjectStatsWidgetProvider,
      androidName: _subjectStatsWidgetProvider,
    );
  }

  // Register callback for background interactivity (Updated)
  static Future<void> registerCallback() async {
    await HomeWidget.registerInteractivityCallback(backgroundCallback);
  }

  // ... helper for background callback ...

  // --- Subject Card Widget Logic ---
  static const String _subjectCardWidgetProvider = 'SubjectCardWidgetProvider';

  static Future<void> updateSubjectCardWidgets(List<Subject> subjects) async {
    try {
      final ids = await WidgetIdManager.getSubjectCardWidgetIds();
      for (final id in ids) {
        final subjectId = await WidgetIdManager.getSubjectIdForWidget(id);
        if (subjectId != null) {
          final subject = subjects.firstWhere((s) => s.id == subjectId,
              orElse: () =>
                  Subject(name: 'Unknown', id: '', colorValue: 0, logs: []));
          if (subject.id.isNotEmpty) {
            await _renderSubjectCard(id, subject);
          }
        }
      }
      await HomeWidget.updateWidget(
        name: _subjectCardWidgetProvider,
        androidName: _subjectCardWidgetProvider,
      );
    } catch (e) {
      debugPrint("Error updating subject card widgets: $e");
    }
  }

  static Future<void> _renderSubjectCard(int widgetId, Subject subject) async {
    final key = 'subject_card_$widgetId';
    await HomeWidget.renderFlutterWidget(
      _headlessWrapper(
        SubjectCardContentWidget(subject: subject),
        const Size(300, 120),
      ),
      key: key,
      logicalSize: const Size(300, 120),
      pixelRatio: 2.0,
    );

    await HomeWidget.saveWidgetData<String>('filename_$widgetId', key);
  }

  static Widget _headlessWrapper(Widget child, Size size) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: MediaQueryData(size: size),
        child: Material(
          color: Colors.transparent,
          child: child,
        ),
      ),
    );
  }
}

// ... helper for background callback ...

@pragma('vm:entry-point')
Future<void> backgroundCallback(Uri? uri) async {
  if (uri?.host == 'action' && uri?.pathSegments.isNotEmpty == true) {
    final action = uri!.pathSegments.first;
    // Check if it's a Subject Card action (id=subject_card)
    final sourceId = uri.queryParameters['id']; // "subject_card"

    if (sourceId == 'subject_card') {
      // Handle Subject Card Action
      final widgetIdStr = uri.queryParameters['widgetId'];
      if (widgetIdStr != null) {
        final widgetId = int.tryParse(widgetIdStr);
        if (widgetId != null) {
          await _handleSubjectCardAction(widgetId, action);
        }
      }
    } else {
      // Existing MyDay Logic (sourceId is session ID)
      final id = sourceId;

      if (id != null) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.reload();

          // 1. Load Data
          final subjectsJson = prefs.getString('subjects');
          final sessionsJson = prefs.getString('sessions');
          final scheduleJson = prefs.getString('schedule');

          if (subjectsJson == null || sessionsJson == null) return;

          List<Subject> subjects = (jsonDecode(subjectsJson) as List)
              .map((e) => Subject.fromJson(e))
              .toList();
          List<ClassSession> sessions = (jsonDecode(sessionsJson) as List)
              .map((e) => ClassSession.fromJson(e))
              .toList();

          List<ScheduleTemplate> schedule = [];
          if (scheduleJson != null) {
            schedule = (jsonDecode(scheduleJson) as List)
                .map((e) => ScheduleTemplate.fromJson(e))
                .toList();
          }

          // 2. Find and Update Session
          final sessionIndex = sessions.indexWhere((s) => s.id == id);
          if (sessionIndex == -1) return;

          final session = sessions[sessionIndex];
          final subjectId = session.subjectId;

          AttendanceStatus newStatus;
          switch (action) {
            case 'present':
              newStatus = AttendanceStatus.present;
              break;
            case 'absent':
              newStatus = AttendanceStatus.absent;
              break;
            case 'proxy':
              newStatus = AttendanceStatus.proxy;
              break;
            default:
              return;
          }

          AttendanceStatus oldStatus = session.status;
          sessions[sessionIndex] = session.copyWith(status: newStatus);

          // 3. Update Subject Stats
          // Only update if subjectId is valid
          if (subjectId != null) {
            final subjectIndex = subjects.indexWhere((s) => s.id == subjectId);
            // ... logic same as existing ...
            if (subjectIndex != -1) {
              // ... (Copied logic or refactored) ...
              subjects[subjectIndex] = _updateSubjectStats(
                  subjects[subjectIndex], oldStatus, newStatus);
            }
          } else if (session.subjectName.isNotEmpty) {
            // Fuzzy match subject name?
            final subjectIndex =
                subjects.indexWhere((s) => s.name == session.subjectName);
            if (subjectIndex != -1) {
              subjects[subjectIndex] = _updateSubjectStats(
                  subjects[subjectIndex], oldStatus, newStatus);
            }
          }

          // 4. Save Back
          await prefs.setString(
              'subjects', jsonEncode(subjects.map((e) => e.toJson()).toList()));
          await prefs.setString(
              'sessions', jsonEncode(sessions.map((e) => e.toJson()).toList()));

          await WidgetService.updateMyDayWidget(sessions, schedule);
          // Also update card widgets just in case stats changed
          await WidgetService.updateSubjectCardWidgets(subjects);

          // Notify Main
          _notifyMainIsolate();
        } catch (e) {
          // print('Error in widget background callback: $e');
        }
      }
    }
  }
}

Future<void> _handleSubjectCardAction(int widgetId, String action) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();

  // Get Subject ID for this widget
  // We can use WidgetIdManager logic, BUT we are in a static background callback.
  // WidgetIdManager uses standard SharedPreferences, so it's safe.
  final subjectId = await WidgetIdManager.getSubjectIdForWidget(widgetId);
  if (subjectId == null) return;

  // Load Subjects
  final subjectsJson = prefs.getString('subjects');
  if (subjectsJson == null) return;
  List<Subject> subjects = (jsonDecode(subjectsJson) as List)
      .map((e) => Subject.fromJson(e))
      .toList();

  final index = subjects.indexWhere((s) => s.id == subjectId);
  if (index == -1) return;

  Subject subject = subjects[index];

  AttendanceStatus status;
  switch (action) {
    case 'present':
      status = AttendanceStatus.present;
      break;
    case 'absent':
      status = AttendanceStatus.absent;
      break;
    case 'proxy':
      status = AttendanceStatus.proxy;
      break;
    default:
      return;
  }

  // Update count
  int present = subject.present;
  int absent = subject.absent;
  int proxy = subject.proxy;

  if (status == AttendanceStatus.present) present++;
  if (status == AttendanceStatus.absent) absent++;
  if (status == AttendanceStatus.proxy) proxy++;

  // Add Log
  final newLog = AttendanceLog(
      timestamp: DateTime.now(), status: status, type: LogType.manual);

  subject = subject.copyWith(
      present: present,
      absent: absent,
      proxy: proxy,
      logs: [...subject.logs, newLog]);

  subjects[index] = subject;

  // Save
  await prefs.setString(
      'subjects', jsonEncode(subjects.map((e) => e.toJson()).toList()));

  // Update THIS widget specifically (and others)
  // We can just call updateAll
  await WidgetService.updateSubjectCardWidgets(subjects);
  // Also update stats widgets
  await WidgetService.updateSubjectStatsWidgets(subjects);

  _notifyMainIsolate();
}

Subject _updateSubjectStats(
    Subject subject, AttendanceStatus oldStatus, AttendanceStatus newStatus) {
  int present = subject.present;
  int absent = subject.absent;
  int proxy = subject.proxy;
  int ambiguous = subject.ambiguous;

  if (oldStatus == AttendanceStatus.present) present--;
  if (oldStatus == AttendanceStatus.absent) absent--;
  if (oldStatus == AttendanceStatus.proxy) proxy--;
  if (oldStatus == AttendanceStatus.ambiguous) ambiguous--;

  if (newStatus == AttendanceStatus.present) present++;
  if (newStatus == AttendanceStatus.absent) absent++;
  if (newStatus == AttendanceStatus.proxy) proxy++;
  if (newStatus == AttendanceStatus.ambiguous) ambiguous++;

  return subject.copyWith(
    present: present,
    absent: absent,
    proxy: proxy,
    ambiguous: ambiguous,
    // logs not updated here in this snippet, ideally should be
  );
}

void _notifyMainIsolate() {
  try {
    final SendPort? sendPort =
        IsolateNameServer.lookupPortByName('notification_port');
    if (sendPort != null) {
      sendPort.send("reload_data");
    }
  } catch (e) {
    // SendPort might not be available if app is backgrounded/terminated
  }
}

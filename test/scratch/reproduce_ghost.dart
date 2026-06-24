// ignore_for_file: avoid_print

import 'package:flutter/material.dart';

// Mock Classes
class ScheduleTemplate {
  final String id;
  final String subjectName;
  final String? subjectId;
  final int dayOfWeek;
  final TimeOfDay startTime;
  final TimeOfDay endTime;

  ScheduleTemplate({
    required this.id,
    required this.subjectName,
    this.subjectId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
  });
}

class ClassSession {
  final String id;
  final String templateId;
  final String subjectName;
  final String? subjectId;
  final DateTime startTime;
  final DateTime endTime;
  final bool isCancelled;
  final String status;

  ClassSession({
    required this.id,
    this.templateId = '',
    required this.subjectName,
    this.subjectId,
    required this.startTime,
    required this.endTime,
    this.isCancelled = false,
    this.status = 'present',
  });
}

// Logic under test (The "Fixed" logic from before)
List<dynamic> getDisplayItemsForDay(DateTime date, List<ClassSession> sessions,
    List<ScheduleTemplate> schedule) {
  final sessionsForDay =
      sessions.where((s) => s.startTime.day == date.day).toList();
  final templatesForDay =
      schedule.where((t) => t.dayOfWeek == date.weekday).toList();

  final displayItems = <dynamic>[];
  final handledSessionIds = <String>{};

  for (final t in templatesForDay) {
    // Find ALL matching sessions for this template
    final matchingSessions = sessionsForDay.where((s) {
      // Robust Match
      if (t.id.isNotEmpty && s.templateId == t.id) {
        return true;
      }
      // Fallback: Fuzzy Time & Subject Match
      return (s.subjectId == t.subjectId ||
              (s.subjectId == null && s.subjectName == t.subjectName)) &&
          s.startTime.hour == t.startTime.hour &&
          s.startTime.minute == t.startTime.minute;
    }).toList();

    if (matchingSessions.isNotEmpty) {
      final validSession = matchingSessions.firstWhere(
        (s) => !s.isCancelled,
        orElse: () => matchingSessions.first,
      );

      if (!validSession.isCancelled) {
        displayItems.add(validSession);
      } else {
        print(
            "DEBUG: Template ${t.subjectName} hidden by session ${validSession.id} (Cancelled)");
      }

      for (var s in matchingSessions) {
        handledSessionIds.add(s.id);
      }
    } else {
      displayItems.add(t);
    }
  }

  return displayItems;
}

void main() {
  final date = DateTime(2025, 12, 31); // Wednesday

  // Scenario:
  // 1. User had a class "Math" at 10:00 (Template Old).
  // 2. User cancelled/deleted it -> Created a persistent Cancelled Session (S_Old).
  // 3. User adds NEW class "Math" at 10:00 (Template New).

  // The Cancelled Session from the OLD template still exists in DB.
  final oldSession = ClassSession(
    id: 's_old',
    templateId: 't_old', // Linked to deleted template
    subjectName: 'Math',
    startTime: DateTime(2025, 12, 31, 10, 0),
    endTime: DateTime(2025, 12, 31, 11, 0),
    isCancelled: true,
  );

  final newTemplate = ScheduleTemplate(
    id: 't_new', // New ID
    subjectName: 'Math',
    dayOfWeek: 3,
    startTime: const TimeOfDay(hour: 10, minute: 0),
    endTime: const TimeOfDay(hour: 11, minute: 0),
  );

  final sessions = [oldSession];
  final schedule = [newTemplate];

  print("Running Ghost Session Test...");
  final result = getDisplayItemsForDay(date, sessions, schedule);

  print("Result count: ${result.length}");
  if (result.isEmpty) {
    print("FAIL: The new template was hidden by the old cancelled session!");
  } else {
    print("PASS: The new template is visible.");
  }
}

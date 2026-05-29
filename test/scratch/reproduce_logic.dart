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
  final String templateId; // FK to ScheduleTemplate
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

// Logic under test (Copy of the fix)
List<dynamic> getDisplayItemsForDay(DateTime date, List<ClassSession> sessions,
    List<ScheduleTemplate> schedule) {
  // 1. Get concrete sessions for this day
  final sessionsForDay = sessions
      .where((s) =>
          s.startTime.year == date.year &&
          s.startTime.month == date.month &&
          s.startTime.day == date.day)
      .toList();

  // 2. Get templates for this day
  final templatesForDay =
      schedule.where((t) => t.dayOfWeek == date.weekday).toList();

  // 3. Merge Logic
  final displayItems = <dynamic>[];
  final handledSessionIds = <String>{};

  for (final t in templatesForDay) {
    // Find ALL matching sessions for this template
    final matchingSessions = sessionsForDay.where((s) {
      // Robust Match: Check by Template ID
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
      // Check if ANY of the matching sessions are valid (not cancelled)
      final validSession = matchingSessions.firstWhere(
        (s) => !s.isCancelled,
        orElse: () => matchingSessions.first, // Fallback (likely cancelled)
      );

      if (!validSession.isCancelled) {
        // Found a valid session -> Show it
        displayItems.add(validSession);
      } else {
        // All matching sessions are cancelled -> Show NOTHING (Cancellation effective)
        print("DEBUG: Hidden cancelled class: ${t.subjectName}");
      }

      // Mark all matching sessions as handled so they don't appear as extras
      for (var s in matchingSessions) {
        handledSessionIds.add(s.id);
      }
    } else {
      // No session found -> Show the Template
      displayItems.add(t);
    }
  }

  // 4. Add remaining sessions (Extra classes not linked to any template)
  for (final s in sessionsForDay) {
    if (!handledSessionIds.contains(s.id)) {
      if (!s.isCancelled) {
        displayItems.add(s);
      }
    }
  }

  return displayItems;
}

void main() {
  final date = DateTime(2025, 12, 31); // Wednesday

  // Create Templates
  final schedule = [
    // T1: Normal, has Session S1
    ScheduleTemplate(
        id: 't1',
        subjectName: 'Normal Class',
        dayOfWeek: 3,
        startTime: const TimeOfDay(hour: 10, minute: 0),
        endTime: const TimeOfDay(hour: 11, minute: 0)),
    // T2: No session -> Should show Template
    ScheduleTemplate(
        id: 't2',
        subjectName: 'Template Only',
        dayOfWeek: 3,
        startTime: const TimeOfDay(hour: 11, minute: 0),
        endTime: const TimeOfDay(hour: 12, minute: 0)),
    // T3: Cancelled Session S3 -> Should show NOTHING
    ScheduleTemplate(
        id: 't3',
        subjectName: 'Cancelled Class',
        dayOfWeek: 3,
        startTime: const TimeOfDay(hour: 12, minute: 0),
        endTime: const TimeOfDay(hour: 13, minute: 0)),
    // T4: Duplicate (One Cancelled S4a, One Valid S4b) -> Should show Valid S4b
    ScheduleTemplate(
        id: 't4',
        subjectName: 'Fixed Ghost',
        dayOfWeek: 3,
        startTime: const TimeOfDay(hour: 13, minute: 0),
        endTime: const TimeOfDay(hour: 14, minute: 0)),
  ];

  final sessions = [
    // S1: Matches T1
    ClassSession(
        id: 's1',
        templateId: 't1',
        subjectName: 'Normal Class',
        startTime: DateTime(2025, 12, 31, 10, 0),
        endTime: DateTime(2025, 12, 31, 11, 0),
        isCancelled: false),
    // S3: Matches T3, Cancelled
    ClassSession(
        id: 's3',
        templateId: 't3',
        subjectName: 'Cancelled Class',
        startTime: DateTime(2025, 12, 31, 12, 0),
        endTime: DateTime(2025, 12, 31, 13, 0),
        isCancelled: true),
    // S4a: Matches T4, Cancelled (Ghost)
    ClassSession(
        id: 's4a',
        templateId: 't4',
        subjectName: 'Fixed Ghost',
        startTime: DateTime(2025, 12, 31, 13, 0),
        endTime: DateTime(2025, 12, 31, 14, 0),
        isCancelled: true),
    // S4b: Matches T4, Valid (The real one)
    ClassSession(
        id: 's4b',
        templateId: 't4',
        subjectName: 'Fixed Ghost',
        startTime: DateTime(2025, 12, 31, 13, 0),
        endTime: DateTime(2025, 12, 31, 14, 0),
        isCancelled: false),
  ];

  print("Running verification...");
  final result = getDisplayItemsForDay(date, sessions, schedule);

  print("Total Items displayed: ${result.length}");
  for (var item in result) {
    String name =
        item is ScheduleTemplate ? item.subjectName : item.subjectName;
    String type = item is ScheduleTemplate ? "TEMPLATE" : "SESSION";
    print("- [$type] $name");
  }

  // Assertions
  assert(result.length == 3,
      "Should show 3 items (T1->S1, T2, T4->S4b). T3 is hidden.");
  assert(
      result.any((i) => i is ClassSession && i.subjectName == 'Normal Class'),
      "S1 missing");
  assert(
      result.any(
          (i) => i is ScheduleTemplate && i.subjectName == 'Template Only'),
      "T2 missing");
  assert(!result.any((i) => i.subjectName == 'Cancelled Class'),
      "T3 should be hidden");
  assert(result.any((i) => i is ClassSession && i.subjectName == 'Fixed Ghost'),
      "S4b missing");

  print("Verification Successful!");
}

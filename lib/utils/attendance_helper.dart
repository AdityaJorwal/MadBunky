import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme.dart';

class AttendanceStatusInfo {
  final String statusText;
  final Color color;

  AttendanceStatusInfo(this.statusText, this.color);
}

AttendanceStatusInfo calculateStatus(Subject subject) {
  final current = subject.currentPercentage;
  final target = subject.targetPercentage.toDouble();
  final attended = subject.present + subject.proxy;
  final total = subject.total;

  if (total == 0) return AttendanceStatusInfo("No data", Colors.grey);

  if (current >= target) {
    // You are safe. How many can you bunk?
    // Formula: (Available - Bunks) / (Total + Bunks) >= Target/100
    // Try incrementing bunks until condition breaks.

    // Easier: Current Attended / (Total + NextBunks) >= Target/100
    // Attended / (Total + X) >= T
    // Attended >= T * (Total + X)
    // Attended/T >= Total + X
    // X <= (Attended/T) - Total

    final t = target / 100.0;
    int safeBunks = 0;
    if (t > 0) {
      safeBunks = ((attended / t) - total).floor();
    } else {
      safeBunks = 999;
    }

    if (safeBunks <= 0) {
      return AttendanceStatusInfo("You are Safe", AppTheme.pastelGreen);
    } else {
      return AttendanceStatusInfo("Bunk Next $safeBunks", AppTheme.pastelGreen);
    }
  } else {
    // Attendance Low. How many to attend?
    // (Attended + Need) / (Total + Need) >= Target/100
    // A + N >= T(Total + N)
    // A + N >= T*Total + T*N
    // N - T*N >= T*Total - A
    // N(1-T) >= T*Total - A
    // N >= (T*Total - A) / (1-T)

    final t = target / 100.0;
    if (t >= 1) {
      return AttendanceStatusInfo(
          "Impossible", AppTheme.pastelRed); // Can't reach 100% if missed one
    }

    final required = ((t * total - attended) / (1 - t)).ceil();

    if (required <= 0) {
      return AttendanceStatusInfo(
          "Attendance Low", AppTheme.pastelRed); // Should be covered above
    }

    return AttendanceStatusInfo("Attend Next $required", AppTheme.pastelRed);
  }
}

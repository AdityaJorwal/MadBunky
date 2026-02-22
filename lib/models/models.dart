import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../theme.dart';

const uuid = Uuid();

enum ThemeType { light, dark, system }

enum LogType { manual, schedule, proxy, auto }

class AttendanceLog {
  final String id;
  final DateTime timestamp;
  final AttendanceStatus status;
  final LogType type;
  final String? relatedSessionId;
  final DateTime? scheduledDate;

  AttendanceLog({
    String? id,
    required this.timestamp,
    required this.status,
    required this.type,
    this.relatedSessionId,
    this.scheduledDate,
  }) : id = id ?? uuid.v4();

  AttendanceLog copyWith({
    String? id,
    DateTime? timestamp,
    AttendanceStatus? status,
    LogType? type,
    String? relatedSessionId,
    DateTime? scheduledDate,
  }) {
    return AttendanceLog(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      type: type ?? this.type,
      relatedSessionId: relatedSessionId ?? this.relatedSessionId,
      scheduledDate: scheduledDate ?? this.scheduledDate,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'status': status.index,
        'type': type.index,
        'relatedSessionId': relatedSessionId,
        if (scheduledDate != null)
          'scheduledDate': scheduledDate!.toIso8601String(),
      };

  factory AttendanceLog.fromJson(Map<String, dynamic> json) => AttendanceLog(
        id: json['id'],
        timestamp: DateTime.parse(json['timestamp']),
        status: AttendanceStatus.values[json['status']],
        type: LogType.values[json['type']],
        relatedSessionId: json['relatedSessionId'],
        scheduledDate: json['scheduledDate'] != null
            ? DateTime.parse(json['scheduledDate'])
            : null,
      );
}

class Subject {
  final String id;
  final String name;
  final String? groupId; // Added for folder logic
  final int present;
  final int absent;
  final int ambiguous;
  final int proxy;
  final int targetPercentage;
  final int? colorValue;
  final List<AttendanceLog> logs;
  final String? teacherName;
  final String? topic;
  final bool showOutline; // Added showOutline

  Subject({
    String? id,
    required this.name,
    this.groupId,
    this.present = 0,
    this.absent = 0,
    this.ambiguous = 0,
    this.proxy = 0,
    this.targetPercentage = 75,
    this.colorValue,
    List<AttendanceLog>? logs,
    this.teacherName,
    this.topic,
    this.showOutline = false, // Default to false
  })  : id = id ?? uuid.v4(),
        logs = logs ?? [];

  int get total => present + absent + ambiguous + proxy;

  double get currentPercentage =>
      total == 0 ? 0 : ((present + proxy) / total) * 100;

  Subject copyWith({
    String? name,
    String? groupId,
    int? present,
    int? absent,
    int? ambiguous,
    int? proxy,
    int? targetPercentage,
    int? colorValue,
    bool clearColor = false,
    List<AttendanceLog>? logs,
    String? teacherName,
    String? topic,
    bool? showOutline,
  }) {
    return Subject(
      id: id,
      name: name ?? this.name,
      groupId: groupId ?? this.groupId,
      present: present ?? this.present,
      absent: absent ?? this.absent,
      ambiguous: ambiguous ?? this.ambiguous,
      proxy: proxy ?? this.proxy,
      targetPercentage: targetPercentage ?? this.targetPercentage,
      colorValue: clearColor ? null : (colorValue ?? this.colorValue),
      logs: logs ?? this.logs,
      teacherName: teacherName ?? this.teacherName,
      topic: topic ?? this.topic,
      showOutline: showOutline ?? this.showOutline,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'groupId': groupId,
        'present': present,
        'absent': absent,
        'ambiguous': ambiguous,
        'proxy': proxy,
        'targetPercentage': targetPercentage,
        'colorValue': colorValue,
        'logs': logs.map((x) => x.toJson()).toList(),
        'teacherName': teacherName,
        'topic': topic,
        'showOutline': showOutline,
      };

  factory Subject.fromJson(Map<String, dynamic> json) => Subject(
        id: json['id'],
        name: json['name'],
        groupId: json['groupId'],
        present: json['present'] as int,
        absent: json['absent'] as int,
        ambiguous: (json['ambiguous'] as int?) ?? 0,
        proxy: (json['proxy'] as int?) ?? 0,
        targetPercentage: json['targetPercentage'] as int? ?? 75,
        colorValue: json['colorValue'] as int?,
        logs: json['logs'] != null
            ? (json['logs'] as List)
                .map((x) => AttendanceLog.fromJson(x))
                .toList()
            : [],
        teacherName: json['teacherName'],
        topic: json['topic'],
        showOutline: json['showOutline'] ?? false,
      );
}

class ScheduleTemplate {
  final String id;
  final String subjectName;
  final String? subjectId; // Optional link to a subject
  final int dayOfWeek; // 1 = Monday, 7 = Sunday
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final int colorValue; // Store color as int
  final bool hasTime; // Added hasTime
  final String? teacherName; // Added teacherName
  final String? topic; // Added topic

  ScheduleTemplate({
    String? id,
    required this.subjectName,
    this.subjectId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.colorValue,
    this.hasTime = true,
    this.teacherName,
    this.topic,
  }) : id = id ?? uuid.v4();

  ScheduleTemplate copyWith({
    String? subjectName,
    String? subjectId,
    int? dayOfWeek,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    int? colorValue,
    bool? hasTime,
    String? teacherName,
    String? topic,
  }) {
    return ScheduleTemplate(
      id: id,
      subjectName: subjectName ?? this.subjectName,
      subjectId: subjectId ?? this.subjectId,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      colorValue: colorValue ?? this.colorValue,
      hasTime: hasTime ?? this.hasTime,
      teacherName: teacherName ?? this.teacherName,
      topic: topic ?? this.topic,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'subjectName': subjectName,
        'subjectId': subjectId,
        'dayOfWeek': dayOfWeek,
        'startHour': startTime.hour,
        'startMinute': startTime.minute,
        'endHour': endTime.hour,
        'endMinute': endTime.minute,
        'colorValue': colorValue,
        'hasTime': hasTime,
        'teacherName': teacherName,
        'topic': topic,
      };

  factory ScheduleTemplate.fromJson(Map<String, dynamic> json) =>
      ScheduleTemplate(
        id: json['id'],
        subjectName: json['subjectName'],
        subjectId: json['subjectId'],
        dayOfWeek: json['dayOfWeek'],
        startTime: TimeOfDay(
            hour: json['startHour'] ?? 0, minute: json['startMinute'] ?? 0),
        endTime: TimeOfDay(
            hour: json['endHour'] ?? 0, minute: json['endMinute'] ?? 0),
        colorValue: json['colorValue'] ?? 0xFF4287f5,
        hasTime: json['hasTime'] ?? true,
        teacherName: json['teacherName'],
        topic: json['topic'],
      );
}

enum AttendanceStatus { pending, present, absent, proxy, ambiguous }

class ClassSession {
  final String id;
  final String subjectName;
  final String? subjectId;
  final DateTime startTime;
  final DateTime endTime;
  final int colorValue;
  final bool isCancelled;
  final AttendanceStatus status;
  final bool isConcrete;
  final bool hasTime; // Added hasTime
  final String? templateId; // Added for robust notification matching
  final String? teacherName;
  final String? topic;
  final String? batch;
  final bool isEvent; // Added isEvent

  ClassSession({
    String? id,
    required this.subjectName,
    this.subjectId,
    required this.startTime,
    required this.endTime,
    required this.colorValue,
    this.isCancelled = false,
    this.status = AttendanceStatus.pending,
    this.isConcrete = true,
    this.hasTime = true,
    this.templateId,
    this.teacherName,
    this.topic,
    this.batch,
    this.isEvent = false,
  }) : id = id ?? uuid.v4();

  ClassSession copyWith({
    String? subjectName,
    String? subjectId,
    DateTime? startTime,
    DateTime? endTime,
    int? colorValue,
    bool? isCancelled,
    AttendanceStatus? status,
    bool? isConcrete,
    bool? hasTime,
    String? templateId,
    String? teacherName,
    String? topic,
    String? batch,
    bool? isEvent,
  }) {
    return ClassSession(
      id: id,
      subjectName: subjectName ?? this.subjectName,
      subjectId: subjectId ?? this.subjectId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      colorValue: colorValue ?? this.colorValue,
      isCancelled: isCancelled ?? this.isCancelled,
      status: status ?? this.status,
      isConcrete: isConcrete ?? this.isConcrete,
      hasTime: hasTime ?? this.hasTime,
      templateId: templateId ?? this.templateId,
      teacherName: teacherName ?? this.teacherName,
      topic: topic ?? this.topic,
      batch: batch ?? this.batch,
      isEvent: isEvent ?? this.isEvent,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'subjectName': subjectName,
        'subjectId': subjectId,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'colorValue': colorValue,
        'isCancelled': isCancelled,
        'status': status.index,
        'isConcrete': isConcrete,
        'hasTime': hasTime,
        'templateId': templateId,
        'teacherName': teacherName,
        'topic': topic,
        'batch': batch,
        'isEvent': isEvent,
      };

  factory ClassSession.fromJson(Map<String, dynamic> json) => ClassSession(
        id: json['id'],
        subjectName: json['subjectName'],
        subjectId: json['subjectId'],
        startTime: DateTime.parse(json['startTime']),
        endTime: DateTime.parse(json['endTime']),
        colorValue: json['colorValue'] ?? 0xFF4287f5,
        isCancelled: json['isCancelled'] ?? false,
        status: AttendanceStatus.values[json['status'] ?? 0],
        isConcrete: json['isConcrete'] ?? true,
        hasTime: json['hasTime'] ?? true,
        templateId: json['templateId'],
        teacherName: json['teacherName'],
        topic: json['topic'],
        batch: json['batch'],
        isEvent: json['isEvent'] ?? false,
      );
}

class Group {
  final String id;
  final String name;
  final List<String> subjectIds;
  final bool isExpanded;
  final int? colorValue;

  Group({
    String? id,
    required this.name,
    required this.subjectIds,
    this.isExpanded = true,
    this.colorValue,
  }) : id = id ?? uuid.v4();

  Group copyWith({
    String? name,
    List<String>? subjectIds,
    bool? isExpanded,
    int? colorValue,
    bool clearColor = false,
  }) {
    return Group(
      id: id,
      name: name ?? this.name,
      subjectIds: subjectIds ?? this.subjectIds,
      isExpanded: isExpanded ?? this.isExpanded,
      colorValue: clearColor ? null : (colorValue ?? this.colorValue),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'subjectIds': subjectIds,
        'isExpanded': isExpanded,
        'colorValue': colorValue,
      };

  factory Group.fromJson(Map<String, dynamic> json) => Group(
        id: json['id'],
        name: json['name'],
        subjectIds: List<String>.from(json['subjectIds']),
        isExpanded: json['isExpanded'] ?? true,
        colorValue: json['colorValue'] as int?,
      );
}

class LocationItem {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final double radius;
  final List<String> subjectIds; // Added for subject filtering

  LocationItem({
    String? id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.radius,
    this.subjectIds = const [], // Default to empty (All Subjects)
  }) : id = id ?? uuid.v4();

  LocationItem copyWith({
    String? name,
    double? lat,
    double? lng,
    double? radius,
    List<String>? subjectIds,
  }) {
    return LocationItem(
      id: id,
      name: name ?? this.name,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      radius: radius ?? this.radius,
      subjectIds: subjectIds ?? this.subjectIds,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'lat': lat,
        'lng': lng,
        'radius': radius,
        'subjectIds': subjectIds,
      };

  factory LocationItem.fromJson(Map<String, dynamic> json) => LocationItem(
        id: json['id'],
        name: json['name'] ?? 'Campus',
        lat: json['lat'] ?? 0.0,
        lng: json['lng'] ?? 0.0,
        radius: json['radius'] ?? 200.0,
        subjectIds: List<String>.from(json['subjectIds'] ?? []),
      );
}

class AppSettings {
  final ThemeType themeMode;
  final bool useMaterialYou;
  final bool showCalendar;
  final bool enableNotifications;
  final bool enableSmartBunking;
  final bool enableGeofence;
  final bool enableWifiTrigger;
  final bool enableHolidayAwareness;
  final bool enableLiveActivity;
  final bool enableClassAlerts;
  final bool enableSilentNotifications;
  final bool enableBackgroundStatusNotification;
  final bool enableGeofenceAlerts;
  final bool enableBatterySaver; // New: Battery Saver Mode
  final bool isNeon; // Added: Neon Mode Flag
  final bool enableAutoBackup; // Added: Auto Backup Flag

  // Refactored for Multiple Support
  final List<String> campusSsids;
  final List<LocationItem> campusLocations;

  // Deprecated Single Fields (Removed for cleanliness)
  // final String? campusSsid;
  // final double? campusLat;
  // final double? campusLng;
  // final double campusGeofenceRadius;

  final ThemePreset themePreset;
  final int? customThemeColor;
  final bool autoSyncGoogleCalendar; // Added

  AppSettings({
    this.themeMode = ThemeType.system,
    this.themePreset = ThemePreset.defaultGray,
    this.useMaterialYou = true,
    this.showCalendar = true,
    this.enableNotifications = true,
    this.enableSmartBunking = true,
    this.enableGeofence = false,
    this.enableWifiTrigger = false,
    this.enableHolidayAwareness = false,
    this.enableLiveActivity = false,
    this.enableClassAlerts = true,
    this.enableSilentNotifications = false,
    this.enableBackgroundStatusNotification = true,
    this.enableGeofenceAlerts = true,
    this.enableBatterySaver = false,
    this.isNeon = false,
    this.autoSyncGoogleCalendar = false,
    this.campusSsids = const [],
    this.campusLocations = const [],
    this.customThemeColor,
    this.enableAutoBackup = false, // Added
  });

  AppSettings copyWith({
    ThemeType? themeMode,
    ThemePreset? themePreset,
    bool? useMaterialYou,
    bool? showCalendar,
    bool? enableNotifications,
    bool? enableSmartBunking,
    bool? enableGeofence,
    bool? enableWifiTrigger,
    bool? enableHolidayAwareness,
    bool? enableLiveActivity,
    bool? enableClassAlerts,
    bool? enableSilentNotifications,
    List<String>? campusSsids,
    List<LocationItem>? campusLocations,
    int? customThemeColor,
    bool? enableBackgroundStatusNotification,
    bool? enableGeofenceAlerts,
    bool? enableBatterySaver,
    bool? autoSyncGoogleCalendar, // Added
    bool? isNeon, // Added
    bool? enableAutoBackup, // Added
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      themePreset: themePreset ?? this.themePreset,
      useMaterialYou: useMaterialYou ?? this.useMaterialYou,
      showCalendar: showCalendar ?? this.showCalendar,
      enableNotifications: enableNotifications ?? this.enableNotifications,
      enableSmartBunking: enableSmartBunking ?? this.enableSmartBunking,
      enableGeofence: enableGeofence ?? this.enableGeofence,
      enableWifiTrigger: enableWifiTrigger ?? this.enableWifiTrigger,
      enableHolidayAwareness:
          enableHolidayAwareness ?? this.enableHolidayAwareness,
      enableLiveActivity: enableLiveActivity ?? this.enableLiveActivity,
      enableClassAlerts: enableClassAlerts ?? this.enableClassAlerts,
      enableSilentNotifications:
          enableSilentNotifications ?? this.enableSilentNotifications,
      campusSsids: campusSsids ?? this.campusSsids,
      campusLocations: campusLocations ?? this.campusLocations,
      customThemeColor: customThemeColor ?? this.customThemeColor,
      enableAutoBackup: enableAutoBackup ?? this.enableAutoBackup,
      enableBatterySaver: enableBatterySaver ??
          this.enableBatterySaver, // Fixed: Added missing field
      isNeon: isNeon ?? this.isNeon, // Fixed: Added missing field
    );
  }

  Map<String, dynamic> toJson() => {
        'themeMode': themeMode.index,
        'themePreset': themePreset.index,
        'useMaterialYou': useMaterialYou,
        'showCalendar': showCalendar,
        'enableNotifications': enableNotifications,
        'enableSmartBunking': enableSmartBunking,
        'enableGeofence': enableGeofence,
        'enableWifiTrigger': enableWifiTrigger,
        'enableHolidayAwareness': enableHolidayAwareness,
        'enableLiveActivity': enableLiveActivity,
        'enableClassAlerts': enableClassAlerts,
        'enableSilentNotifications': enableSilentNotifications,
        'campusSsids': campusSsids,
        'campusLocations': campusLocations.map((e) => e.toJson()).toList(),
        'customThemeColor': customThemeColor,
        'enableBackgroundStatusNotification':
            enableBackgroundStatusNotification,
        'enableGeofenceAlerts': enableGeofenceAlerts,
        'enableBatterySaver': enableBatterySaver,
        'isNeon': isNeon, // Added
        'enableAutoBackup': enableAutoBackup, // Added
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        themeMode: ThemeType.values[json['themeMode'] ?? 0],
        themePreset: ThemePreset.values[json['themePreset'] ?? 0],
        useMaterialYou: json['useMaterialYou'] ?? true,
        showCalendar: json['showCalendar'] ?? true,
        enableNotifications: json['enableNotifications'] ?? true,
        enableSmartBunking: json['enableSmartBunking'] ?? true,
        enableGeofence: json['enableGeofence'] ?? false,
        enableWifiTrigger: json['enableWifiTrigger'] ?? false,
        enableHolidayAwareness: json['enableHolidayAwareness'] ?? false,
        enableLiveActivity: json['enableLiveActivity'] ?? false,
        enableClassAlerts: json['enableClassAlerts'] ?? true,
        enableSilentNotifications: json['enableSilentNotifications'] ?? false,
        campusSsids: List<String>.from(json['campusSsids'] ?? []),
        campusLocations: (json['campusLocations'] as List<dynamic>?)
                ?.map((e) => LocationItem.fromJson(e))
                .toList() ??
            [],
        customThemeColor: json['customThemeColor'] as int?,
        enableAutoBackup: json['enableAutoBackup'] ?? false,
        enableBatterySaver:
            json['enableBatterySaver'] ?? false, // Fixed: Added missing field
        isNeon: json['isNeon'] ?? false, // Fixed: Added missing field
      );
}

// Helper to calculate status
class AttendanceHealth {
  final String statusText;
  final Color color;
  final double percentage;

  AttendanceHealth(this.statusText, this.color, this.percentage);
}

AttendanceHealth calculateStatus(Subject subject) {
  final total = subject.total;
  final effectivePresent = subject.present + subject.proxy;
  final target = subject.targetPercentage;
  final double currentPct = total == 0 ? 0 : (effectivePresent / total) * 100;

  if (total == 0 || target == 0) {
    return AttendanceHealth(
      "No classes recorded yet",
      const Color(0xFFE8A317), // Same orange as "on track"
      0,
    );
  }

  // O(1) mathematical approximation for "Can Miss"
  // Formula: (effectivePresent / (total + x)) * 100 >= target
  // x <= (effectivePresent * 100 / target) - total
  // We want the maximum whole number of classes we can miss while staying >= target.
  int canMiss = ((effectivePresent * 100) / target).floor() - total;

  if (canMiss > 0) {
    return AttendanceHealth(
      "Can miss upcoming $canMiss classes",
      Colors.green,
      currentPct,
    );
  }

  // O(1) mathematical approximation for "Must Attend"
  // Formula: ((effectivePresent + y) / (total + y)) * 100 >= target
  // y >= (target * total - 100 * effectivePresent) / (100 - target)
  int mustAttend = 0;
  if (currentPct < target) {
    if (target == 100) {
      // Impossible to reach 100% if already below 100%
      return AttendanceHealth(
        "Cannot reach 100%",
        Colors.red,
        currentPct,
      );
    }
    mustAttend =
        ((target * total - 100 * effectivePresent) / (100 - target)).ceil();
    if (mustAttend > 0) {
      return AttendanceHealth(
        "Must attend upcoming $mustAttend classes",
        Colors.red,
        currentPct,
      );
    }
  }

  return AttendanceHealth(
    "On track, cannot miss next class",
    const Color(0xFFE8A317),
    currentPct,
  );
}

class UserProfile {
  final String name;
  final String institute;

  const UserProfile({
    required this.name,
    required this.institute,
  });

  UserProfile copyWith({
    String? name,
    String? institute,
  }) {
    return UserProfile(
      name: name ?? this.name,
      institute: institute ?? this.institute,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'institute': institute,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        name: json['name'] ?? '',
        institute: json['institute'] ?? '',
      );
}

enum HolidayType {
  user,
  national,
  calendar,
}

class HolidayItem {
  final DateTime date;
  final String name;
  final HolidayType type;

  const HolidayItem({
    required this.date,
    required this.name,
    required this.type,
  });

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'name': name,
        'type': type.index,
      };

  factory HolidayItem.fromJson(Map<String, dynamic> json) {
    return HolidayItem(
      date: DateTime.parse(json['date']),
      name: json['name'] ?? 'Holiday',
      type: HolidayType.values[json['type'] ?? 0],
    );
  }

  // Helper for sorting
  int compareTo(HolidayItem other) {
    return date.compareTo(other.date);
  }

  @override
  bool operator ==(Object other) {
    if (other is! HolidayItem) return false;
    return date.year == other.date.year &&
        date.month == other.date.month &&
        date.day == other.date.day &&
        name == other.name &&
        type == other.type;
  }

  @override
  int get hashCode => Object.hash(date, name, type);
}

class ScanStructure {
  final List<double> verticalLines;
  final List<double> horizontalLines;
  final double slope;

  ScanStructure({
    this.verticalLines = const [],
    this.horizontalLines = const [],
    this.slope = 0.0,
  });

  Map<String, dynamic> toJson() => {
        'verticalLines': verticalLines,
        'horizontalLines': horizontalLines,
        'slope': slope,
      };

  factory ScanStructure.fromJson(Map<String, dynamic> json) => ScanStructure(
        verticalLines: List<double>.from(json['verticalLines'] ?? []),
        horizontalLines: List<double>.from(json['horizontalLines'] ?? []),
        slope: (json['slope'] as num?)?.toDouble() ?? 0.0,
      );
}

class ScanOptions {
  final bool useGridAnalysis;
  final bool useLineEnhancement;

  const ScanOptions({
    this.useGridAnalysis = true,
    this.useLineEnhancement = true,
  });

  ScanOptions copyWith({
    bool? useGridAnalysis,
    bool? useLineEnhancement,
  }) {
    return ScanOptions(
      useGridAnalysis: useGridAnalysis ?? this.useGridAnalysis,
      useLineEnhancement: useLineEnhancement ?? this.useLineEnhancement,
    );
  }
}

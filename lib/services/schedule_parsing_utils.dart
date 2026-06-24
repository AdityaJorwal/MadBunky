import 'package:flutter/material.dart';
import 'package:mad_bunky/models/models.dart';

class ScheduleParsingUtils {
  // --- Date Extraction ---

  static DateTime? extractDate(String text) {
    if (text.isEmpty) return null;
    final lower = text.toLowerCase();

    // 1. Common formats: dd/MM/yyyy, dd-MM-yyyy, yyyy-MM-dd
    // Regex for d/M/y or d-M-y
    final dateRegex = RegExp(r'\b(\d{1,2})[./-](\d{1,2})[./-](\d{2,4})\b');
    final match = dateRegex.firstMatch(text);
    if (match != null) {
      try {
        int d = int.parse(match.group(1)!);
        int m = int.parse(match.group(2)!);
        int y = int.parse(match.group(3)!);
        if (y < 100) y += 2000; // Assume 21st century

        return DateTime(y, m, d);
      } catch (_) {}
    }

    // 2. Textual formats: 12th Oct 2024, Oct 12 2024
    // Simple heuristic for month names
    final months = [
      "jan",
      "feb",
      "mar",
      "apr",
      "may",
      "jun",
      "jul",
      "aug",
      "sep",
      "oct",
      "nov",
      "dec"
    ];

    // Look for day (1-31) and Year (2020-2030)
    // This is a basic parser. For advanced, might need more regex.
    for (int i = 0; i < months.length; i++) {
      if (lower.contains(months[i])) {
        // We found a month. Look for nearby digits.
        // Regex to find "12th", "12", "2024"
        final dayRegex = RegExp(r'\b(\d{1,2})(?:st|nd|rd|th)?\b');
        final yearRegex = RegExp(r'\b(20\d{2})\b');

        final dayMatch = dayRegex.firstMatch(text);
        final yearMatch = yearRegex.firstMatch(text);

        int year = DateTime.now().year;
        if (yearMatch != null) {
          year = int.parse(yearMatch.group(1)!);
        }

        if (dayMatch != null) {
          int day = int.parse(dayMatch.group(1)!);
          return DateTime(year, i + 1, day);
        }
      }
    }

    return null;
  }

  // --- Core Smart Extraction Logic ---

  /// Extracts Subject, Teacher, and Topic from a list of strings (lines or split parts).
  ///
  /// [textLines]: The raw lines of text from a schedule block.
  /// [existingSubjects]: User's known subjects for prioritization.
  /// [knownTeachers]: Extracted teacher names for identification.
  /// [forceNoSplit]: If true, prevents splitting logic (passed contextually if needed).
  static SessionDetails extractSessionDetails(
    List<String> textLines,
    List<Subject> existingSubjects, {
    List<String>? knownTeachers,
  }) {
    if (textLines.isEmpty) return SessionDetails(subjectName: "Class");

    String fullText = textLines.join("\n");
    String subjectName = "";
    String? topic;
    String? teacher;

    // 1. Try to detect subject from Full Text (Existing Subjects Priority)
    final sortedSubjects = List<Subject>.from(existingSubjects)
      ..sort((a, b) => b.name.length.compareTo(a.name.length));

    for (var sub in sortedSubjects) {
      if (fullText.toLowerCase().contains(sub.name.toLowerCase())) {
        subjectName = sub.name;
        break;
      }
    }

    // 2. Fallback to Hardcoded/Heuristic Logic
    if (subjectName.isEmpty) {
      String? detected = _detectSubjectName(fullText);
      if (detected != null) {
        subjectName = detected;
      }
    }

    // 3. Fallback: Line-by-Line Analysis
    if (subjectName.isEmpty) {
      for (var line in textLines) {
        if (!isTeacherLine(line, knownTeachers)) {
          // Check if line is a subject
          String cleaned = _cleanBatchPrefix(line);
          String? detected = _detectSubjectName(cleaned);
          if (detected != null) {
            subjectName = detected;
            break;
          }
        }
      }
    }

    // 4. Last Resort: First non-teacher line
    if (subjectName.isEmpty) {
      for (var line in textLines) {
        if (!isTeacherLine(line, knownTeachers) && !_isMetaLine(line)) {
          String cleaned = _cleanBatchPrefix(line);
          // Heuristic: If it's short and looks like a subject?
          subjectName = cleaned.split(":").first.trim();
          break;
        }
      }
      if (subjectName.isEmpty) subjectName = "Class";
    }

    subjectName = _cleanText(subjectName);

    // --- Detail Extraction (Teacher / Topic) ---
    List<String> detailLines = [];

    // Filter out the "Subject" part from the lines to find residues
    for (var line in textLines) {
      String clean = _cleanBatchPrefix(line);
      // Remove Subject Name from line if present
      String lowerLine = clean.toLowerCase();
      String lowerSub = subjectName.toLowerCase();

      // If this line *IS* the subject, we might want to extract "Topic" from it?
      // E.g. "Medicine: CVS"
      if (lowerLine.contains(lowerSub)) {
        // Strip subject
        String residue =
            clean.replaceAll(RegExp(subjectName, caseSensitive: false), '');
        residue = residue.replaceAll(RegExp(r'^[:\-]'), '').trim();
        if (residue.isNotEmpty && residue.length > 2) {
          detailLines.add(residue);
        }
      } else {
        // Line doesn't contain subject name... is it a teacher or topic?
        detailLines.add(clean);
      }
    }

    List<String> potentialTeachers = [];
    List<String> potentialTopics = [];

    for (var l in detailLines) {
      if (isTeacherLine(l, knownTeachers)) {
        potentialTeachers.add(l);
      } else if (!_isMetaLine(l) && l.length > 2) {
        // Assume topic if not teacher and significant length
        potentialTopics.add(l);
      }
    }

    // teacher = potentialTeachers.join(", ");
    // topic = potentialTopics.join(" ");

    // Explicitly disabled by user request
    teacher = null;
    topic = null;

    // if (teacher.isEmpty) teacher = null;
    // if (topic.isEmpty) topic = null;

    return SessionDetails(
      subjectName: subjectName,
      topic: topic,
      teacher: teacher,
    );
  }

  // --- Recognition Helpers ---

  static bool isTeacherLine(String line, [List<String>? knownTeachers]) {
    final markers = ['Dr ', 'Dr.', 'Prof', 'Mrs', 'Mr ', 'Ms '];
    if (markers.any((m) => line.contains(m))) return true;

    if (knownTeachers != null) {
      for (var t in knownTeachers) {
        final escaped = RegExp.escape(t);
        // Use word boundaries for safety
        if (line
            .contains(RegExp(r'\b' + escaped + r'\b', caseSensitive: false))) {
          return true;
        }
      }
    }
    return false;
  }

  static String? _detectSubjectName(String text) {
    final lower = text.toLowerCase();

    // Explicit Rules for Tutorial/Practical Mapping
    if (lower.contains("anatomy") &&
        (lower.contains("practical") ||
            lower.contains("tutorial") ||
            lower.contains("dissection"))) {
      return "Anatomy Practical";
    }

    // Tutorials treated as subjects (Split allowed)
    if (lower.contains("physiology") && lower.contains("tutorial")) {
      return "Physiology";
    }
    if (lower.contains("biochemistry") && lower.contains("tutorial")) {
      return "Biochemistry";
    }
    if (lower.contains("sdl")) return "SDL";

    // Clinics Detection (Explicit Mapping)
    if (lower.contains("clinics")) {
      if (lower.contains("medicine") && !lower.contains("community")) {
        return "Medicine Clinics";
      }
      if (lower.contains("community medicine") || lower.contains("psm")) {
        return "Community Medicine Clinics";
      }
      if (lower.contains("surgery")) {
        return "Surgery Clinics";
      }
      if (lower.contains("pediatrics")) {
        return "Pediatrics Clinics";
      }
      if (lower.contains("obgy") || lower.contains("obstetrics")) {
        return "OBGY Clinics";
      }
      if (lower.contains("ophthalmology")) {
        return "Ophthalmology Clinics";
      }
      if (lower.contains("ent")) {
        return "ENT Clinics";
      }
      if (lower.contains("orthopedics")) {
        return "Orthopedics Clinics";
      }
      if (lower.contains("psychiatry")) {
        return "Psychiatry Clinics";
      }
      if (lower.contains("skin") || lower.contains("dermatology")) {
        return "Dermatology Clinics";
      }

      return "Clinics";
    }

    // Standard Mapping
    if (lower.contains("anatomy")) return "Anatomy";
    if (lower.contains("physiology")) {
      if (lower.contains("practical")) return "Physiology Practical";
      return "Physiology";
    }
    if (lower.contains("biochemistry")) {
      if (lower.contains("practical")) return "Biochemistry Practical";
      return "Biochemistry";
    }

    if (lower.contains("community medicine")) return "Community Medicine";
    if (lower.contains("pharmacology")) {
      if (lower.contains("practical")) return "Pharmacology Practical";
      return "Pharmacology";
    }
    if (lower.contains("pathology")) {
      if (lower.contains("practical")) return "Pathology Practical";
      return "Pathology";
    }
    if (lower.contains("microbiology")) {
      if (lower.contains("practical")) return "Microbiology Practical";
      return "Microbiology";
    }
    if (lower.contains("forensic medicine") || lower.contains("fmt")) {
      return "FMT";
    }

    if (lower.contains("medicine") && !lower.contains("community")) {
      return "Medicine";
    }
    if (lower.contains("surgery")) {
      return "Surgery";
    }
    if (lower.contains("pediatrics")) {
      return "Pediatrics";
    }
    if (lower.contains("obgy") ||
        lower.contains("obstetrics") ||
        lower.contains("obs & gyn")) {
      return "OBGY";
    }

    if (lower.contains("ent")) {
      return "ENT";
    }
    if (lower.contains("ophthalmology")) {
      return "Ophthalmology";
    }
    if (lower.contains("orthopedics")) {
      return "Orthopedics";
    }
    if (lower.contains("anaesthesia")) {
      return "Anaesthesia";
    }
    if (lower.contains("psychiatry")) {
      return "Psychiatry";
    }
    if (lower.contains("radiology") || lower.contains("radiodiagnosis")) {
      return "Radiology";
    }
    if (lower.contains("psm")) return "Community Medicine";

    // Generic Tutorial catch-all
    if (lower.contains("tutorial")) {
      return "Tutorial";
    }

    return null;
  }

  static bool isPracticalOrClinic(String text) {
    final lower = text.toLowerCase();

    if (lower.contains("anatomy") &&
        (lower.contains("practical") || lower.contains("tutorial"))) {
      return true;
    }
    if (lower.contains("physiology") && lower.contains("tutorial")) {
      return false; // Force split
    }
    if (lower.contains("biochemistry") && lower.contains("tutorial")) {
      return false; // Force split
    }

    return lower.contains("practical") ||
        lower.contains("clinic") ||
        lower.contains("laboratory") ||
        lower.contains("dissection") ||
        lower.contains("posting");
  }

  // --- Utility Helpers ---

  static bool _isMetaLine(String line) {
    return line.toLowerCase().contains("batch") || line.trim().length < 2;
  }

  static String _cleanText(String t) =>
      t.replaceAll(RegExp(r'[^\w\s]'), '').trim();

  static String _cleanBatchPrefix(String line) {
    var s = line;
    // Standard "Batch A"
    s = s.replaceAll(
        RegExp(r'^(?:Practical\s+)?Batch\s+[A-Z0-9]+(?:-[A-Z0-9]+)?\s*[-:]?\s*',
            caseSensitive: false),
        '');
    // Inverted "A Batch" or "(A) Batch"
    s = s.replaceAll(
        RegExp(r'^\(?\s*[A-Z0-9]+\s*\)?\s+Batch\s*[-:]?\s*',
            caseSensitive: false),
        '');
    return s.trim();
  }

  // Color Helper: Try to match existing subject color or generate
  static int getColor(String name, List<Subject> existingSubjects) {
    final existing = existingSubjects.firstWhere(
        (s) => s.name.toLowerCase() == name.toLowerCase(),
        orElse: () => Subject(name: '', colorValue: 0) // Dummy
        );
    if (existing.colorValue != 0 && existing.colorValue != null) {
      return existing.colorValue!;
    }
    return Colors.primaries[name.hashCode.abs() % Colors.primaries.length]
        .toARGB32();
  }
  // --- Historical Learning ---

  static SessionDetails? predictFromHistory(
    List<ClassSession> history,
    int dayOfWeek,
    TimeOfDay start,
    TimeOfDay end,
  ) {
    if (history.isEmpty) return null;

    // Filter relevant sessions
    // 1. Same Day of Week
    // 2. Overlapping Time (mostly)
    // 3. Recent? (Maybe last 90 days?)
    final cutoff = DateTime.now().subtract(const Duration(days: 90));

    final candidates = history.where((s) {
      if (s.startTime.isBefore(cutoff)) return false;
      if (s.startTime.weekday != dayOfWeek) return false;

      // Compare Time
      // Convert session time to TimeOfDay for comparison
      final sStart = TimeOfDay.fromDateTime(s.startTime);

      // Check for substantial overlap (e.g. share start hour)
      // Simplest: Start times match or are very close (within 30 mins)
      int sMin = sStart.hour * 60 + sStart.minute;
      int tMin = start.hour * 60 + start.minute;
      return (sMin - tMin).abs() < 30; // 30 min tolerance
    }).toList();

    if (candidates.isEmpty) return null;

    // Tally Subjects
    final scores = <String, int>{};
    final teacherMap = <String, String>{}; // Subject -> Teacher(last seen)
    final topicMap = <String, String>{}; // Subject -> Topic(last seen)

    for (var s in candidates) {
      scores[s.subjectName] = (scores[s.subjectName] ?? 0) + 1;
      if (s.teacherName != null) teacherMap[s.subjectName] = s.teacherName!;
      if (s.topic != null) topicMap[s.subjectName] = s.topic!;
    }

    // Find Winner
    var bestSubject = "";
    var maxScore = 0;
    scores.forEach((sub, score) {
      if (score > maxScore) {
        maxScore = score;
        bestSubject = sub;
      }
    });

    if (bestSubject.isNotEmpty) {
      // Only confident if it appeared at least twice? Or just once if nothing else?
      // Let's say we trust it even if 1, provided the user scans similar schedules.
      return SessionDetails(
        subjectName: bestSubject,
        teacher: teacherMap[bestSubject],
        topic:
            topicMap[bestSubject], // Maybe don't predict topic? Topics change.
        // Actually user said "learn to handle that schedule".
        // Usually Teacher is constant, Topic changes.
        // Let's omit Topic prediction unless user explicitly asked for strict cloning.
        // Safest: Omit Topic.
      );
    }

    return null;
  }
}

class SessionDetails {
  final String subjectName;
  final String? topic;
  final String? teacher;

  SessionDetails({required this.subjectName, this.topic, this.teacher});
}

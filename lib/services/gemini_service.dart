import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';

class GeminiService {
  static const _secureStorage = FlutterSecureStorage();
  static const _apiKeyStorageKey = 'gemini_api_key';

  // Private constructor
  GeminiService._privateConstructor();

  // Singleton instance
  static final GeminiService instance = GeminiService._privateConstructor();

  /// Retrieve the API Key from secure storage
  Future<String?> getApiKey() async {
    try {
      return await _secureStorage.read(key: _apiKeyStorageKey);
    } catch (e) {
      debugPrint("Error reading API key from secure storage: $e");
      return null;
    }
  }

  /// Save the API Key to secure storage
  Future<void> saveApiKey(String apiKey) async {
    try {
      await _secureStorage.write(key: _apiKeyStorageKey, value: apiKey.trim());
    } catch (e) {
      debugPrint("Error writing API key to secure storage: $e");
      rethrow;
    }
  }

  /// Delete the API Key from secure storage
  Future<void> deleteApiKey() async {
    try {
      await _secureStorage.delete(key: _apiKeyStorageKey);
    } catch (e) {
      debugPrint("Error deleting API key from secure storage: $e");
      rethrow;
    }
  }

  /// Check if the API Key is configured
  Future<bool> hasApiKey() async {
    final key = await getApiKey();
    return key != null && key.isNotEmpty;
  }

  /// Test connectivity to Gemini with the provided API key and model.
  /// Returns null if successful, or the error message if it fails.
  Future<String?> testApiKey(String apiKey, String modelName) async {
    try {
      final model = GenerativeModel(
        model: modelName,
        apiKey: apiKey,
      );
      final response = await model.generateContent([
        Content.text("Hello. Please respond with exactly the word 'SUCCESS' if you can read this message.")
      ]);
      final text = response.text?.trim().toUpperCase();
      if (text != null && text.contains("SUCCESS")) {
        return null;
      }
      return "Unexpected response from Gemini: $text";
    } catch (e) {
      debugPrint("Gemini connection test failed: $e");
      // Format the error message to be readable for the user
      String errMsg = e.toString();
      if (errMsg.contains("API_KEY_INVALID")) {
        return "Invalid API Key. Please verify your key from Google AI Studio.";
      }
      if (errMsg.contains("MODEL_NOT_FOUND") || errMsg.contains("model not found") || errMsg.contains("404")) {
        return "Model '$modelName' not found or not supported with this API key.";
      }
      return errMsg;
    }
  }

  /// Processes schedule file (image or PDF) and extracts ClassSession list using Gemini
  Future<List<ClassSession>> extractSchedule({
    required File file,
    required String mimeType,
    required String apiKey,
    required String modelName,
    List<Subject> existingSubjects = const [],
    String customPrompt = '',
  }) async {
    final model = GenerativeModel(
      model: modelName,
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
      ),
    );

    final fileBytes = await file.readAsBytes();

    final customPromptText = customPrompt.trim().isNotEmpty
        ? "\n\nAdditional user guidelines for parsing this schedule:\n$customPrompt\n"
        : "";

    final prompt = """
Analyze the attached timetable document/image and extract all scheduled classes, sessions, lectures, or events.
$customPromptText
Return a JSON array of objects, where each object represents a class session and has the EXACT following structure:
{
  "subjectName": "Name of the class/subject/event (e.g. Mathematics, Physics Lab)",
  "startTime": "HH:MM (24-hour format, e.g. 09:30 or 14:00)",
  "endTime": "HH:MM (24-hour format, e.g. 10:30 or 15:30)",
  "dayOfWeek": 1-7 (integer, 1 for Monday, 7 for Sunday. Set to null if the timetable is associated with specific absolute dates rather than recurring weekdays),
  "date": "YYYY-MM-DD (e.g. 2026-06-01. Only include if specific dates are associated with this class/event, otherwise set to null)",
  "teacherName": "Name of the teacher/lecturer (optional, set to null if not found)",
  "topic": "Topic/type of class e.g. lecture/lab/seminar (optional, set to null if not found)",
  "batch": "Batch/group name if specified, e.g. CSE-A, Batch-1 (optional, set to null if not found)"
}

Do not include any markdown block code wraps or other explanations. Return only the raw JSON array.
""";

    final content = [
      Content.multi([
        DataPart(mimeType, fileBytes),
        TextPart(prompt),
      ])
    ];

    final response = await model.generateContent(content);
    final responseText = response.text;
    if (responseText == null || responseText.trim().isEmpty) {
      throw Exception("Empty response received from Gemini AI.");
    }

    try {
      final decoded = jsonDecode(responseText);
      if (decoded is! List) {
        throw const FormatException("Expected a JSON array of events.");
      }

      final List<ClassSession> sessions = [];
      const uuid = Uuid();

      for (var item in decoded) {
        if (item is! Map<String, dynamic>) continue;

        final String subjectName = item['subjectName']?.toString() ?? 'Unknown Class';
        final String startTimeStr = item['startTime']?.toString() ?? '09:00';
        final String endTimeStr = item['endTime']?.toString() ?? '10:00';
        final int? dayOfWeekVal = item['dayOfWeek'] != null ? int.tryParse(item['dayOfWeek'].toString()) : null;
        final String? dateStr = item['date']?.toString();
        final String? teacherName = item['teacherName']?.toString();
        final String? topic = item['topic']?.toString();
        final String? batch = item['batch']?.toString();

        // Check if subject exists to preserve/reuse its color or ID
        final matchedSubject = existingSubjects.firstWhere(
          (s) => s.name.toLowerCase() == subjectName.toLowerCase(),
          orElse: () => Subject(name: subjectName),
        );

        final int colorValue = matchedSubject.colorValue ?? _getDeterministicColor(subjectName);

        // Resolve absolute start and end times
        final resolvedTimes = _resolveTimes(
          dateStr: dateStr,
          dayOfWeek: dayOfWeekVal,
          startTimeStr: startTimeStr,
          endTimeStr: endTimeStr,
        );

        sessions.add(
          ClassSession(
            id: uuid.v4(),
            subjectName: subjectName,
            subjectId: matchedSubject.id,
            startTime: resolvedTimes.start,
            endTime: resolvedTimes.end,
            colorValue: colorValue,
            teacherName: teacherName,
            topic: topic,
            batch: batch,
            isConcrete: true,
            hasTime: true,
          ),
        );
      }

      return sessions;
    } catch (e) {
      debugPrint("Error parsing Gemini JSON response: $e\nResponse: $responseText");
      rethrow;
    }
  }

  /// Resolve absolute DateTime values for start and end times
  _DateTimeRange _resolveTimes({
    required String? dateStr,
    required int? dayOfWeek,
    required String startTimeStr,
    required String endTimeStr,
  }) {
    final startParts = startTimeStr.split(':');
    final startHour = int.tryParse(startParts[0]) ?? 9;
    final startMinute = int.tryParse(startParts.length > 1 ? startParts[1] : '0') ?? 0;

    final endParts = endTimeStr.split(':');
    final endHour = int.tryParse(endParts[0]) ?? 10;
    final endMinute = int.tryParse(endParts.length > 1 ? endParts[1] : '0') ?? 0;

    if (dateStr != null && dateStr.isNotEmpty) {
      try {
        final parsedDate = DateTime.parse(dateStr);
        return _DateTimeRange(
          start: DateTime(parsedDate.year, parsedDate.month, parsedDate.day, startHour, startMinute),
          end: DateTime(parsedDate.year, parsedDate.month, parsedDate.day, endHour, endMinute),
        );
      } catch (_) {}
    }

    // Default: use dummy week starting Monday, Jan 5, 1970
    final int resolvedDay = (dayOfWeek != null && dayOfWeek >= 1 && dayOfWeek <= 7) ? dayOfWeek : 1;
    final baseDate = DateTime(1970, 1, 5).add(Duration(days: resolvedDay - 1));

    return _DateTimeRange(
      start: DateTime(baseDate.year, baseDate.month, baseDate.day, startHour, startMinute),
      end: DateTime(baseDate.year, baseDate.month, baseDate.day, endHour, endMinute),
    );
  }

  /// Generate a deterministic color for a given subject name
  int _getDeterministicColor(String name) {
    final hash = name.hashCode;
    final colors = [
      0xFFE57373, // Light Red
      0xFFF06292, // Light Pink
      0xFFBA68C8, // Light Purple
      0xFF9575CD, // Light Deep Purple
      0xFF7986CB, // Light Indigo
      0xFF64B5F6, // Light Blue
      0xFF4FC3F7, // Light Cyan
      0xFF4DB6AC, // Light Teal
      0xFF81C784, // Light Green
      0xFFAED581, // Light Lime Green
      0xFFFFD54F, // Light Amber
      0xFFFFB74D, // Light Orange
      0xFFFF8A65, // Light Deep Orange
    ];
    return colors[hash.abs() % colors.length];
  }
}

class _DateTimeRange {
  final DateTime start;
  final DateTime end;
  _DateTimeRange({required this.start, required this.end});
}

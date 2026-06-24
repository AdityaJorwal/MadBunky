import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/models.dart';

class GoogleCalendarService {
  final GoogleSignIn _googleSignIn;

  GoogleCalendarService(this._googleSignIn);

  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  Stream<GoogleSignInAccount?> get onCurrentUserChanged =>
      _googleSignIn.onCurrentUserChanged;

  bool get isSignedIn => _googleSignIn.currentUser != null; // Added helper

  /// Initializes the service.
  /// For Google Sign In, we often need to attempt a silent sign-in to restore state.
  Future<void> init() async {
    try {
      // Attempt to sign in silently to restore previous session if any.
      // This will emit an event to onCurrentUserChanged if successful.
      await _googleSignIn.signInSilently();
    } catch (e) {
      debugPrint("GoogleCalendarService: Silent sign-in failed/ignored: $e");
    }
  }

  Future<GoogleSignInAccount?> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      return account;
    } catch (error) {
      debugPrint('Google Sign In Error: $error');
      return null;
    }
  }

  Future<GoogleSignInAccount?> silentSignIn() async {
    try {
      return await _googleSignIn.signInSilently();
    } catch (error) {
      debugPrint('Silent Sign In Error: $error');
      return null;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.disconnect();
  }

  Future<List<ClassSession>> fetchEventsForWeek(DateTime startOfWeek) async {
    final account = _googleSignIn.currentUser;
    if (account == null) {
      // Attempt silent sign-in one last time?
      final reAuth = await _googleSignIn.signInSilently();
      if (reAuth == null) throw Exception('User not signed in');
    }

    try {
      final httpClient = await _googleSignIn.authenticatedClient();
      if (httpClient == null) {
        throw Exception('Could not authenticate client');
      }

      final calendarApi = calendar.CalendarApi(httpClient);

      // Define time range (Monday to Sunday)
      final endOfWeek = startOfWeek.add(const Duration(days: 7));

      final events = await calendarApi.events.list(
        'primary',
        timeMin: startOfWeek.toUtc(),
        timeMax: endOfWeek.toUtc(),
        singleEvents: true,
        orderBy: 'startTime',
      );

      if (events.items == null) return [];

      return events.items!
          .where((e) => e.start?.dateTime != null && e.end?.dateTime != null)
          .map((e) => _mapEventToClassSession(e))
          .whereType<
              ClassSession>() // Filter out potential nulls if map returns null
          .toList();
    } catch (e) {
      debugPrint('Error fetching events: $e');
      rethrow;
    }
  }

  static Map<String, String?> parseDescription(String? description) {
    if (description == null || description.isEmpty) {
      return {'topic': null, 'teacher': null};
    }

    // Regex to match "topic - [topic] , teacher - [teacher]"
    // We use case-insensitive matching for the keys "topic" and "teacher"
    // We handle optional spaces around separators.
    final regex = RegExp(
      r'topic\s*-\s*(?<topic>.*?)\s*,\s*teacher\s*-\s*(?<teacher>.*)',
      caseSensitive: false,
    );

    final match = regex.firstMatch(description);
    if (match != null) {
      return {
        'topic': match.namedGroup('topic')?.trim(),
        'teacher': match.namedGroup('teacher')?.trim(),
      };
    }

    return {'topic': null, 'teacher': null};
  }

  ClassSession? _mapEventToClassSession(calendar.Event event) {
    try {
      final startTime = event.start!.dateTime!.toLocal();
      final endTime = event.end!.dateTime!.toLocal();

      final subjectName = event.summary ?? "Untitled Class";
      String? teacherName;
      String? topic;

      // Priority 1: Check for structured format in notes
      if (event.description != null && event.description!.isNotEmpty) {
        final parsed = parseDescription(event.description);
        if (parsed['topic'] != null || parsed['teacher'] != null) {
          topic = parsed['topic'];
          teacherName = parsed['teacher'];
        } else {
          // Priority 2: Fallback to Heuristic
          // Description (Line 1) -> Teacher (if starts with "Teacher:")
          // Description (Line 2) -> Topic
          final lines = event.description!.split('\n');
          if (lines.isNotEmpty) {
            // Check for "Teacher:" prefix
            final teacherLine = lines.firstWhere(
              (l) => l.toLowerCase().startsWith('teacher:'),
              orElse: () => "",
            );

            if (teacherLine.isNotEmpty) {
              teacherName = teacherLine
                  .replaceAll(RegExp(r'^teacher:\s*', caseSensitive: false), '')
                  .trim();
              if (teacherName.isEmpty) teacherName = null;
            }

            // If we have more lines and didn't find the pattern, use remaining as topic?
            // Original logic: "if lines.length > 1 ... topic = lines.skip(1)..."
            // We should probably keep similar heuristic if the "Teacher:" prefix was used.
            if (lines.length > 1) {
              // If first line was teacher, take the rest.
              // If first line wasn't teacher, maybe the whole thing is topic?
              // The original logic was a bit loose. Let's stick to safe fallback.
              if (teacherName != null) {
                // If we found a "Teacher:" line, assume the rest is topic/notes
                topic = lines.where((l) => l != teacherLine).join('\n').trim();
              } else {
                // If no "Teacher:" prefix found, and no structured pattern,
                // maybe we don't extract anything to avoid bad data?
                // Or logic said: "orElse: () => lines.first".
                // The original logic was:
                // teacherName = teacherLine... (which fell back to lines.first)
                // So effectively it treated the FIRST line as teacher name if no prefix was there.
                // And 2nd line onwards as topic.

                // Preserving exact original fallback behavior:
                final oldTeacherLine = lines.firstWhere(
                  (l) => l.toLowerCase().startsWith('teacher:'),
                  orElse: () => lines.first,
                );
                teacherName = oldTeacherLine
                    .replaceAll(
                        RegExp(r'^teacher:\s*', caseSensitive: false), '')
                    .trim();
                if (teacherName.isEmpty) teacherName = null;

                if (lines.length > 1) {
                  topic = lines.skip(1).join('\n').trim();
                }
              }
            }
          }
        }
      }

      return ClassSession(
        id: DateTime.now().millisecondsSinceEpoch.toString() +
            (event.id ?? ""), // Generate ID
        subjectName: subjectName,
        startTime: startTime,
        endTime: endTime,
        colorValue: 0xFF4287f5, // Default Blue
        teacherName: teacherName,
        topic: topic ??
            event
                .location, // Use location as topic if available and not extracted
        isEvent: false, // Mark as regular class session
      );
    } catch (e) {
      debugPrint('Error mapping event ${event.id}: $e');
      return null;
    }
  }
}

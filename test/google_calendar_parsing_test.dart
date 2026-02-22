import 'package:flutter_test/flutter_test.dart';
import 'package:mad_bunky/services/google_calendar_service.dart';

void main() {
  group('GoogleCalendarService Note Parsing', () {
    test('Extracts topic and teacher when pattern is present', () {
      const description = 'topic - Algebra , teacher - Mr. Smith';
      final result = GoogleCalendarService.parseDescription(description);
      expect(result['topic'], 'Algebra');
      expect(result['teacher'], 'Mr. Smith');
    });

    test('Extracts topic and teacher with surrounding text', () {
      const description =
          'Some random note.\ntopic - Biology , teacher - Dr. Jones\nRoom 101';
      final result = GoogleCalendarService.parseDescription(description);
      expect(result['topic'], 'Biology');
      expect(result['teacher'], 'Dr. Jones');
    });

    test('Extracts topic and teacher with messy spacing', () {
      const description = 'topic-History,teacher-   Mrs. Doe   ';
      final result = GoogleCalendarService.parseDescription(description);
      expect(result['topic'], 'History');
      expect(result['teacher'], 'Mrs. Doe');
    });

    test('Case insensitive matching for keys', () {
      const description = 'Topic - Physics , Teacher - Einstein';
      final result = GoogleCalendarService.parseDescription(description);
      expect(result['topic'], 'Physics');
      expect(result['teacher'], 'Einstein');
    });

    test('Returns null values when pattern is not found', () {
      const description = 'Just a regular note\nTeacher: Someone';
      final result = GoogleCalendarService.parseDescription(description);
      expect(result['topic'], null);
      expect(result['teacher'], null);
    });

    test('Handles null description', () {
      final result = GoogleCalendarService.parseDescription(null);
      expect(result['topic'], null);
      expect(result['teacher'], null);
    });
  });
}

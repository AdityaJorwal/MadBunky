// ignore_for_file: avoid_print

void main() {
  print('Running standalone regex test...');

  Map<String, String?> parseDescription(String? description) {
    if (description == null || description.isEmpty) {
      return {'topic': null, 'teacher': null};
    }

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

  void expect(String? actual, String? matcher, String reason) {
    if (actual != matcher) {
      throw Exception('Failed: $reason. Expected "$matcher", got "$actual"');
    }
    print('Passed: $reason');
  }

  // Test cases

  // 1. Exact format
  var result = parseDescription('topic - Algebra , teacher - Mr. Smith');
  expect(result['topic'], 'Algebra', 'Exact format topic');
  expect(result['teacher'], 'Mr. Smith', 'Exact format teacher');

  // 2. Surrounding text
  result = parseDescription(
      'Some note.\ntopic - Biology , teacher - Dr. Jones\nEnd note.');
  expect(result['topic'], 'Biology', 'Surrounding text topic');
  expect(result['teacher'], 'Dr. Jones', 'Surrounding text teacher');

  // 3. Spacing
  result = parseDescription('topic-History,teacher-Mrs. Doe');
  expect(result['topic'], 'History', 'Spacing topic');
  expect(result['teacher'], 'Mrs. Doe', 'Spacing teacher');

  // 4. Case insensitive
  result = parseDescription('Topic - Physics , Teacher - Einstein');
  expect(result['topic'], 'Physics', 'Case insensitive topic');
  expect(result['teacher'], 'Einstein', 'Case insensitive teacher');

  // 5. Not found
  result = parseDescription('Just a random note');
  expect(result['topic'], null, 'Not found topic');
  expect(result['teacher'], null, 'Not found teacher');

  print('All standalone tests passed!');
}

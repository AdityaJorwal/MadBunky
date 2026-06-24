// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mad_bunky/main.dart';
import 'package:mad_bunky/providers/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App renders correctly', (WidgetTester tester) async {
    // Mock SharedPreferences
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MadBunkyApp(),
      ),
    );

    // Verify that our title is present
    expect(find.text('𝕄𝕒𝕕𝔹𝕦𝕟𝕜𝕪'), findsOneWidget);
  });
}

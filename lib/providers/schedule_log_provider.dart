import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// Stores detailed logs from the Schedule Parser / OCR workflow.
/// These are separate from general app logs to help debug parsing issues.
final scheduleLogProvider =
    StateNotifierProvider<ScheduleLogNotifier, List<String>>((ref) {
  return ScheduleLogNotifier();
});

class ScheduleLogNotifier extends StateNotifier<List<String>> {
  ScheduleLogNotifier() : super([]);

  void addLog(String message) {
    final timestamp = DateTime.now().toIso8601String().split('T').last;
    state = [...state, "[$timestamp] $message"];
  }

  void addLogs(List<String> messages) {
    if (messages.isEmpty) return;
    final timestamp = DateTime.now().toIso8601String().split('T').last;
    final stamped = messages.map((m) => "[$timestamp] $m").toList();
    state = [...state, ...stamped];
  }

  void clear() {
    state = [];
  }

  String get fullLogString => state.join('\n');

  Future<void> shareLogs() async {
    if (state.isEmpty) return;
    final box = state.join('\n');
    await Share.share(box, subject: "MadBunky OCR Logs");
  }
}

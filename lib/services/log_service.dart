import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';

class LogService {
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;
  LogService._internal();

  File? _logFile;
  final String _logFileName = "app_logs.txt";

  Future<void> init() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      _logFile = File('${directory.path}/$_logFileName');
      if (!await _logFile!.exists()) {
        await _logFile!.create();
      }
    } catch (e) {
      debugPrint("Failed to initialize LogService: $e");
    }
  }

  Future<void> log(String message, [StackTrace? stackTrace]) async {
    final timestamp = DateTime.now().toIso8601String();
    final logEntry =
        "[$timestamp] $message\n${stackTrace != null ? stackTrace.toString() : ''}\n";

    // Print to console for debug
    debugPrint(logEntry);

    try {
      if (_logFile != null) {
        await _logFile!.writeAsString(logEntry, mode: FileMode.append);
      }
    } catch (e) {
      debugPrint("Failed to write to log file: $e");
    }
  }

  Future<void> error(dynamic error, StackTrace? stackTrace) async {
    await log("ERROR: $error", stackTrace);
  }

  Future<String> getLogs() async {
    try {
      if (_logFile != null && await _logFile!.exists()) {
        return await _logFile!.readAsString();
      }
    } catch (e) {
      return "Failed to read logs: $e";
    }
    return "";
  }

  Future<void> clearLogs() async {
    try {
      if (_logFile != null && await _logFile!.exists()) {
        await _logFile!.writeAsString("");
      }
    } catch (e) {
      debugPrint("Failed to clear logs: $e");
    }
  }

  Future<void> shareLogs() async {
    try {
      if (_logFile != null && await _logFile!.exists()) {
        final Email email = Email(
          body: 'Hi support team,\n\nPlease find my MadBunky app logs attached.\n\n[Describe your issue here]',
          subject: 'MadBunky Bug Report / Logs',
          recipients: ['support@madbunky.dpdns.org'],
          attachmentPaths: [_logFile!.path],
          isHTML: false,
        );
        await FlutterEmailSender.send(email);
      }
    } catch (e) {
      debugPrint("Failed to share logs via email: $e");
      // Fallback to general share sheet if email client fails
      try {
        if (_logFile != null && await _logFile!.exists()) {
          await Share.shareXFiles([XFile(_logFile!.path)], text: 'MadBunky App Logs / Bug Report\nSupport email: support@madbunky.dpdns.org');
        }
      } catch (ex) {
        debugPrint("Failed to share logs via fallback: $ex");
      }
    }
  }
}

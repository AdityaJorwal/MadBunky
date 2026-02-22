import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class SecurityService {
  static const MethodChannel _channel =
      MethodChannel('com.aj.mad_bunky/security');

  /// Verifies if the app was installed from the Google Play Store.
  /// returns true if verified, false if side-loaded.
  static Future<bool> verifyInstallationSource() async {
    // Bypass check in debug mode
    if (kDebugMode) {
      debugPrint(
          'Security Check: Debug mode verified. Bypassing Play Store check.');
      return true;
    }

    try {
      final String? installerName =
          await _channel.invokeMethod('verifyInstaller');
      debugPrint('Security Check: Installer name is: $installerName');

      // Check for Google Play Store package name
      if (installerName == 'com.android.vending') {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      debugPrint('Security Check Error: $e');
      // If native check fails (e.g. error), treat as insecure to be safe?
      // Or maybe allow if it's just an error? Stricter = return false.
      return false;
    }
  }

  /// Crashes or exits the app depending on platform capabilities.
  static void terminateApp() {
    // Force exit
    SystemChannels.platform.invokeMethod('SystemNavigator.pop');

    // As a fallback/insurance to ensure it stops if pop doesn't work well:
    // We can also throw an exception to crash it if needed, but exit(0) is cleaner.
    // However, on Android, SystemNavigator.pop() is the standard way.
  }
}

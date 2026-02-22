import 'package:flutter/services.dart';

class MadHaptics {
  // Base Primitives
  static Future<void> _light() async => await HapticFeedback.lightImpact();
  static Future<void> _medium() async => await HapticFeedback.mediumImpact();
  static Future<void> _heavy() async => await HapticFeedback.heavyImpact();
  static Future<void> _selection() async =>
      await HapticFeedback.selectionClick();

  // --- Haptic Vocabulary ---

  /// Light tick: Used for selection, toggles, and minor interactions.
  static Future<void> tick() async => _selection();

  /// Heavy thud: Used for errors, warnings, or dropping below thresholds (e.g. <75%).
  static Future<void> thud() async => _heavy();

  /// Success: Distinct pattern indicating achievement or positive action.
  static Future<void> success() async {
    await _medium();
    await Future.delayed(const Duration(milliseconds: 150));
    await _light();
  }

  /// Warning: Quick double vibration for alerts.
  static Future<void> warning() async {
    await _heavy();
    await Future.delayed(const Duration(milliseconds: 100));
    await _heavy();
  }
}

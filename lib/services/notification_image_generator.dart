import 'dart:io';

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../widgets/notification_card.dart';

class NotificationImageGenerator {
  /// The active key for the currently mounted generator.
  /// This prevents "Duplicate GlobalKey" errors during reassembly/theme switches
  /// by ensuring we only track the latest mounted instance.
  static GlobalKey? _activeKey;

  /// Widget that must be placed in the widget tree (hidden) to enable generation
  static Widget wrapper({required Widget child}) {
    return Stack(
      children: [
        child,
        Transform.translate(
          offset: const Offset(-9999, -9999), // Move off-screen
          child: const _GeneratorScope(),
        ),
      ],
    );
  }

  /// Generates an image for the given session and saves it to a file.
  /// Returns the file path.
  static Future<String?> generateAndSave(ClassSession session) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/notification_${session.id}.png';
      final file = File(filePath);

      // Cache Hit: Return existing image if available (Crucial for BG updates)
      if (await file.exists()) {
        return filePath;
      }

      // 1. Update the hidden widget's state
      _currentData.value = session;

      // Wait for build
      await Future.delayed(const Duration(milliseconds: 100)); // Build cycle

      // Use the currently active key
      final key = _activeKey;
      if (key == null) {
        debugPrint("Error: No active NotificationImageGenerator found in tree");
        return null;
      }

      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        debugPrint("Error: RepaintBoundary not found context for active key");
        return null;
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;
      final buffer = byteData.buffer.asUint8List();

      await file.writeAsBytes(buffer);

      return filePath;
    } catch (e) {
      debugPrint("Error generating notification image: $e");
      return null;
    }
  }

  static final ValueNotifier<ClassSession?> _currentData = ValueNotifier(null);
}

class _GeneratorScope extends StatefulWidget {
  const _GeneratorScope();

  @override
  State<_GeneratorScope> createState() => _GeneratorScopeState();
}

class _GeneratorScopeState extends State<_GeneratorScope> {
  final GlobalKey _localKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Register this instance as the active one
    NotificationImageGenerator._activeKey = _localKey;
  }

  @override
  void dispose() {
    // Unregister if we are still the active one
    if (NotificationImageGenerator._activeKey == _localKey) {
      NotificationImageGenerator._activeKey = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: _localKey,
      child: const _CaptureWrapper(),
    );
  }
}

class _CaptureWrapper extends StatelessWidget {
  const _CaptureWrapper();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ClassSession?>(
      valueListenable: NotificationImageGenerator._currentData,
      builder: (context, session, _) {
        if (session == null) {
          // Placeholder layout to ensure size
          return const SizedBox(width: 400, height: 100);
        }
        return Material(
          type: MaterialType.transparency,
          child: NotificationCard(
            subjectName: session.subjectName,
            time:
                "${DateFormat.jm().format(session.startTime)} - ${DateFormat.jm().format(session.endTime)}",
            room: session.teacherName, // Use teacherName as substitute for room
            type: "Class",
          ),
        );
      },
    );
  }
}

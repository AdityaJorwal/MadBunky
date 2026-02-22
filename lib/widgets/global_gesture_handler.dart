import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GlobalGestureHandler extends StatefulWidget {
  final Widget child;

  const GlobalGestureHandler({super.key, required this.child});

  @override
  State<GlobalGestureHandler> createState() => _GlobalGestureHandlerState();
}

class _GlobalGestureHandlerState extends State<GlobalGestureHandler> {
  static const platform = MethodChannel('com.aj.mad_bunky/minimize');

  // Track start scale baseline
  double? _initialAvgDistance;
  bool _gestureTriggered = false;

  // Map of pointer ID to position
  final Map<int, Offset> _pointers = {};

  void _handlePointerEvent(PointerEvent event) {
    // Only apply on large screens
    // Using shortestSide > 600 as a standard breakpoint for tablets/large screens
    final size = MediaQuery.of(context).size;
    if (size.shortestSide < 600) return;

    if (event is PointerDownEvent) {
      _pointers[event.pointer] = event.position;
    } else if (event is PointerMoveEvent) {
      _pointers[event.pointer] = event.position;
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      _pointers.remove(event.pointer);
      // Reset gesture state when fingers are lifted
      if (_pointers.length < 4) {
        _initialAvgDistance = null;
        _gestureTriggered = false;
      }
    }

    // Check for 4 or 5 fingers
    if (_pointers.length >= 4 && _pointers.length <= 5) {
      _processGesture();
    } else {
      _initialAvgDistance = null;
      _gestureTriggered = false;
    }
  }

  void _processGesture() {
    if (_gestureTriggered) return;

    // Calculate centroid
    double sumX = 0;
    double sumY = 0;
    _pointers.forEach((_, position) {
      sumX += position.dx;
      sumY += position.dy;
    });

    final count = _pointers.length;
    final centroid = Offset(sumX / count, sumY / count);

    // Calculate average distance from centroid
    double totalDist = 0;
    _pointers.forEach((_, position) {
      totalDist += (position - centroid).distance;
    });
    final currentAvgDist = totalDist / count;

    if (_initialAvgDistance == null) {
      _initialAvgDistance = currentAvgDist;
    } else {
      // Calculate scale factor
      final scale = currentAvgDist / _initialAvgDistance!;

      // Refined threshold to 0.75
      if (scale < 0.75) {
        _triggerMinimize();
        _gestureTriggered = true;
      }
    }
  }

  Future<void> _triggerMinimize() async {
    try {
      await platform.invokeMethod('minimizeApp');
    } catch (e) {
      debugPrint("Failed to minimize app: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _handlePointerEvent,
      onPointerMove: _handlePointerEvent,
      onPointerUp: _handlePointerEvent,
      onPointerCancel: _handlePointerEvent,
      behavior: HitTestBehavior.translucent, // Ensure touches pass through
      child: widget.child,
    );
  }
}

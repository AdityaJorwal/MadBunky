import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';

class OptimizedGlass extends ConsumerWidget {
  final Widget child;
  final double sigmaX;
  final double sigmaY;
  final Color? fallbackColor;
  final bool forceGlass;
  final BorderRadius? borderRadius; // Added for clipping

  const OptimizedGlass({
    super.key,
    required this.child,
    this.sigmaX = 10.0,
    this.sigmaY = 10.0,
    this.fallbackColor,
    this.forceGlass = false,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (forceGlass) {
      return _buildGlass(child);
    }

    final settings = ref.watch(settingsProvider);
    if (settings.enableBatterySaver) {
      if (fallbackColor != null) {
        return Container(
          decoration: BoxDecoration(
            color: fallbackColor,
            borderRadius: borderRadius,
          ),
          child: child,
        );
      }
      return child;
    }

    return _buildGlass(child);
  }

  Widget _buildGlass(Widget child) {
    // If borderRadius is provided, we must ClipRRect the backdrop filter
    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: sigmaX, sigmaY: sigmaY),
          child: child,
        ),
      );
    }
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: sigmaX, sigmaY: sigmaY),
      child: child,
    );
  }
}

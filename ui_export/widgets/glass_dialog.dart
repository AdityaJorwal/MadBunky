import 'dart:ui';
import 'package:flutter/material.dart';

class GlassDialog extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry padding;

  const GlassDialog({
    super.key,
    required this.child,
    this.width = 340,
    this.height,
    this.padding = const EdgeInsets.all(24),
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return RepaintBoundary(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background Blur
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.black.withValues(alpha: 0.2)),
          ),
          // Dialog
          RepaintBoundary(
            child: Container(
              width: width,
              // Limit height to 85% of screen if not specified, or use constraints
              constraints: BoxConstraints(
                maxHeight: height ?? screenHeight * 0.85,
              ),
              padding: padding,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surface
                    .withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.2),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 30,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:ui';
import 'package:flutter/material.dart';

void showGlassSnackBar(BuildContext context, String message,
    {String? label, VoidCallback? onPressed, Color? color}) {
  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 35, sigmaY: 35),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            color: (color ?? Theme.of(context).colorScheme.tertiaryContainer)
                .withValues(alpha: 0.4), // More translucent
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: (color ?? Theme.of(context).colorScheme.onInverseSurface)
                  .withValues(alpha: 0.1),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center, // Center content
            children: [
              Flexible(
                child: Text(
                  message,
                  style: TextStyle(
                      color: color != null
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
              if (label != null) ...[
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: onPressed,
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color ??
                          Theme.of(context)
                              .colorScheme
                              .primary, // Use primary for action
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    ),
    backgroundColor: Colors.transparent,
    padding: EdgeInsets.zero,
    // Ensure it floats above the custom bottom bar (approx 100px height including padding)
    margin: const EdgeInsets.only(
        left: 24,
        right: 24,
        bottom: 130), // Increased side margins for "smaller" look
    duration: const Duration(milliseconds: 2000),
    behavior: SnackBarBehavior.floating,
    elevation: 0,
    width:
        null, // Let margins control width, or use width property if we want fixed size
  ));
}

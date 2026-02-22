import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ConsolePanel extends StatelessWidget {
  final String title;
  final Widget child;
  final Color borderColor;
  final bool isError;
  final double? height;

  const ConsolePanel({
    super.key,
    required this.title,
    required this.child,
    this.borderColor = const Color(0xFF30363D),
    this.isError = false,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorderColor =
        isError ? const Color(0xFFF85149) : borderColor;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        border: Border.all(color: effectiveBorderColor),
        boxShadow: [
          BoxShadow(
            color: effectiveBorderColor.withValues(alpha: 0.1),
            blurRadius: 8,
            spreadRadius: 1,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: effectiveBorderColor.withValues(alpha: 0.2),
              border: Border(bottom: BorderSide(color: effectiveBorderColor)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title.toUpperCase(),
                  style: GoogleFonts.firaCode(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isError
                        ? const Color(0xFFF85149)
                        : const Color(0xFF7EE787),
                  ),
                ),
                // Decorative corner bits
                Row(
                  children: [
                    Container(width: 4, height: 4, color: effectiveBorderColor),
                    const SizedBox(width: 2),
                    Container(
                        width: 4,
                        height: 4,
                        color: effectiveBorderColor.withValues(alpha: 0.5)),
                    const SizedBox(width: 2),
                    Container(
                        width: 4,
                        height: 4,
                        color: effectiveBorderColor.withValues(alpha: 0.2)),
                  ],
                )
              ],
            ),
          ),
          // Content
          Expanded(
            child: ClipRect(
              child: Stack(
                children: [
                  // Scanline effect (subtle)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.05),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: child,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CircularAttendanceIndicator extends StatelessWidget {
  final double percentage;
  final double target;
  final Color color;
  final double size;

  const CircularAttendanceIndicator({
    super.key,
    required this.percentage,
    required this.target,
    required this.color,
    this.size = 70,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background Circle
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: 6,
              valueColor: AlwaysStoppedAnimation<Color>(
                color.withValues(alpha: 0.1),
              ),
              strokeCap: StrokeCap.round,
            ),
          ),
          // Progress Circle with Animation
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: percentage / 100),
            duration: const Duration(seconds: 1),
            curve: Curves.easeOutQuart,
            builder: (context, value, _) {
              return SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  value: value,
                  strokeWidth: 6,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  strokeCap: StrokeCap.round,
                  backgroundColor: Colors.transparent,
                ),
              );
            },
          ),
          // Text
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "${percentage.toStringAsFixed(0)}%",
                style: GoogleFonts.outfit(
                  fontSize: size * 0.25,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

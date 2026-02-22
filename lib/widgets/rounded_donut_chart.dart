import 'dart:math';
import 'package:flutter/material.dart';

class DonutItem {
  final double value;
  final Color color;

  const DonutItem({required this.value, required this.color});
}

class RoundedDonutChart extends StatelessWidget {
  final List<DonutItem> items;
  final double innerRadius;
  final double thickness;
  final double spacing; // In radians approx or visual gap

  const RoundedDonutChart({
    super.key,
    required this.items,
    this.innerRadius = 30,
    this.thickness = 25,
    this.spacing = 0.05, // Small gap
    this.isNeon = false,
  });

  final bool isNeon;

  @override
  Widget build(BuildContext context) {
    // Filter out zero values
    final validItems = items.where((e) => e.value > 0).toList();
    if (validItems.isEmpty) {
      return SizedBox(
        width: (innerRadius + thickness) * 2,
        height: (innerRadius + thickness) * 2,
        child: CustomPaint(
          painter: _EmptyDonutPainter(
              innerRadius: innerRadius,
              thickness: thickness,
              color: Theme.of(context).colorScheme.surfaceContainerHighest),
        ),
      );
    }

    return SizedBox(
      width: (innerRadius + thickness) * 2,
      height: (innerRadius + thickness) * 2,
      child: CustomPaint(
        painter: _RoundedDonutPainter(
          items: validItems,
          innerRadius: innerRadius,
          thickness: thickness,
          spacing: spacing,
          isNeon: isNeon,
        ),
      ),
    );
  }
}

class _RoundedDonutPainter extends CustomPainter {
  final List<DonutItem> items;
  final double innerRadius;
  final double thickness;
  final double spacing;
  final bool isNeon;

  _RoundedDonutPainter({
    required this.items,
    required this.innerRadius,
    required this.thickness,
    required this.spacing,
    required this.isNeon,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (items.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = innerRadius + (thickness / 2);
    final totalValue = items.fold(0.0, (sum, item) => sum + item.value);

    // Single item case: Draw full continuous ring
    if (items.length == 1) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..color = items.first.color
        ..strokeCap = StrokeCap.butt; // Smooth join for full circle

      if (isNeon) {
        final glowPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = thickness + 4
          ..color = items.first.color.withValues(alpha: 0.6)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
          ..strokeCap = StrokeCap.butt;
        canvas.drawCircle(center, radius, glowPaint);
      }
      canvas.drawCircle(center, radius, paint);
      return;
    }

    // --- GAP & CAP LOGIC ---
    // Cap Angle: The angle occupied by the rounded cap on ONE end.
    // For StrokeCap.round, the cap extends 'thickness/2' units along the tangent.
    // Angle = (arc_length) / radius  => (thickness/2) / radius
    final capAngle = (thickness / 2) / radius;

    // Total angle consumed by gaps between segments
    final totalGapAngle = items.length * spacing;

    // Available angle for the actual segments (visual length INCLUDING caps)
    final availableAngle = (2 * pi) - totalGapAngle;

    // If spacing is too large, fallback to a fail-safe mode (ignore spacing)
    if (availableAngle <= 0) {
      _paintFallback(canvas, center, radius, totalValue);
      return;
    }

    double currentStart = -pi / 2; // Start from top (12 o'clock)

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;

    for (var item in items) {
      final share = item.value / totalValue;
      // Visual angle this segment should appear to occupy (from cap end to cap end)
      final visualSweep = share * availableAngle;

      // The actual path sweep needs to retract by one cap diameter (two cap radii)
      // so that the caps sit *inside* the visual sweep boundaries.
      final pathSweep = visualSweep - (2 * capAngle);

      // Center start: visual boundary + cap radius offset
      final pathStart = currentStart + capAngle;

      if (pathSweep > 0) {
        paint.color = item.color;
        if (isNeon) {
          final glowPaint = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = thickness + 4
            ..color = item.color.withValues(alpha: 0.6)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
            ..strokeCap = StrokeCap.round;

          canvas.drawArc(
            Rect.fromCircle(center: center, radius: radius),
            pathStart,
            pathSweep,
            false,
            glowPaint,
          );
        }

        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          pathStart,
          pathSweep,
          false,
          paint,
        );
      } else {
        // Segment too small for full caps. Draw a minimal dot if value exists.
        if (visualSweep > 0) {
          paint.color = item.color;
          final dotAngle = currentStart + (visualSweep / 2);
          // Draw minimal arc to trigger cap rendering
          canvas.drawArc(
            Rect.fromCircle(center: center, radius: radius),
            dotAngle,
            0.001,
            false,
            paint,
          );
        }
      }

      // Advance by visual sweep + spacing gap
      currentStart += visualSweep + spacing;
    }
  }

  void _paintFallback(
      Canvas canvas, Offset center, double radius, double totalValue) {
    double startAngle = -pi / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;

    for (var item in items) {
      // Just draw proportional arcs with no gap logic if things are too tight
      final sweep = (item.value / totalValue) * 2 * pi;
      paint.color = item.color;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
          startAngle, sweep * 0.9, false, paint);
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _EmptyDonutPainter extends CustomPainter {
  final double innerRadius;
  final double thickness;
  final Color color;

  _EmptyDonutPainter(
      {required this.innerRadius,
      required this.thickness,
      required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = innerRadius + (thickness / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..color = color
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

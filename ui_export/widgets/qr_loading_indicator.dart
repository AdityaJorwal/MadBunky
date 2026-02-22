import 'dart:math';
import 'package:flutter/material.dart';

class QRLoadingIndicator extends StatefulWidget {
  final double size;
  final Color color;

  const QRLoadingIndicator({
    super.key,
    this.size = 60.0,
    this.color = Colors.white,
  });

  @override
  State<QRLoadingIndicator> createState() => _QRLoadingIndicatorState();
}

class _QRLoadingIndicatorState extends State<QRLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  // 7x7 grid for valid QR visual
  final int gridCount = 7;
  // Store random phases for each dot so they shimmer independently
  late List<double> _phases;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat();

    _phases = List.generate(
        gridCount * gridCount, (_) => Random().nextDouble() * 2 * pi);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _QRLoadingPainter(
              progress: _controller.value,
              color: widget.color,
              gridCount: gridCount,
              phases: _phases,
            ),
          );
        },
      ),
    );
  }
}

class _QRLoadingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final int gridCount;
  final List<double> phases;

  _QRLoadingPainter({
    required this.progress,
    required this.color,
    required this.gridCount,
    required this.phases,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double padding = size.width * 0.05;
    final double availableSize = size.width - (padding * 2);
    final double moduleSize = availableSize / gridCount;
    // slightly smaller to leave gap
    final double drawSize = moduleSize * 0.8;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Draw "Finder Patterns" (Corners) - they should be stable
    // Top-Left (0,0 to 2,2)
    _drawFinder(canvas, 0, 0, moduleSize, drawSize, paint, padding);
    // Top-Right (gridCount-3, 0)
    _drawFinder(canvas, gridCount - 3, 0, moduleSize, drawSize, paint, padding);
    // Bottom-Left (0, gridCount-3)
    _drawFinder(canvas, 0, gridCount - 3, moduleSize, drawSize, paint, padding);

    // Draw chaotic middle bits
    for (int x = 0; x < gridCount; x++) {
      for (int y = 0; y < gridCount; y++) {
        // Skip finder areas
        if ((x < 3 && y < 3) ||
            (x >= gridCount - 3 && y < 3) ||
            (x < 3 && y >= gridCount - 3)) {
          continue;
        }

        final index = y * gridCount + x;
        final phase = phases[index];

        // Calculate opacity based on sine wave with random phase
        // sin(2pi * t + phase) -> -1 to 1 -> normalize to 0 to 1
        // We want a dissolve effect, maybe blinking?
        // Let's use a smoother shimmer.

        final double t = (progress * 2 * pi) + phase;
        final double val = sin(t);
        // Normalize -1..1 to 0..1
        double opacity = (val + 1) / 2;

        // Sharpen the curve to make it "blink" more than "fade"
        // if opacity > 0.5 -> 1, else 0? Or smooth step?
        // Let's keep it smooth but varied.

        // Use threshold for digital feel
        opacity = opacity > 0.4 ? opacity : 0.0;

        if (opacity > 0) {
          paint.color = color.withValues(alpha: opacity);

          final double left =
              padding + x * moduleSize + (moduleSize - drawSize) / 2;
          final double top =
              padding + y * moduleSize + (moduleSize - drawSize) / 2;

          canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTWH(left, top, drawSize, drawSize),
                Radius.circular(drawSize * 0.3), // Rounded edges
              ),
              paint);
        }
      }
    }
  }

  void _drawFinder(Canvas canvas, int startX, int startY, double moduleSize,
      double drawSize, Paint paint, double padding) {
    // 3x3 block, simplistic finder (just a solid block or ring?)
    // Let's draw a ring shape:
    // Paint full 3x3
    // Remove center 1x1?

    paint.color = color; // Solid color for finders

    // We can draw individual modules for the finder to match style
    for (int x = startX; x < startX + 3; x++) {
      for (int y = startY; y < startY + 3; y++) {
        bool isCenter = (x == startX + 1 && y == startY + 1);
        // Standard finder: Ring of 3x3, empty middle?
        // Actually standard is Black 7x7, White 5x5, Black 3x3.
        // Since our grid is small (7x7), a 3x3 finder is huge.
        // Let's just make the finder 'solid' except the very middle pixel
        // to imply the "center".

        if (isCenter) continue; // Hollow center

        final double left =
            padding + x * moduleSize + (moduleSize - drawSize) / 2;
        final double top =
            padding + y * moduleSize + (moduleSize - drawSize) / 2;

        canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(left, top, drawSize, drawSize),
              Radius.circular(drawSize * 0.3),
            ),
            paint);
      }
    }

    // Draw Single Center Dot
    final double cx =
        padding + (startX + 1) * moduleSize + (moduleSize - drawSize) / 2;
    final double cy =
        padding + (startY + 1) * moduleSize + (moduleSize - drawSize) / 2;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(cx, cy, drawSize, drawSize),
          Radius.circular(drawSize * 0.3),
        ),
        paint);
  }

  @override
  bool shouldRepaint(covariant _QRLoadingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

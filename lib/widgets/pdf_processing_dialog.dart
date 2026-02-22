import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import '../utils/morph_dialog.dart';

class PdfProcessingDialog extends StatefulWidget {
  const PdfProcessingDialog({super.key});

  @override
  State<PdfProcessingDialog> createState() => _PdfProcessingDialogState();
}

class _PdfProcessingDialogState extends State<PdfProcessingDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _percent = 0.0;
  Timer? _fakeProgressTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // Fake progress
    _fakeProgressTimer =
        Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted) return;
      setState(() {
        if (_percent < 0.90) {
          _percent += 0.01;
        } else {
          // Slow down at end
          if (_percent < 0.95) _percent += 0.001;
        }
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _fakeProgressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GlassDialogContainer(
      title: "Analyzing PDF...",
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),

          // Fluid Progress Bar
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 40,
                width: double.infinity,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: _LiquidProgressPainter(
                        percent: _percent,
                        animationValue: _controller.value,
                        color: Theme.of(context).primaryColor,
                        backgroundColor: Theme.of(context).canvasColor,
                      ),
                    );
                  },
                ),
              ),
              Text(
                "${(_percent * 100).toInt()}%",
                style: TextStyle(
                    color: _percent > 0.5
                        ? Colors.white
                        : Theme.of(context)
                            .primaryColor, // Contrast flip heuristic
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    shadows: [
                      if (_percent > 0.5)
                        const BoxShadow(color: Colors.black26, blurRadius: 2)
                    ]),
              )
            ],
          )
        ],
      ),
    );
  }
}

class _LiquidProgressPainter extends CustomPainter {
  final double percent;
  final double animationValue;
  final Color color;
  final Color backgroundColor;

  _LiquidProgressPainter({
    required this.percent,
    required this.animationValue,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect,
        Radius.circular(size.height / 2)); // High radius for capsule shape

    // Draw background
    final bgPaint = Paint()
      ..color = backgroundColor; // Sligthly darker context usually
    canvas.drawRRect(rrect, bgPaint);

    // Clip to capsule
    canvas.save();
    canvas.clipRRect(rrect);

    // Draw Liquid
    final wavePaint = Paint()..color = color;
    final path = Path();

    // Width filled
    final width = size.width * percent;

    // If progress is very low, we might not see wave, but let's draw it at the "end" edge
    // Actually, "Process Bar ... with percentage" usually fills horizontal.
    // The "liquid" effect usually implies the SURFACE is wavy.

    // We will draw a rect from 0 to width.
    // The Right edge should be wavy? No, the user said "Process bar". Usually liquid fills from left to right.
    // Let's make the RIGHT EDGE vertical wavy.

    double waveHeight = 4.0;
    double frequency = 2.0;

    path.moveTo(0, 0);
    // Top line to current width
    for (double i = 0; i <= size.height; i++) {
      // Logic for vertical wave on the right side?
      // Or horizontal wave on top?
      // A standard progress bar fills L->R.
      // Liquid effect usually means the leading edge is wobbly.

      // Let's draw the Leading Edge.
      // x = width + sine
    }

    // Re-thinking simpler liquid:
    // Just draw a rect but the RIGHT SIDE is a sine wave.

    path.reset();
    path.moveTo(0, 0);

    // Draw top edge
    path.lineTo(width, 0);

    // Draw wavy right edge
    // y goes 0 -> height
    for (double y = 0; y <= size.height; y++) {
      double waveX = width +
          sin((y / size.height * frequency * pi * 2) +
                  (animationValue * pi * 2)) *
              waveHeight;
      // Clamp to size
      if (waveX > size.width) waveX = size.width;
      path.lineTo(waveX, y);
    }

    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, wavePaint);

    // Add "bubbles" or gloss if desired? Keep it clean for now.

    canvas.restore();

    // Border
    // final borderPaint = Paint()
    //   ..color = color.withOpacity(0.2)
    //   ..style = PaintingStyle.stroke
    //   ..strokeWidth = 1;
    // canvas.drawRRect(rrect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _LiquidProgressPainter oldDelegate) {
    return oldDelegate.percent != percent ||
        oldDelegate.animationValue != animationValue;
  }
}

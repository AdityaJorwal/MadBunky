import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SparkWidget extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onEdgeHit; // Trigger external edge effects
  final Color sparkColor;

  const SparkWidget({
    super.key,
    required this.child,
    this.onTap,
    this.onEdgeHit,
    this.sparkColor = const Color(0xFFFFD700),
  });

  @override
  State<SparkWidget> createState() => SparkWidgetState();
}

class SparkWidgetState extends State<SparkWidget> {
  void fire() {
    // Tight tap feedback
    HapticFeedback.mediumImpact();
    _triggerElectricEffect();
    widget.onTap?.call();
  }

  void _triggerElectricEffect() {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final size = renderBox.size;
    final position = renderBox.localToGlobal(Offset.zero);
    final center = position + Offset(size.width / 2, size.height / 2);

    final entry = OverlayEntry(
      builder: (context) => _ElectricOverlay(
        startPosition: center,
        color: widget.sparkColor,
        onEdgeHit: widget.onEdgeHit,
      ),
    );

    Overlay.of(context).insert(entry);

    // Remove after animation (faster projectile ~500ms is enough)
    Future.delayed(const Duration(milliseconds: 600), () {
      if (entry.mounted) entry.remove();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: fire,
      behavior: HitTestBehavior.opaque,
      child: widget.child,
    );
  }
}

class _ElectricOverlay extends StatefulWidget {
  final Offset startPosition;
  final Color color;
  final VoidCallback? onEdgeHit;

  const _ElectricOverlay({
    required this.startPosition,
    required this.color,
    this.onEdgeHit,
  });

  @override
  State<_ElectricOverlay> createState() => _ElectricOverlayState();
}

class _ElectricOverlayState extends State<_ElectricOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  List<_BoltData> _bolts = [];
  bool _hitEdgeTriggered = false;
  Timer? _hapticTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500), // Faster, snappier
    );

    // Initial random angles
    _bolts = List.generate(8, (index) {
      // Reduced count for cleaner look
      final angle = Random().nextDouble() * 2 * pi;
      return _BoltData(angle: angle);
    });

    _controller.addListener(() {
      // Trigger Impact when projectile hits end (progress ~ 1.0)
      if (_controller.value >= 0.95 && !_hitEdgeTriggered) {
        _hitEdgeTriggered = true;
        _triggerImpact();
      }
    });

    _startHapticTrain();
    _controller.forward();
  }

  void _startHapticTrain() {
    // Traveling haptics: Fast, distinct ticks (like Pixel volume slider)
    // 60ms interval ~ 16Hz
    _hapticTimer = Timer.periodic(const Duration(milliseconds: 60), (timer) {
      if (!_controller.isAnimating || _controller.isCompleted) {
        timer.cancel();
        return;
      }
      // Light selection click for "traveling" sensation
      HapticFeedback.selectionClick();
    });
  }

  void _triggerImpact() {
    // 1. Haptic
    HapticFeedback.heavyImpact();

    // 2. External callback (Edge Glow)
    widget.onEdgeHit?.call();

    // 3. Spawn Local Impact Overlay (Scatter) at intersection points
    final screenSize = MediaQuery.of(context).size;

    for (final bolt in _bolts) {
      final dist = _calculateDistanceToEdge(
          widget.startPosition, bolt.angle, screenSize);
      final impactPos = widget.startPosition +
          Offset(cos(bolt.angle) * dist, sin(bolt.angle) * dist);

      _spawnScatter(impactPos);
    }
  }

  void _spawnScatter(Offset pos) {
    final entry = OverlayEntry(
      builder: (context) => _ImpactScatterOverlay(
        position: pos,
        color: widget.color,
      ),
    );
    Overlay.of(context).insert(entry);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (entry.mounted) entry.remove();
    });
  }

  double _calculateDistanceToEdge(Offset start, double angle, Size screenSize) {
    final dx = cos(angle);
    final dy = sin(angle);

    double tMin = double.infinity;

    // Right Wall (x = width)
    if (dx > 0) {
      double t = (screenSize.width - start.dx) / dx;
      if (t < tMin) tMin = t;
    }
    // Left Wall (x = 0)
    else if (dx < 0) {
      double t = (0 - start.dx) / dx;
      if (t < tMin) tMin = t;
    }

    // Bottom Wall (y = height)
    if (dy > 0) {
      double t = (screenSize.height - start.dy) / dy;
      if (t < tMin) tMin = t;
    }
    // Top Wall (y = 0)
    else if (dy < 0) {
      double t = (0 - start.dy) / dy;
      if (t < tMin) tMin = t;
    }

    return tMin;
  }

  @override
  void dispose() {
    _hapticTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _ProjectilePainter(
              startPos: widget.startPosition,
              bolts: _bolts,
              progress: _controller.value,
              color: widget.color,
              screenSize: MediaQuery.of(context).size,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _BoltData {
  final double angle;
  _BoltData({required this.angle});
}

class _ProjectilePainter extends CustomPainter {
  final Offset startPos;
  final List<_BoltData> bolts;
  final double progress;
  final Color color;
  final Size screenSize;

  _ProjectilePainter({
    required this.startPos,
    required this.bolts,
    required this.progress,
    required this.color,
    required this.screenSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    // Projectile length (pixels)
    const double projectileLength = 150.0;

    for (final bolt in bolts) {
      // 1. Calculate Full Distance to Edge
      final fullDist =
          _calculateDistanceToEdge(startPos, bolt.angle, screenSize);

      // 2. Current Head Position
      final currentHeadDist = fullDist * progress;

      // 3. Current Tail Position (lagging behind)
      final currentTailDist = max(0.0, currentHeadDist - projectileLength);

      // If tail reached end, fade out
      if (currentTailDist >= fullDist) continue;

      // Limit head to fullDist (stick to wall for a moment or just stop)
      final drawHeadDist = min(fullDist, currentHeadDist);
      final drawTailDist = min(fullDist, currentTailDist);

      if (drawHeadDist <= drawTailDist) continue;

      final dx = cos(bolt.angle);
      final dy = sin(bolt.angle);

      final headPos = startPos + Offset(dx * drawHeadDist, dy * drawHeadDist);
      final tailPos = startPos + Offset(dx * drawTailDist, dy * drawTailDist);

      final path = Path();
      path.moveTo(tailPos.dx, tailPos.dy);

      // Zig-Zag logic
      const int segments = 10;
      // Perpendicular vector for offset
      final pdx = -dy;
      final pdy = dx;

      // Amplitude scales with projectile speed visually, and tapers
      final amplitude = 12.0;

      for (int i = 1; i < segments; i++) {
        final t = i / segments;
        final pointOnLine = Offset.lerp(tailPos, headPos, t)!;

        // Random Zig-Zag offset
        // Using hashcode and frame(progress) to make it crackle
        final seed = (i * 10) + (progress * 1000).toInt() + bolt.hashCode;
        final r = Random(seed);

        final offsetAmount = (r.nextDouble() - 0.5) * 2 * amplitude;

        final zigZagPoint =
            pointOnLine + Offset(pdx * offsetAmount, pdy * offsetAmount);

        path.lineTo(zigZagPoint.dx, zigZagPoint.dy);
      }
      path.lineTo(headPos.dx, headPos.dy);

      // Stroke width tapers from head to tail?
      // Simple stroke for now
      paint.strokeWidth = 3.0;
      glowPaint.strokeWidth = 6.0;

      canvas.drawPath(path, glowPaint);
      canvas.drawPath(path, paint);

      // Draw bright head
      canvas.drawCircle(headPos, 3, paint..style = PaintingStyle.fill);
    }
  }

  double _calculateDistanceToEdge(Offset start, double angle, Size screenSize) {
    // Duplicate logic from state, but needed for drawing
    final dx = cos(angle);
    final dy = sin(angle);
    double tMin = double.infinity;

    if (dx > 0) {
      double t = (screenSize.width - start.dx) / dx;
      if (t < tMin) tMin = t;
    } else if (dx < 0) {
      double t = (0 - start.dx) / dx;
      if (t < tMin) tMin = t;
    }

    if (dy > 0) {
      double t = (screenSize.height - start.dy) / dy;
      if (t < tMin) tMin = t;
    } else if (dy < 0) {
      double t = (0 - start.dy) / dy;
      if (t < tMin) tMin = t;
    }
    return tMin;
  }

  @override
  bool shouldRepaint(_ProjectilePainter old) => true;
}

// --- Impact Scatter Overlay ---

class _ImpactScatterOverlay extends StatefulWidget {
  final Offset position;
  final Color color;

  const _ImpactScatterOverlay({required this.position, required this.color});

  @override
  State<_ImpactScatterOverlay> createState() => _ImpactScatterOverlayState();
}

class _ImpactScatterOverlayState extends State<_ImpactScatterOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  List<_ZigZagParticle> _particles = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));

    // Create particles
    _particles = List.generate(8, (index) {
      final angle = Random().nextDouble() * 2 * pi;
      final speed = Random().nextDouble() * 80 + 40; // pixels per second
      return _ZigZagParticle(
          angle: angle, speed: speed, seed: Random().nextInt(1000));
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _ImpactPainter(
              origin: widget.position,
              particles: _particles,
              progress: _controller.value,
              color: widget.color,
            ),
          );
        },
      ),
    );
  }
}

class _ZigZagParticle {
  final double angle;
  final double speed;
  final int seed;
  _ZigZagParticle(
      {required this.angle, required this.speed, required this.seed});
}

class _ImpactPainter extends CustomPainter {
  final Offset origin;
  final List<_ZigZagParticle> particles;
  final double progress;
  final Color color;

  _ImpactPainter(
      {required this.origin,
      required this.particles,
      required this.progress,
      required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final fade = 1.0 - progress;
    final paint = Paint()
      ..color = color.withValues(alpha: fade)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    for (final p in particles) {
      final dist = p.speed * (progress * 0.4) + 10; // Move out
      final dx = cos(p.angle);
      final dy = sin(p.angle);

      final centerPos = origin + Offset(dx * dist, dy * dist);

      // Draw small zig-zag line instead of circle
      final path = Path();
      // Start a bit "behind"
      final startOffset = Offset(-dx * 8, -dy * 8);
      path.moveTo(centerPos.dx + startOffset.dx, centerPos.dy + startOffset.dy);

      // Perpendicular for jaggedness
      final pdx = -dy;
      final pdy = dx;

      final r = Random(p.seed);
      final zigP = centerPos +
          Offset(pdx * (r.nextBool() ? 4 : -4), pdy * (r.nextBool() ? 4 : -4));
      path.lineTo(zigP.dx, zigP.dy);

      // End point
      final endOffset = Offset(dx * 8, dy * 8);
      path.lineTo(centerPos.dx + endOffset.dx, centerPos.dy + endOffset.dy);

      canvas.drawPath(path, paint);
    }

    // Draw central impact glow
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.5 * fade)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);

    canvas.drawCircle(origin, 20 * (1 + progress), glowPaint);
  }

  @override
  bool shouldRepaint(_ImpactPainter old) => true;
}

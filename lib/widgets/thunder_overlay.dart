import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';

class ThunderOverlay extends ConsumerStatefulWidget {
  final Widget child;
  const ThunderOverlay({super.key, required this.child});

  @override
  ConsumerState<ThunderOverlay> createState() => ThunderOverlayState();
}

class ThunderOverlayState extends ConsumerState<ThunderOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    // Total duration: 900ms
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));

    // Sudden appear (0-100ms), Smooth fade (100-900ms)
    // We use a TweenSequence or explicitly intervals.
    _opacity = TweenSequence([
      // Sudden IN: 0 -> 1 in 10% of time (90ms)
      TweenSequenceItem(
          tween: Tween(begin: 0.0, end: 1.0)
              .chain(CurveTween(curve: Curves.easeOutExpo)),
          weight: 10),
      // Smooth OUT: 1 -> 0 in 90% of time (810ms)
      TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 0.0)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 90),
    ]).animate(_controller);
  }

  void trigger() {
    _controller.forward(from: 0);
  }

  @override
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(proxyEffectTriggerProvider, (prev, next) {
      if (next > (prev ?? 0)) {
        _controller.forward(from: 0);
      }
    });

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        IgnorePointer(
          child: AnimatedBuilder(
            animation: _opacity,
            builder: (ctx, child) => Opacity(
              opacity: _opacity.value,
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    // Tighter radius to push it to edges? No, 1.0 reaches edges of shortest side.
                    // We want "edge glowing".
                    // 1.2 or 1.3 pushes the center transparent part wider.
                    radius: 1.4,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Colors.orange.withValues(alpha: 0.1), // Inner glow start
                      Colors.orangeAccent.withValues(alpha: 0.3), // Mid glow
                      const Color(0xFFFFD700)
                          .withValues(alpha: 0.6), // Edge Gold
                    ],
                    stops: const [0.0, 0.6, 0.8, 0.9, 1.0],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

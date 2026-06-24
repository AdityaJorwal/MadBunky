import 'dart:ui';
import 'package:flutter/material.dart';

class MorphingText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final Duration duration;

  const MorphingText(
    this.text, {
    super.key,
    this.style = const TextStyle(),
    this.duration = const Duration(milliseconds: 500),
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.easeOutQuart,
      switchOutCurve: Curves.easeInQuart,
      transitionBuilder: (child, animation) {
        return _MorphTransition(
          animation: animation,
          child: child,
        );
      },
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.center,
          children: <Widget>[
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      child: Text(
        text,
        key: ValueKey<String>(text),
        style: style,
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _MorphTransition extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const _MorphTransition({
    required this.animation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final val = animation.value;
        // 0 -> 1 (In)
        // 1 -> 0 (Out)

        // Blur: High -> 0
        final blur = (1 - val) * 10.0;
        // Scale: 0.8 -> 1.0 (In), 1.0 -> 1.2 (Out check handled by separate instance usually?)
        // Actually AnimatedSwitcher runs one instance forward 0->1, and one reverse 1->0.
        // Wait, NO. switchOut runs Reverse (1->0) on the OLD child. switchIn runs Forward (0->1) on NEW child.

        // So:
        // Forward (Entering): Val goes 0 -> 1. Blur goes 10 -> 0. Scale 0.5 -> 1.0. Opacity 0 -> 1.
        // Reverse (Exiting): Val goes 1 -> 0. Blur goes 0 -> 10. Scale 1.0 -> 1.5. Opacity 1 -> 0.

        // However, AnimatedSwitcher reuses the transition builder.
        // So for the EXITING child, it is running in reverse.
        // We want Exiting to Blow up (Scale > 1) and Entering to Shrink in (Scale < 1 -> 1).

        // But how to distinguish? We don't easily inside standard TransitionBuilder without external state.
        // Standard ScaleTransition scales 0->1.

        // Let's just use Scale 0.8 -> 1.0. And Fade 0 -> 1.
        // Blur is symmetric.

        return Opacity(
          opacity: val.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: 0.8 + (0.2 * val), // 0.8 -> 1.0
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }
}

class LiquidText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final Duration duration;

  const LiquidText(
    this.text, {
    super.key,
    this.style = const TextStyle(),
    this.duration = const Duration(milliseconds: 600), // Slower for liquid feel
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.easeOutBack, // Bouncy enter
      switchOutCurve: Curves.easeInBack, // Bouncy exit
      transitionBuilder: (child, animation) {
        return _LiquidTransition(
          animation: animation,
          child: child,
        );
      },
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.center,
          children: <Widget>[
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      child: Text(
        text,
        key: ValueKey<String>(text),
        style: style,
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _LiquidTransition extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const _LiquidTransition({
    required this.animation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final val = animation.value;
        // LIQUID EFFECT:
        // Overlap Blur with Scale.
        // Enter: Blur 10 -> 0, Scale 0.5 -> 1.0, Opacity 0 -> 1
        // Exit: Blur 0 -> 10, Scale 1.0 -> 1.5 (Spread out), Opacity 1 -> 0

        // Determine if we are entering or exiting based on the status?
        // AnimatedBuilder doesn't know. But standard usage:
        // Entering child runs 0->1. Exiting child runs 1->0 (Reverse).

        // So we design a symmetric transition where 1.0 is "Normal" and 0.0 is "Liquid Blob".

        final blur = (1 - val) * 12.0;
        final scale = 0.5 + (0.5 * val); // 0.5 -> 1.0

        // Enhance: If val is close to 0, opacity drops faster to hide the "blob" jumping
        final opacity = val.clamp(0.0, 1.0);

        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }
}

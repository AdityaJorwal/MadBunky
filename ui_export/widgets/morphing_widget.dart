import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'non_clipping_size_transition.dart';

/// A widget that morphs its child change with a "Melting" fluid effect.
/// Uses a Stack layout to allow cross-dissolve overlap.
class MorphingWidget extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final Duration? reverseDuration;

  const MorphingWidget({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 600),
    this.reverseDuration,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      reverseDuration: reverseDuration ?? duration ~/ 2,
      switchInCurve: Curves.easeOutQuart, // Fast entry to prevent "blank" start
      switchOutCurve: Curves.easeInQuart,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.center,
          children: [
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      transitionBuilder: (child, animation) {
        return MorphTransition(
          animation: animation,
          child: child,
        );
      },
      child: child,
    );
  }
}

/// The core transition effect: Smooth Blur + Scale + Opacity (Particle Dissolve)
class MorphTransition extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const MorphTransition({
    super.key,
    required this.animation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // 1. RepaintBoundary isolates the liquid effect
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final val = animation.value;

          // "Particle" Dissolve Logic

          // Blur:
          // 1.0 (Visible) -> 0.0 Blur
          // 0.0 (Gone) -> High Blur (Simulating dispersion)
          final double blur =
              (1.0 - val) * 12.0; // Significant blur for "cloud" effect

          // Scale:
          // 1.0 (Visible) -> 1.0 Scale
          // 0.0 (Gone) -> 0.8 Scale (Implode) or 1.2 (Explode)?
          // "Morphing particles" usually disperse. Let's try slight expansion + blur.
          final double scale = 1.0 + ((1.0 - val) * 0.15);

          // Opacity:
          // We want it to be visible as long as possible while blurring, then fade out.
          // Curve: 1.0 -> 0.4 (Keep mostly visible) -> 0.0 (Fade)
          // Simple clamp for now, but let's make it last longer.
          final double opacity = val.clamp(0.0, 1.0);

          // Optimization: Skip ImageFiltered if fully visible
          if (val > 0.99) {
            return child!;
          }

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
      ),
    );
  }
}

/// Morphs text character-by-character for a more fluid effect
class MorphingText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;

  const MorphingText(
    this.text, {
    super.key,
    this.style,
    this.textAlign = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    // Split text into characters
    final chars = text.split('');

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: textAlign == TextAlign.center
          ? MainAxisAlignment.center
          : TextAlign.end == textAlign
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
      children: chars
          .asMap()
          .entries
          .map((entry) => _MorphingChar(
                char: entry.value,
                style: style,
                index: entry.key, // Can be used for staggered delays if needed
              ))
          .toList(),
    );
  }
}

class _MorphingChar extends StatelessWidget {
  final String char;
  final TextStyle? style;
  final int index;

  const _MorphingChar({
    required this.char,
    required this.style,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    // Unique key ensures AnimatedSwitcher detects change
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      switchInCurve: Curves.easeInOutBack,
      switchOutCurve: Curves.easeInBack,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.center,
          children: <Widget>[
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      transitionBuilder: (Widget child, Animation<double> animation) {
        return MorphTransition(
          animation: animation,
          child: child,
        );
      },
      child: Text(
        char,
        key: ValueKey(char),
        style: style,
      ),
    );
  }
}

/// Orchestrates the Layout vs Visual animation staggering
class MorphItemTransition extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const MorphItemTransition({
    super.key,
    required this.animation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // Staggered Animation Logic:

    // 1. Layout (Size)
    // Insertion: Expands EARLY (0.0 -> 0.6) to create space.
    // Deletion: Collapses LATE (0.6 -> 0.0) after visuals are gone.
    // Interval(0.0, 0.6) - Slightly tighter to ensure full size before visuals dominate.
    final sizeAnimation = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      reverseCurve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
    );

    // 2. Visuals (Blur/Dissolve)
    // Insertion: Appears LATE (0.5 -> 1.0) after space is MOSTLY ready.
    // Deletion: Disappears EARLY (1.0 -> 0.5) while space is still full.
    // Interval(0.5, 1.0)
    final visualAnimation = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic),
    );

    // Use NonClippingSizeTransition to allow blur/scale overflow during the visual phase.
    return NonClippingSizeTransition(
      sizeFactor: sizeAnimation,
      axisAlignment: 0,
      child: MorphTransition(
        animation: visualAnimation,
        child: child,
      ),
    );
  }
}

/// A staggered animation effect that applies the "Morph" (Blur + Scale + Fade)
/// compatible with [flutter_staggered_animations].
class StaggeredMorphEffect extends StatefulWidget {
  final Widget child;

  const StaggeredMorphEffect({super.key, required this.child});

  @override
  State<StaggeredMorphEffect> createState() => _StaggeredMorphEffectState();
}

class _StaggeredMorphEffectState extends State<StaggeredMorphEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    // Use the configuration from flutter_staggered_animations
    final animationConfig = AnimationConfiguration.of(context);
    final duration =
        animationConfig?.duration ?? const Duration(milliseconds: 375);
    final delay = animationConfig?.delay ?? Duration.zero;

    _controller = AnimationController(
      vsync: this,
      duration: duration,
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    // Start after delay
    Future.delayed(delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final val = _animation.value;

        // Same logic as MorphTransition but 0 -> 1 for Entrance
        // Val goes 0.0 -> 1.0

        // Blur:
        // 0.0 (Entry) -> High Blur
        // 1.0 (Settled) -> No Blur
        final double blur = (1.0 - val) * 12.0;

        // Scale:
        // 0.0 (Entry) -> 1.15 (Expanded/Cloudy)
        // 1.0 (Settled) -> 1.0
        final double scale = 1.0 + ((1.0 - val) * 0.15);

        // Opacity:
        // 0.0 -> 0.0
        // 1.0 -> 1.0
        final double opacity = val.clamp(0.0, 1.0);

        if (val > 0.99) {
          return widget.child;
        }

        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: widget.child,
            ),
          ),
        );
      },
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

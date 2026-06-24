import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MorphingParticleText extends StatefulWidget {
  final String? text;
  final InlineSpan? richText; // Added support for RichText
  final TextStyle? style;
  final Duration duration;
  final bool isDispersed; // True = Dissolved/Particles, False = Formed Text

  const MorphingParticleText({
    super.key,
    this.text,
    this.richText,
    this.style,
    this.duration = const Duration(milliseconds: 800),
    this.isDispersed = false,
  }) : assert(text != null || richText != null, "Provide text or richText");

  @override
  State<MorphingParticleText> createState() => _MorphingParticleTextState();
}

class _MorphingParticleTextState extends State<MorphingParticleText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _progress =
        CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic);

    if (!widget.isDispersed) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(MorphingParticleText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isDispersed != oldWidget.isDispersed) {
      if (widget.isDispersed) {
        _controller.reverse(); // Go back to Dispersed (0.0)
      } else {
        _controller.forward(); // Go to Formed (1.0)
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progress,
      builder: (context, child) {
        final val = _progress.value; // 0.0 (Particles) -> 1.0 (Text)
        final inv = 1.0 - val;

        // 1. Spacing Animation: Condense from wide to normal
        final spacing = 10.0 * inv;

        // 2. Blur Animation: Valid sigma > 0
        final blur = 10.0 * inv;

        // 3. Opacity (Fade in)
        final opacity = (val * 1.5).clamp(0.0, 1.0);

        // 4. "Particle" Jitter (Scale + Offset simulation)
        // We simulate particles by masking with noise-like scale/opacity if possible
        // but robustly: we use blur + spacing + slight scale.

        final scale = 1.2 - (0.2 * val); // 1.2 -> 1.0

        final effectiveStyle = (widget.style ??
                GoogleFonts.outfit(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0, // Base tracking
                ))
            .copyWith(
          letterSpacing: (widget.style?.letterSpacing ?? 1.0) + spacing,
        );

        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur / 2),
              child: widget.richText != null
                  ? Text.rich(
                      widget.richText!,
                      style: effectiveStyle,
                      textAlign: TextAlign.center,
                    )
                  : Text(
                      widget.text!,
                      style: effectiveStyle,
                      textAlign: TextAlign.center,
                    ),
            ),
          ),
        );
      },
    );
  }
}

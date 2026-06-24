import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'animations/particle_text.dart';
import '../widgets/optimized_glass.dart';

class UnifiedTopBar extends StatefulWidget {
  final String title;
  final VoidCallback? onBack;
  final List<Widget>? actions;
  final String? heroTag; // Added Hero support

  const UnifiedTopBar({
    super.key,
    required this.title,
    this.onBack,
    this.actions,
    this.heroTag,
  });

  @override
  State<UnifiedTopBar> createState() => _UnifiedTopBarState();
}

class _UnifiedTopBarState extends State<UnifiedTopBar> {
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    // Trigger entry animation
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _isVisible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPadding = MediaQuery.of(context).padding.top;

    // Helper to wrap in Hero if tag exists
    Widget maybeHero({required Widget child}) {
      if (widget.heroTag != null) {
        return Hero(
          tag: widget.heroTag!,
          child: Material(type: MaterialType.transparency, child: child),
        );
      }
      return child;
    }

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: 80 + topPadding, // Consistent height
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. Frosted Glass Container
          AnimatedPositioned(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutQuart,
            top: topPadding + 10,
            left: _isVisible ? 16 : 32, // Slide/Expand effect
            right: _isVisible ? 16 : 32,
            height: 56,
            child: maybeHero(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 400),
                opacity: _isVisible ? 1.0 : 0.0,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 20,
                        spreadRadius: -2,
                        offset: const Offset(0, 8),
                      )
                    ],
                  ),
                  child: OptimizedGlass(
                    borderRadius: BorderRadius.circular(28),
                    sigmaX: 20,
                    sigmaY: 20,
                    fallbackColor:
                        isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    child: RepaintBoundary(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E1E1E).withValues(alpha: 0.6)
                              : Colors.white.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.2)
                                : Colors.black.withValues(alpha: 0.1),
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Back Button (or spacer)
                            if (widget.onBack != null)
                              IconButton(
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  widget.onBack!();
                                },
                                icon: Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  size: 20,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                                tooltip: 'Back',
                              )
                            else
                              const SizedBox(width: 40),

                            // Actions (or spacer)
                            if (widget.actions != null)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: widget.actions!,
                              )
                            else
                              const SizedBox(width: 40),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 2. Title (Floating on top)
          Positioned(
            top: topPadding + 13, // Vertically centered
            left: 0,
            right: 0,
            height: 50,
            child: IgnorePointer(
              child: Center(
                child: MorphingParticleText(
                  text: widget.title,
                  isDispersed: !_isVisible, // Animate from dispersed state
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

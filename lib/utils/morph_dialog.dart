import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/optimized_glass.dart';

/// Shows a dialog with a morphing particle animation (Scale + Fade + Blur).
///
/// [builder] constructs the content of the dialog.
/// [barrierDismissible] defaults to true.
Future<T?> showMorphDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  Duration transitionDuration = const Duration(milliseconds: 350),
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    // Use transparent barrier because GlassDialogContainer handles the dim/blur
    barrierColor: barrierColor ?? Colors.transparent,
    transitionDuration: transitionDuration,
    pageBuilder: (context, animation, secondaryAnimation) {
      return builder(context);
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      // "Smooth fast iOS style" -> fast start, distinct ease out
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );

      return AnimatedBuilder(
        animation: curvedAnimation,
        builder: (context, child) {
          // Smooth Fade + Slide (Fixes BackdropFilter scaling glitches)
          // Premium Fade + Scale (Subtle Pop) - No Sliding
          return RepaintBoundary(
            child: ScaleTransition(
              scale:
                  Tween<double>(begin: 0.95, end: 1.0).animate(curvedAnimation),
              child: child,
            ),
          );
        },
        child: child,
      );
    },
  );
}

// Deprecated: Internal Frosted Glass logic (can be removed if unused, but keeping for compatibility if any direct usage exists)
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final BoxBorder? border;
  final Color? color;

  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.borderRadius,
    this.border,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    // Legacy support or internal usage?
    // If not used, we can ignore.
    // But let's assume this might be used inside the new dialog as well?
    // No, new dialog uses Opaque Surface.
    final radius = borderRadius ?? BorderRadius.circular(24);

    // Fallback to simple container if used directly
    return Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: (color ?? Theme.of(context).colorScheme.surface)
            .withValues(alpha: 0.2),
        borderRadius: radius,
        border: border ??
            Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .outline
                    .withValues(alpha: 0.1),
                width: 1),
      ),
      child: child,
    );
  }
}

class GlassDialogContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onClose;
  final String? title;
  final List<Widget>? actions;

  const GlassDialogContainer({
    super.key,
    required this.child,
    this.width,
    this.padding = const EdgeInsets.all(24),
    this.onClose,
    this.title,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    // Replicates the "Color Picker" style:
    // 1. Fullscreen Stack
    // 2. Safe-Area only Blur (BackdropFilter)
    // 3. Centered Dialog Box (Surface + Outline + Shadow)

    final screenHeight = MediaQuery.of(context).size.height;

    return Stack(
      alignment: Alignment.center,
      children: [
        // 1. Global Dismiss Layer (Catches taps on transparent zones)
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              if (onClose != null) {
                onClose!();
              } else {
                Navigator.of(context).pop();
              }
            },
            child: Container(color: Colors.transparent),
          ),
        ),

        // 2. Visual Blur Layer (Restricted to Content Area)
        // 2. Visual Blur Layer (Removed as per request for clear background)
        // Dialogs now float on clear background with global dismiss.

        // Dialog Content
        Center(
          child: Container(
            width: width ?? MediaQuery.of(context).size.width * 0.9,
            constraints: BoxConstraints(
              maxWidth: 400,
              maxHeight: screenHeight * 0.85,
            ),

            // Shadow Layer
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
              fallbackColor: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1E1E1E)
                  : Colors.white,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF1E1E1E).withValues(alpha: 0.6)
                      : Colors.white.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: 0.15)
                        : Colors.black.withValues(alpha: 0.08),
                    width: 1.0,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Optional Header
                      if (title != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title!,
                                  style: GoogleFonts.outfit(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Content
                      Flexible(
                        child: Padding(
                          padding: padding,
                          child: child,
                        ),
                      ),

                      // Optional Actions Bar
                      if (actions != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: actions!,
                          ),
                        ),
                    ],
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

/// Shows a premium, glassy SnackBar.
void showMorphSnackBar(
  BuildContext context, {
  required String message,
  bool isError = false,
  IconData? icon,
  Duration duration = const Duration(seconds: 4),
}) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;

  // Clear existing snackbars to prevent stacking weirdly
  ScaffoldMessenger.of(context).clearSnackBars();

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      duration: duration,
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      padding: EdgeInsets.zero,
      content: OptimizedGlass(
        borderRadius: BorderRadius.circular(20),
        sigmaX: 12,
        sigmaY: 12,
        fallbackColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1E1E1E).withValues(alpha: 0.8)
                : Colors.white.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isError
                  ? Colors.red.withValues(alpha: 0.3)
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.05)),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isError
                      ? Colors.red.withValues(alpha: 0.1)
                      : Colors.green.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon ??
                      (isError
                          ? Icons.error_outline_rounded
                          : Icons.check_circle_outline_rounded),
                  color: isError ? Colors.redAccent : Colors.greenAccent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.outfit(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

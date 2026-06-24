import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DurationChip extends StatelessWidget {
  final String label;
  final Duration duration;
  final VoidCallback onTap;
  final bool isSelected;

  const DurationChip({
    super.key,
    required this.label,
    required this.duration,
    required this.onTap,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    // Theme-aware colors
    final primary = Theme.of(context).colorScheme.primary;
    final surfaceContainer =
        Theme.of(context).colorScheme.surfaceContainerHighest;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primary : surfaceContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? primary : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

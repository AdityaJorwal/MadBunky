import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/providers.dart';

class UserCard extends ConsumerWidget {
  const UserCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final madnessScore = ref.watch(madnessScoreProvider);

    // Rank Text Logic
    String rankText = "Rookie";
    Color rankColor = Colors.blueGrey;
    if (madnessScore > 30) {
      rankText = "Skillful";
      rankColor = Colors.blue;
    }
    if (madnessScore > 60) {
      rankText = "Professional";
      rankColor = Colors.purple;
    }
    if (madnessScore > 85) {
      rankText = "Mad Genius";
      rankColor = Colors.deepOrange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Text Info
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.name.isNotEmpty ? profile.name : "Setup Profile",
                  style: GoogleFonts.outfit(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 24, // Increased from 20
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  profile.institute.isNotEmpty
                      ? profile.institute
                      : "Your Institute",
                  style: GoogleFonts.outfit(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 14, // Increased from 13
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: rankColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: rankColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    rankText.toUpperCase(),
                    style: GoogleFonts.outfit(
                      color: rankColor,
                      fontSize: 11, // Increased from 10
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          // 2. Madness Score Indicator
          _MadnessIndicator(score: madnessScore),
        ],
      ),
    );
  }
}

class _MadnessIndicator extends StatelessWidget {
  final double score;
  const _MadnessIndicator({required this.score});

  @override
  Widget build(BuildContext context) {
    // Score is 0-100
    // Color Gradient: Safe (Blue) -> Risky (Purple) -> Mad (Fire/Orange)
    final Color scoreColor = score < 50
        ? Color.lerp(Colors.blue, Colors.purple, score / 50)!
        : Color.lerp(Colors.purple, Colors.deepOrange, (score - 50) / 50)!;

    return SizedBox(
      width: 140, // Increased
      height: 140, // Increased
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background Circle
          SizedBox(
            width: 130, // Increased
            height: 130, // Increased
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: 10, // Increased stroke
              color: Theme.of(context)
                  .colorScheme
                  .outlineVariant
                  .withValues(alpha: 0.1),
              strokeCap: StrokeCap.round,
            ),
          ),
          // Value Circle
          SizedBox(
            width: 130, // Increased
            height: 130, // Increased
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 1500),
              curve: Curves.easeOutExpo,
              tween: Tween<double>(begin: 0, end: score / 100),
              builder: (context, value, _) {
                return CircularProgressIndicator(
                  value: value,
                  strokeWidth: 10, // Increased stroke
                  color: scoreColor,
                  strokeCap: StrokeCap.round,
                );
              },
            ),
          ),
          // Text
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                score == 100.0 ? "100%" : "${score.toStringAsFixed(2)}%",
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 26, // Increased from 22
                  color: scoreColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

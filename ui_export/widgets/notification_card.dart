import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NotificationCard extends StatelessWidget {
  final String subjectName;
  final String time;
  final String? room;
  final String? type;

  const NotificationCard({
    super.key,
    required this.subjectName,
    required this.time,
    this.room,
    this.type,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 400, // Fixed width
      height: 120, // Fixed height for consistency
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.black, // Fallback
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // 1. Abstract Gradient Background (Aurora)
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF2E3192), // Deep Blue
                    Color(0xFF1BFFFF), // Cyan
                  ],
                ),
              ),
            ),
          ),
          // 2. Mesh / Blobs
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF4081).withValues(alpha: 0.6),
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFFFF4081).withValues(alpha: 0.6),
                      blurRadius: 60,
                      spreadRadius: 20),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -30,
            left: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF7C4DFF).withValues(alpha: 0.6),
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFF7C4DFF).withValues(alpha: 0.6),
                      blurRadius: 60,
                      spreadRadius: 20),
                ],
              ),
            ),
          ),
          // 3. Ultra Glass Overlay (Frosted)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3), // Dark Tint
                // Note: ImageFilter.blur doesn't work well in generated images if no background,
                // but here we have a background (gradient).
                // However, capturing `BackdropFilter` sometimes has issues in `toImage`.
                // simpler to just use semi-transparent overlay.
              ),
            ),
          ),

          // 4. Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Icon Box
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3), width: 1),
                  ),
                  child: const Icon(Icons.school_rounded,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                // Text Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        subjectName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded,
                              color: Colors.white70, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            time,
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (room != null) ...[
                            const SizedBox(width: 12),
                            Icon(Icons.location_on_rounded,
                                color: Colors.white70, size: 14),
                            const SizedBox(width: 4),
                            Expanded(
                                child: Text(
                              room!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                              ),
                            )),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Type Badge (Class)
                if (type != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      type!.toUpperCase(),
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

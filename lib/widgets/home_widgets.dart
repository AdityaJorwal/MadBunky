import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';

// Key for the My Day Widget - Deprecated/Unused
// const String _myDayWidgetKey = 'my_day_widget';

class MyDayWidget extends StatelessWidget {
  final List<ClassSession> sessions;
  final DateTime date;

  const MyDayWidget({super.key, required this.sessions, required this.date});

  @override
  Widget build(BuildContext context) {
    // Filter sessions for the given date and sort by time
    final todaysSessions = sessions.where((s) {
      return s.startTime.year == date.year &&
          s.startTime.month == date.month &&
          s.startTime.day == date.day &&
          !s.isCancelled;
    }).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    return Container(
      width: 320, // Standard width for generation
      height: 150, // Standard height
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E), // Dark background for contrast
        borderRadius: BorderRadius.circular(24),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "My Day",
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                DateFormat('EEE, MMM d').format(date),
                style: GoogleFonts.outfit(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: todaysSessions.isEmpty
                ? Center(
                    child: Text(
                      "No classes today! 🎉",
                      style: GoogleFonts.outfit(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 14,
                      ),
                    ),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: todaysSessions.length,
                    separatorBuilder: (ctx, i) => const SizedBox(width: 8),
                    itemBuilder: (ctx, i) {
                      final session = todaysSessions[i];
                      final isPast = session.endTime.isBefore(DateTime.now());
                      final isNow =
                          session.startTime.isBefore(DateTime.now()) &&
                              session.endTime.isAfter(DateTime.now());

                      return Container(
                        width: 100,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isNow
                              ? Colors.blue.withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: isNow
                              ? Border.all(
                                  color: Colors.blue.withValues(alpha: 0.5))
                              : null,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              DateFormat('h:mm a').format(session.startTime),
                              style: GoogleFonts.outfit(
                                color: isPast
                                    ? Colors.white.withValues(alpha: 0.4)
                                    : Colors.white.withValues(alpha: 0.9),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              session.subjectName,
                              style: GoogleFonts.outfit(
                                color: isPast
                                    ? Colors.white.withValues(alpha: 0.5)
                                    : Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// DEPRECATED: Use WidgetService.updateMyDayWidget via Native JSON updates instead.
// Future<void> updateMyDayWidget(List<ClassSession> sessions) async {
//   ...
// }

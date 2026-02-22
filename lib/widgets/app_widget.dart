import 'package:flutter/material.dart';
import '../models/models.dart';

class AppWidget extends StatelessWidget {
  final List<ClassSession> todaysSessions;
  final AttendanceHealth?
      overallHealth; // You might want to calculate an overall health or show key subjects

  const AppWidget({
    super.key,
    required this.todaysSessions,
    this.overallHealth,
  });

  @override
  Widget build(BuildContext context) {
    // Determine status color
    Color statusColor = Colors.green;
    String statusText = "On Track";
    if (overallHealth != null) {
      statusColor = overallHealth!.color;
      statusText = overallHealth!.statusText;
    }

    return Container(
      width: 320, // targeted standard width
      height: 160, // targeted standard height
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E), // Dark background
        borderRadius: BorderRadius.circular(24),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Status
          Row(
            children: [
              Icon(Icons.person, color: statusColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                "My Day",
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Divider
          Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 12),
          // Content: Next Class or Empty State
          Expanded(
            child: todaysSessions.isEmpty
                ? const Center(
                    child: Text(
                      "No classes today! \uD83C\uDF89",
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    itemCount: todaysSessions.length > 2
                        ? 2
                        : todaysSessions.length, // Show top 2
                    itemBuilder: (context, index) {
                      final session = todaysSessions[index];
                      // Simple formatter
                      String formatTime(DateTime dt) {
                        String twoDigits(int n) => n.toString().padLeft(2, '0');
                        int hour = dt.hour > 12 ? dt.hour - 12 : dt.hour;
                        if (hour == 0) hour = 12;
                        String amPm = dt.hour >= 12 ? "PM" : "AM";
                        return "$hour:${twoDigits(dt.minute)} $amPm";
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            Container(
                              width: 4,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Color(session.colorValue),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    session.subjectName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    "${formatTime(session.startTime)} - ${formatTime(session.endTime)}",
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
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

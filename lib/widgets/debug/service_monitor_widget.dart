import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ServiceMonitorWidget extends StatelessWidget {
  final String serviceName;
  final bool isRunning;
  final DateTime? lastActive;
  final String? statusMessage;
  final VoidCallback? onRestart;

  const ServiceMonitorWidget({
    super.key,
    required this.serviceName,
    required this.isRunning,
    this.lastActive,
    this.statusMessage,
    this.onRestart,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusColor = isRunning ? Colors.greenAccent : colorScheme.error;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          // Status Indicator
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: statusColor.withValues(alpha: 0.5),
                  blurRadius: 6,
                  spreadRadius: 2,
                )
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  serviceName.toUpperCase(),
                  style: GoogleFonts.ibmPlexMono(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: colorScheme.onSurface,
                  ),
                ),
                if (statusMessage != null)
                  Text(
                    statusMessage!,
                    style: GoogleFonts.ibmPlexMono(
                      fontSize: 10,
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (lastActive != null)
                  Text(
                    "LAST ACTIVE: ${_formatTime(lastActive!)}",
                    style: GoogleFonts.ibmPlexMono(
                      fontSize: 10,
                      color: colorScheme.primary.withValues(alpha: 0.8),
                    ),
                  ),
              ],
            ),
          ),
          // Action
          if (onRestart != null)
            IconButton(
              icon: const Icon(Icons.refresh, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              color: colorScheme.tertiary,
              onPressed: onRestart,
              tooltip: "Restart Service",
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}";
  }
}

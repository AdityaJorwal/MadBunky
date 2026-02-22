import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LiveLogTerminal extends StatefulWidget {
  final List<String> logs;
  final ScrollController? scrollController;
  final bool autoScroll;

  const LiveLogTerminal({
    super.key,
    required this.logs,
    this.scrollController,
    this.autoScroll = true,
  });

  @override
  State<LiveLogTerminal> createState() => _LiveLogTerminalState();
}

class _LiveLogTerminalState extends State<LiveLogTerminal> {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: widget.scrollController,
      reverse:
          true, // Newest at bottom visually in a terminal mostly means auto-scroll to bottom, but for log lists usually newest at top is easier.
      // Wait, standard terminal: New logs appear at the bottom.
      // Let's stick to the convention used in the previous file: Reverse = true, index 0 is newest.
      physics: const BouncingScrollPhysics(),
      itemCount: widget.logs.length,
      padding: const EdgeInsets.all(4),
      itemBuilder: (ctx, i) {
        final log = widget.logs[i];
        return _buildLogLine(log);
      },
    );
  }

  Widget _buildLogLine(String log) {
    Color logColor = const Color(0xFFC9D1D9); // Default FG
    if (log.toLowerCase().contains('error') || log.contains('exception')) {
      logColor = const Color(0xFFF85149);
    } else if (log.toLowerCase().contains('warning') || log.contains('wrn')) {
      logColor = const Color(0xFFD29922);
    } else if (log.toLowerCase().contains('success') || log.contains('ok')) {
      logColor = const Color(0xFF7EE787);
    } else if (log.contains('CMD >')) {
      logColor = const Color(0xFF58A6FF);
    }

    // Try to split timestamp if present
    // Assuming format "[TE] msg" or similar, maybe clean it up

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: SelectableText.rich(
        TextSpan(
          children: [
            TextSpan(
              text: "> ",
              style: GoogleFonts.firaCode(
                color: const Color(0xFF30363D),
                fontSize: 10,
              ),
            ),
            TextSpan(
              text: log,
              style: GoogleFonts.firaCode(
                color: logColor,
                fontSize: 11,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

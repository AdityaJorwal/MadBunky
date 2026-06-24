import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/log_service.dart';
import '../screens/main_scaffold.dart';

class LogViewerScreen extends StatefulWidget {
  const LogViewerScreen({super.key});

  @override
  State<LogViewerScreen> createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends State<LogViewerScreen> {
  String _logs = "Loading...";

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final logs = await LogService().getLogs();
    if (mounted) {
      setState(() {
        _logs = logs.isEmpty ? "No logs found." : logs;
      });
    }
  }

  Future<void> _clearLogs() async {
    await LogService().clearLogs();
    if (mounted) {
      setState(() {
        _logs = "Logs cleared.";
      });
      MainScaffold.showGlassToast(context, "Logs Cleared");
    }
  }

  Future<void> _shareLogs() async {
    await LogService().shareLogs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          "System Logs",
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLogs,
            tooltip: "Refresh",
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareLogs,
            tooltip: "Share Logs",
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text("Clear Logs?"),
                  content: const Text("This cannot be undone."),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("Cancel"),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _clearLogs();
                      },
                      child: const Text("Clear",
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
            tooltip: "Clear Logs",
          ),
        ],
      ),
      body: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
          ),
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: SelectableText(
            _logs,
            style: GoogleFonts.sourceCodePro(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/providers.dart';

import '../services/mega_schedule_parser.dart'; // For ScheduleExtractionResult
import '../widgets/pdf_confirmation_dialog.dart';
import '../utils/morph_dialog.dart';
import 'package:google_fonts/google_fonts.dart';

class GoogleCalendarImportDialog extends ConsumerStatefulWidget {
  const GoogleCalendarImportDialog({super.key});

  @override
  ConsumerState<GoogleCalendarImportDialog> createState() =>
      _GoogleCalendarImportDialogState();
}

class _GoogleCalendarImportDialogState
    extends ConsumerState<GoogleCalendarImportDialog> {
  bool _isLoading = false;
  DateTime _selectedStartOfWeek = _getStartOfWeek(DateTime.now());

  static DateTime _getStartOfWeek(DateTime date) {
    // Assuming Monday is start
    return date.subtract(Duration(days: date.weekday - 1));
  }

  String get _formattedRange {
    final end = _selectedStartOfWeek.add(const Duration(days: 6));
    final f = DateFormat('MMM d');
    return "${f.format(_selectedStartOfWeek)} - ${f.format(end)}";
  }

  Future<void> _handleConnect() async {
    setState(() => _isLoading = true);
    try {
      final account = await ref.read(googleCalendarServiceProvider).signIn();
      if (account != null && mounted) {
        // Success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error connecting: $e"),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleImport() async {
    setState(() => _isLoading = true);
    try {
      final service = ref.read(googleCalendarServiceProvider);
      // Ensure signed in
      if (!service.isSignedIn) {
        await _handleConnect();
        if (!service.isSignedIn) return; // Still not signed in
      }

      final sessions = await service.fetchEventsForWeek(_selectedStartOfWeek);

      if (!mounted) return;

      if (sessions.isEmpty) {
        // Show toast
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("No events found for this week."),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        return;
      }

      // Capture notifier BEFORE popping to ensure valid ref
      final notifier = ref.read(attendanceProvider.notifier);

      Navigator.pop(context); // Close the import chooser

      // Show Confirmation
      // We wrap the sessions in ScheduleExtractionResult
      final result = ScheduleExtractionResult(
        sessions: sessions,
        instituteName: "Google Calendar",
        dateRange: _formattedRange,
      );

      // Use a new context if possible or ensure this context is valid.
      // Actually passing `notifier` instance is safer.
      if (!mounted) return; // Paranoia check

      showMorphDialog(
        context: context,
        builder: (c) => PdfConfirmationDialog(
          extractedSessions: result.sessions,
          instituteName: result.instituteName,
          dateRange: result.dateRange,
          showSaveOption: false, // Don't save as image/schedule file
          initialDate: _selectedStartOfWeek,
          onConfirm: (confirmedSessions, selectedDate, _) {
            for (var session in confirmedSessions) {
              notifier.addClassSession(session);
            }
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      "Imported ${confirmedSessions.length} classes from Calendar"),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              );
            }
          },
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Import failed: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _shiftWeek(int weeks) {
    setState(() {
      _selectedStartOfWeek =
          _selectedStartOfWeek.add(Duration(days: 7 * weeks));
    });
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(googleCalendarServiceProvider);

    return StreamBuilder(
      stream: service.onCurrentUserChanged,
      initialData: service.currentUser,
      builder: (context, snapshot) {
        final user = snapshot.data;
        final isSignedIn = user != null;

        return GlassDialogContainer(
          title: "Import from Calendar",
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isSignedIn) ...[
                const SizedBox(height: 16),
                const Icon(Icons.calendar_month, size: 48, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  "Connect your Google Account to import your schedule.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _isLoading ? null : _handleConnect,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.login),
                  label: const Text("Sign In with Google"),
                ),
              ] else ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundImage: user.photoUrl != null
                        ? NetworkImage(user.photoUrl!)
                        : null,
                    child:
                        user.photoUrl == null ? const Icon(Icons.person) : null,
                  ),
                  title: Text(user.displayName ?? "User"),
                  subtitle: Text(user.email),
                  trailing: IconButton(
                    icon: const Icon(Icons.logout),
                    onPressed: () async {
                      await service.signOut();
                      setState(() {});
                    },
                  ),
                ),
                const Divider(),
                const SizedBox(height: 16),
                Text(
                  "Select Week",
                  style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),

                // 3-Button Section
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      _WeekButton(
                        icon: Icons.chevron_left,
                        label: "Prev",
                        onTap: () => _shiftWeek(-1),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            // Reset to current
                            setState(() {
                              _selectedStartOfWeek =
                                  _getStartOfWeek(DateTime.now());
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  "Current",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  _formattedRange,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimaryContainer,
                                      fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      _WeekButton(
                        icon: Icons.chevron_right,
                        label: "Next",
                        onTap: () => _shiftWeek(1),
                        isRight: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _handleImport,
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : const Text("Import Events"),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _WeekButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isRight;

  const _WeekButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isRight =
        false, // Unused parameter but keeping for API consistency if needed
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Icon(icon, size: 20),
            Text(label, style: const TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

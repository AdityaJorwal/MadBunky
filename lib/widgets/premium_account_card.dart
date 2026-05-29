import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../providers/providers.dart';
import '../utils/morph_dialog.dart';
import '../models/models.dart';
import '../widgets/google_calendar_import_dialog.dart';
import '../widgets/pdf_confirmation_dialog.dart';

class PremiumAccountCard extends ConsumerStatefulWidget {
  const PremiumAccountCard({super.key});

  @override
  ConsumerState<PremiumAccountCard> createState() => _PremiumAccountCardState();
}

class _PremiumAccountCardState extends ConsumerState<PremiumAccountCard> {
  bool _isBackingUp = false;
  bool _isRestoring = false;
  bool _isSyncing = false;

  String _formatDate(String? iso) {
    if (iso == null) return "Never";
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat.yMMMd().add_jm().format(dt);
    } catch (_) {
      return "Unknown";
    }
  }

  Future<void> _handleBackup() async {
    setState(() => _isBackingUp = true);
    try {
      await ref.read(backupServiceProvider).createBackup();
      await ref
          .read(sharedPreferencesProvider)
          .setString('lastBackupTime', DateTime.now().toIso8601String());
      if (mounted) {
        showMorphSnackBar(
          context,
          message: "Backup Successful!",
        );
      }
    } catch (e) {
      if (mounted) {
        showMorphSnackBar(
          context,
          message: "Backup Failed: $e",
          isError: true,
        );
      }
    } finally {
      setState(() => _isBackingUp = false);
    }
  }

  Future<void> _handleRestore() async {
    showMorphDialog(
      context: context,
      builder: (ctx) => GlassDialogContainer(
        title: "Restore Backup?",
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              _performRestore();
            },
            child: const Text("Restore"),
          ),
        ],
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            "This will overwrite your current app data with the latest backup. This action cannot be undone.",
          ),
        ),
      ),
    );
  }

  Future<void> _performRestore() async {
    setState(() => _isRestoring = true);
    try {
      final drive = ref.read(googleDriveServiceProvider);
      final files = await drive.listBackups();
      if (files.isEmpty) throw Exception("No backups found.");

      final fileId = files.first.id;
      if (fileId == null) throw Exception("Invalid backup file.");

      await ref.read(backupServiceProvider).restoreBackup(fileId);
      await ref.read(attendanceProvider.notifier).reload();

      if (mounted) {
        showMorphSnackBar(
          context,
          message: "Restore Complete! Please restart to apply all settings.",
          icon: Icons.restart_alt_rounded,
        );
      }
    } catch (e) {
      if (mounted) {
        showMorphSnackBar(
          context,
          message: "Restore Failed: $e",
          isError: true,
        );
      }
    } finally {
      setState(() => _isRestoring = false);
    }
  }

  Future<void> _syncCalendarNow() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    try {
      final service = ref.read(googleCalendarServiceProvider);
      final account = service.currentUser;
      if (account == null) {
        showMorphSnackBar(context,
            message: "Please sign in to sync schedule", isError: true);
        return;
      }

      final now = DateTime.now();
      // Start of CURRENT week (Monday)
      final currentWeekStart = now.subtract(Duration(days: now.weekday - 1));
      final currentWeekStartDate = DateTime(
          currentWeekStart.year, currentWeekStart.month, currentWeekStart.day);
      // Start of NEXT week
      final nextWeekStart = currentWeekStartDate.add(const Duration(days: 7));

      // Fetch both weeks
      final currentSessions =
          await service.fetchEventsForWeek(currentWeekStartDate);
      final nextSessions = await service.fetchEventsForWeek(nextWeekStart);
      final allSessions = [...currentSessions, ...nextSessions];

      if (allSessions.isNotEmpty && mounted) {
        final notifier = ref.read(attendanceProvider.notifier);
        for (var session in allSessions) {
          notifier.addClassSession(session);
        }
        showMorphSnackBar(context,
            message:
                "Auto-synced ${allSessions.length} classes (this week + next week)");
      } else if (mounted) {
        showMorphSnackBar(context,
            message: "No events found for this week or next week.");
      }
    } catch (e) {
      if (mounted) {
        showMorphSnackBar(context, message: "Sync Failed: $e", isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  void _handleToggleScheduleSync(bool value) async {
    final notifier = ref.read(settingsProvider.notifier);
    await notifier.toggleAutoSyncGoogleCalendar(value);
    if (value && mounted) {
      _syncCalendarNow();
    }
  }

  @override
  Widget build(BuildContext context) {
    final googleAccountAsync = ref.watch(userGoogleAccountProvider);
// Removed authUser variable
    final isGuest = ref.watch(isGuestProvider);
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

// ... keeping rest same until the widget building part, but replaced target block carefully

    // Auth State
    final googleUser = googleAccountAsync.value;

    final String displayName =
        isGuest ? "Guest User" : (googleUser?.displayName ?? "User");
    final String email = isGuest
        ? "Sign in to sync & backup"
        : (googleUser?.email ?? "No Email");
    final String? photoUrl = isGuest ? null : googleUser?.photoUrl;

    // Backup State
    final prefs = ref.watch(sharedPreferencesProvider);
    final lastBackup = prefs.getString('lastBackupTime');

    // Dynamic Colors to support Light and Dark
    final Color cardBackground =
        isDark ? const Color(0xFF1E1E1E) : theme.colorScheme.primaryContainer;
    final Color textColor =
        isDark ? Colors.white : theme.colorScheme.onPrimaryContainer;
    final Color mutedTextColor = isDark
        ? Colors.white54
        : theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.6);
    final Color dividerColor = isDark
        ? Colors.white10
        : theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.1);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          if (isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          else
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. HEADER: Profile Row
          Row(
            children: [
              // Big Profile Pic
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark
                        ? theme.colorScheme.primary.withValues(alpha: 0.5)
                        : theme.colorScheme.primary,
                    width: isDark ? 2 : 1.5,
                  ),
                ),
                child: ClipOval(
                  child: photoUrl != null
                      ? Image.network(
                          photoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _buildPlaceholder(theme, displayName),
                        )
                      : _buildPlaceholder(theme, displayName),
                ),
              ),
              const SizedBox(width: 20),
              // Name & Email
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: GoogleFonts.outfit(
                        fontSize: 22, // Big Bold Name
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: mutedTextColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          if (!isGuest && googleUser != null) ...[
            // 2. CONTROLS: Auto Sync & Backup
            // Sleek Row for Toggles
            Row(
              children: [
                Expanded(
                  child: _buildToggleItem(
                    context,
                    label: "Schedule Sync",
                    subLabel: "Auto-import this & next week",
                    value: settings.autoSyncGoogleCalendar,
                    onChanged: _handleToggleScheduleSync,
                    icon: Icons.calendar_month,
                    isDark: isDark,
                    textColor: textColor,
                    mutedTextColor: mutedTextColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildToggleItem(
                    context,
                    label: "Cloud Backup",
                    subLabel: "Auto-save changes",
                    value: settings.enableAutoBackup,
                    onChanged: (v) => notifier.toggleAutoBackup(v),
                    icon: Icons.cloud_upload,
                    isDark: isDark,
                    textColor: textColor,
                    mutedTextColor: mutedTextColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 3. ACTION BUTTONS: Import / Backup / Restore
            // Import (Outline)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  HapticFeedback.mediumImpact();
                  final ctx = context;
                  final result = await showMorphDialog(
                    context: ctx,
                    builder: (context) => const GoogleCalendarImportDialog(),
                  );

                  if (!mounted) return;
                  if (result != null && result is Map) {
                    final sessions = result['sessions'] as List<ClassSession>;
                    final range = result['range'] as String;
                    final startOfWeek = result['startOfWeek'] as DateTime;

                    showMorphDialog(
                      context: ctx, // ignore: use_build_context_synchronously
                      builder: (c) => PdfConfirmationDialog(
                        extractedSessions: sessions,
                        instituteName: "Google Calendar",
                        dateRange: range,
                        showSaveOption: false,
                        initialDate: startOfWeek,
                        onConfirm: (confirmedSessions, selectedDate, _) {
                          final notifier = ref.read(attendanceProvider.notifier);
                          for (var session in confirmedSessions) {
                            notifier.addClassSession(session);
                          }
                          if (mounted) {
                            showMorphSnackBar(
                              ctx,
                              message:
                                  "Imported ${confirmedSessions.length} classes from Calendar",
                            );
                          }
                        },
                      ),
                    );
                  }
                },
                icon: Icon(_isSyncing ? Icons.refresh : Icons.download_rounded,
                    size: 20),
                label: Text(_isSyncing ? "Syncing..." : "Import Schedule"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: textColor,
                  side: BorderSide(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.2)
                          : theme.colorScheme.primary.withValues(alpha: 0.3)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Backup Actions Row
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _isBackingUp ? null : _handleBackup,
                    icon: _isBackingUp
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.upload_file, size: 18),
                    label: Text(_isBackingUp ? "Backing up" : "Backup"),
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.primaryContainer
                          .withValues(alpha: isDark ? 0.5 : 1.0),
                      foregroundColor: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _isRestoring ? null : _handleRestore,
                    icon: _isRestoring
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.history, size: 18),
                    label: Text(_isRestoring ? "Restoring" : "Restore"),
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.surfaceContainerHigh,
                      foregroundColor: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),
            Center(
              child: Text(
                "Last Backup: ${_formatDate(lastBackup)}",
                style: TextStyle(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.3)
                        : theme.colorScheme.onPrimaryContainer
                            .withValues(alpha: 0.5),
                    fontSize: 11),
              ),
            ),
          ] else ...[
            // GUEST STATE
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? theme.colorScheme.surface.withValues(alpha: 0.1)
                    : theme.colorScheme.surface.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.cloud_off, color: mutedTextColor),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text(
                    "Sign in to enable Cloud Backup & Sync",
                    style: TextStyle(color: mutedTextColor),
                  )),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  await ref.read(authServiceProvider).signInWithGoogle();
                  ref.read(isGuestProvider.notifier).setGuestMode(false);
                },
                icon: const Icon(Icons.login),
                label: const Text("Sign In with Google"),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],

          if (!isGuest && googleUser != null) ...[
            const SizedBox(height: 20),
            Divider(color: dividerColor),
            const SizedBox(height: 8),
            // Log Out text button
            Center(
              child: TextButton(
                onPressed: () {
                  showMorphDialog(
                    context: context,
                    builder: (ctx) => GlassDialogContainer(
                      title: "Log Out?",
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text("Cancel")),
                        FilledButton(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await ref.read(authServiceProvider).signOut();
                          },
                          style: FilledButton.styleFrom(
                              backgroundColor: theme.colorScheme.error),
                          child: const Text("Log Out"),
                        ),
                      ],
                      child: const SizedBox.shrink(),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error),
                child: const Text("Log Out"),
              ),
            )
          ]
        ],
      ),
    );
  }

  Widget _buildToggleItem(
    BuildContext context, {
    required String label,
    required String subLabel,
    required bool value,
    required Function(bool) onChanged,
    required IconData icon,
    required bool isDark,
    required Color textColor,
    required Color mutedTextColor,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onChanged(!value);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: value
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)
                  : Colors.transparent),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon,
                    size: 20,
                    color: value
                        ? Theme.of(context).colorScheme.primary
                        : mutedTextColor),
                SizedBox(
                  height: 24,
                  width: 36,
                  child: Switch.adaptive(
                    value: value,
                    onChanged: (v) {
                      HapticFeedback.lightImpact();
                      onChanged(v);
                    },
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(label,
                style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    fontSize: 13)),
            Text(subLabel,
                style: GoogleFonts.outfit(color: mutedTextColor, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(ThemeData theme, String name) {
    return Container(
      color: theme.colorScheme.surfaceContainerHigh,
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : "U",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

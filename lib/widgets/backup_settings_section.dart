import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../providers/providers.dart';
// Added
import '../utils/morph_dialog.dart';

class BackupSettingsSection extends ConsumerStatefulWidget {
  const BackupSettingsSection({super.key});

  @override
  ConsumerState<BackupSettingsSection> createState() =>
      _BackupSettingsSectionState();
}

class _BackupSettingsSectionState extends ConsumerState<BackupSettingsSection> {
  bool _isBackingUp = false;
  bool _isRestoring = false;

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Backup Successful!"),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Backup Failed: $e"),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isBackingUp = false);
    }
  }

  Future<void> _handleRestore() async {
    // Show confirmation
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
            "This will overwrite your current app data with the latest backup from Google Drive. This action cannot be undone.",
          ),
        ),
      ),
    );
  }

  Future<void> _performRestore() async {
    setState(() => _isRestoring = true);
    try {
      // 1. List files to find ID
      final drive = ref.read(googleDriveServiceProvider);
      final files = await drive.listBackups();
      if (files.isEmpty) {
        throw Exception("No backups found.");
      }
      // Pick first (or sort by date if not done in service)
      // Service listBackups returns them. We assume they are just files.
      // We'll pick the one matching our filename if possible, or just the first JSON.
      // In BackupService we cleaned old ones. So taking first is fine.
      final fileId = files.first.id;
      if (fileId == null) throw Exception("Invalid backup file.");

      await ref.read(backupServiceProvider).restoreBackup(fileId);

      // Reload App State
      // We need to trigger reload on Notifiers.
      // AttendanceNotifier has reload(). SettingsNotifier loads in constructor.
      // We can create a method to force reload or just restart the app UI?
      // AttendanceNotifier.reload() is public.
      await ref.read(attendanceProvider.notifier).reload();
      // SettingsNotifier doesn't have public reload?
      // Actually SettingsNotifier._loadSettings is private.
      // But we wrote to Prefs. Next app restart will pick it up.
      // To reflect immediately, we might need hot restart or manual reload method.
      // For now, prompt user to restart or try to update state if possible.

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Restore Complete! Please restart the app."),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Restore Failed: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isRestoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final prefs = ref.watch(sharedPreferencesProvider);
    final lastBackup = prefs.getString('lastBackupTime');

    // Check if user is signed in
    final googleUser = ref.watch(userGoogleAccountProvider).asData?.value;
    final isSignedIn = googleUser != null;

    return Column(
      children: [
        Center(child: _SectionHeader(title: "Backup & Sync")),
        Container(
          margin: const EdgeInsets.only(top: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              // 1. Google Account Connection
              Row(
                children: [
                  Icon(Icons.cloud_sync_outlined,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Google Drive Backup",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          isSignedIn
                              ? "Connected as ${googleUser.email}"
                              : "Connect to save data",
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  isSignedIn
                      ? IconButton(
                          icon: const Icon(Icons.logout, color: Colors.red),
                          onPressed: () async {
                            // "Disconnect" - technically sign out?
                            // Or just un-link?
                            // Per prompt guidelines, user can disconnect account anytime.
                            // If we sign out, we sign out of AuthService.
                            // Let's ask confirmation.
                            showMorphDialog(
                              context: context,
                              builder: (ctx) => GlassDialogContainer(
                                title: "Disconnect Cloud?",
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text("Cancel")),
                                  FilledButton(
                                      onPressed: () async {
                                        Navigator.pop(ctx);
                                        await ref
                                            .read(authServiceProvider)
                                            .signOut();
                                      },
                                      child: const Text("Disconnect")),
                                ],
                                child: const Text(
                                    "This will sign you out and stop backups."),
                              ),
                            );
                          },
                        )
                      : FilledButton.tonal(
                          onPressed: () async {
                            await ref
                                .read(authServiceProvider)
                                .signInWithGoogle();
                          },
                          child: const Text("Connect"),
                        ),
                ],
              ),

              if (isSignedIn) ...[
                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 8),

                // 2. Auto-Backup Toggle
                Row(
                  children: [
                    const Icon(Icons.autorenew),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Auto-Backup",
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            "Backup automatically on changes",
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: settings.enableAutoBackup,
                      onChanged: (val) {
                        notifier.toggleAutoBackup(val);
                      },
                    ),
                  ],
                ),
                // Fix for Auto-Backup Switch Value:
                // Since I haven't updated AppSettings model yet, I'll use:
                // value: ref.watch(sharedPreferencesProvider).getBool('enableAutoBackup') ?? false,
                // BUT ref.watch(sharedPreferencesProvider) just returns the instance, it doesn't rebuild on key change unless we use a specific provider for that key.
                // I'll stick to a FutureBuilder or just local state initialized in initState?

                const SizedBox(height: 16),

                // 3. Backup Actions
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Last: ${_formatDate(lastBackup)}",
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _isBackingUp ? null : _handleBackup,
                      icon: _isBackingUp
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.upload),
                      label:
                          Text(_isBackingUp ? "Backing up..." : "Backup Now"),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isRestoring ? null : _handleRestore,
                    icon: _isRestoring
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.download),
                    label: Text(_isRestoring ? "Restoring..." : "Restore Data"),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.outfit(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

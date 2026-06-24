import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/providers.dart';
import '../services/gemini_service.dart';
import '../models/models.dart';
import 'main_scaffold.dart';
import 'holiday_screen.dart';
import 'privacy_policy_screen.dart';
import 'feature_list_screen.dart';
import 'debug_tools_screen.dart';
import 'geofence_picker_screen.dart';

import 'package:mad_bunky/widgets/premium_account_card.dart'; // Using package import as requested
// Alternatively use '../widgets/premium_account_card.dart'; if package name fails.
// Given the other imports like 'package:mad_bunky/providers/providers.dart' seen in login_screen.dart,
// wait login_screen used 'package:mad_bunky/providers/providers.dart'.
// But here in settings_screen line 9 is '../providers/providers.dart'.
// I will stick to relative for safety or match the pattern.
// Let's use relative for premium account to be safe:

import '../widgets/morphing_widget.dart';
import '../utils/morph_dialog.dart';

import '../services/log_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Widget _buildThemeModeOption(
      BuildContext context,
      String label,
      ThemeType mode,
      ThemeType currentMode,
      IconData icon,
      VoidCallback onTap) {
    final isSelected = currentMode == mode;
    final theme = Theme.of(context);

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primaryContainer
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline.withValues(alpha: 0.1),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.outfit(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeModeRow(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Row(
      children: [
        _buildThemeModeOption(
          context,
          "Auto",
          ThemeType.system,
          settings.themeMode,
          Icons.brightness_auto,
          () => notifier.updateThemeMode(ThemeType.system),
        ),
        _buildThemeModeOption(
          context,
          "Light",
          ThemeType.light,
          settings.themeMode,
          Icons.light_mode,
          () => notifier.updateThemeMode(ThemeType.light),
        ),
        _buildThemeModeOption(
          context,
          "Dark",
          ThemeType.dark,
          settings.themeMode,
          Icons.dark_mode,
          () => notifier.updateThemeMode(ThemeType.dark),
        ),
      ],
    );
  }

  void _handleBackgroundServiceToggle(
      bool value, WidgetRef ref, BuildContext context) {
    if (!value) {
      // User is trying to disable
      showMorphDialog(
        context: context,
        builder: (ctx) => GlassDialogContainer(
          title: "Stop Background Service?",
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error),
              onPressed: () {
                Navigator.pop(ctx);
                // Disable All
                final notifier = ref.read(settingsProvider.notifier);
                notifier.toggleGeofence(false);
                notifier.toggleWifiTrigger(false);
                // Sync Service toggle removed

                // UI will automatically hide the toggle since condition becomes false
                MainScaffold.showGlassToast(
                    context, "Background Service Stopped");
              },
              child: const Text("Turn Off"),
            ),
          ],
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              "This will disable Geofence, WiFi Triggers, and Auto-Sync. You will need to re-enable them individually to restart the service.",
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: ListView(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top +
              100, // Increased to avoid Header overlap
          left: 16,
          right: 16,
        ),
        children: [
          Center(child: _SectionHeader(title: "Account & Sync")),
          const SizedBox(height: 16),
          const PremiumAccountCard(),
          const SizedBox(height: 24),
          const SizedBox(height: 24),
          Center(child: _SectionHeader(title: "Essentials")),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                _buildThemeModeRow(context, ref),
                const SizedBox(height: 24),
                const Divider(height: 1),
                const SizedBox(height: 16),

                // Calendar Toggle
                Row(
                  children: [
                    const Icon(Icons.calendar_month_outlined),
                    const SizedBox(width: 16),
                    const Text(
                      "Show Calendar",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Switch.adaptive(
                      value: settings.showCalendar,
                      onChanged: (val) {
                        HapticFeedback.mediumImpact();
                        notifier.toggleCalendar(val);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 8),

                // Notifications Toggle
                Row(
                  children: [
                    const Icon(Icons.notifications_outlined),
                    const SizedBox(width: 16),
                    const Text(
                      "Notifications",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Switch.adaptive(
                      value: settings.enableNotifications,
                      onChanged: (val) {
                        HapticFeedback.mediumImpact();
                        notifier.toggleNotifications(val);
                      },
                    ),
                  ],
                ),

                // Live Activity & Silent Delivery Details (Animated)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  reverseDuration: const Duration(milliseconds: 250),
                  switchInCurve: Curves.easeOutQuart,
                  switchOutCurve: Curves.easeInQuart,
                  transitionBuilder: (child, animation) {
                    return MorphItemTransition(
                      animation: animation,
                      child: child,
                    );
                  },
                  layoutBuilder: (formattedChild, formattedPreviousChildren) {
                    return Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        ...formattedPreviousChildren,
                        if (formattedChild != null) formattedChild,
                      ],
                    );
                  },
                  child: settings.enableNotifications
                      ? Column(
                          key: const ValueKey("LiveActivitySection"),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.only(left: 40),
                              child: Column(
                                children: [
                                  // 1. Live Activity
                                  Row(
                                    children: [
                                      Icon(Icons.timer_outlined,
                                          size: 20,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              "Live Activity",
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              "Persistent status during class",
                                              style: TextStyle(
                                                fontSize: 11,
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
                                        value: settings.enableLiveActivity,
                                        onChanged: (val) {
                                          HapticFeedback.mediumImpact();
                                          notifier.toggleLiveActivity(val);
                                        },
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 12),
                                  // 3. Silent Delivery
                                  Row(
                                    children: [
                                      Icon(Icons.notifications_off_outlined,
                                          size: 20,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              "Silent Delivery",
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              "Deliver without sound/vibration",
                                              style: TextStyle(
                                                fontSize: 11,
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
                                        value:
                                            settings.enableSilentNotifications,
                                        onChanged: (val) {
                                          HapticFeedback.mediumImpact();
                                          notifier
                                              .toggleSilentNotifications(val);
                                        },
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 12),
                                ],
                              ),
                            ),
                          ],
                        )
                      : Container(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Center(child: _SectionHeader(title: "Automation & Intelligence")),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                // Master Background Service Toggle
                if (settings.enableGeofence || settings.enableWifiTrigger)
                  Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.bolt_outlined,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Background Service",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                Text(
                                  "Running active monitoring",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value: true, // Only visible if ON
                            onChanged: (val) {
                              HapticFeedback.mediumImpact();
                              _handleBackgroundServiceToggle(val, ref, context);
                            },
                            activeTrackColor:
                                Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                    ],
                  ),

                // Battery Saver Mode (Always Visible)
                Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.battery_saver_outlined,
                            color: settings.enableBatterySaver
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Battery Saver Mode",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                settings.enableBatterySaver
                                    ? "Reduced UI Blur • Low GPS Accuracy"
                                    : "Standard UI & Location Accuracy",
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
                          value: settings.enableBatterySaver,
                          onChanged: (val) async {
                            HapticFeedback.mediumImpact();
                            await notifier.toggleBatterySaver(val);
                            if (context.mounted) {
                              MainScaffold.showGlassToast(
                                  context,
                                  val
                                      ? "Battery Saver Enabled"
                                      : "Battery Saver Disabled");
                            }
                          },
                        ),
                      ],
                    ),
                    // Info Subtext
                    if (settings.enableBatterySaver)
                      Padding(
                        padding:
                            const EdgeInsets.only(left: 40, top: 4, bottom: 4),
                        child: Text(
                          "Reduces battery usage by removing blur effects and minimizing background location checks.",
                          style: TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                  ],
                ),

                // Smart Bunking
                Row(
                  children: [
                    const Icon(Icons.calculate_outlined),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Smart Bunking",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "Show 'Safe Bunks' & 'Must Attend'",
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
                      value: settings.enableSmartBunking,
                      onChanged: (val) {
                        HapticFeedback.mediumImpact();
                        notifier.toggleSmartBunking(val);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 8),
                // Geofence
                Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Geofence Mode",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                "Mark when in college",
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
                          value: settings.enableGeofence,
                          onChanged: (val) {
                            HapticFeedback.mediumImpact();
                            _handleGeofenceToggle(val, ref, context);
                          },
                        ),
                      ],
                    ),
                    // List Locations
                    if (settings.enableGeofence)
                      Padding(
                        padding:
                            const EdgeInsets.only(left: 40, top: 12, bottom: 8),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surface
                                .withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outline
                                  .withValues(alpha: 0.08),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (settings.campusLocations.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Text(
                                    "No locations configured.",
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant
                                          .withValues(alpha: 0.6),
                                    ),
                                  ),
                                ),
                              ...settings.campusLocations.map((loc) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest
                                          .withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .outline
                                            .withValues(alpha: 0.05),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: InkWell(
                                            onTap: () => _editGeofenceLocation(
                                                context, ref, loc),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  loc.name,
                                                  style: GoogleFonts.outfit(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurface,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  "${loc.lat.toStringAsFixed(4)}, ${loc.lng.toStringAsFixed(4)} (${loc.radius.round()}m)",
                                                  style:
                                                      GoogleFonts.sourceCodePro(
                                                    fontSize: 11,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            loc.subjectIds.isEmpty
                                                ? Icons.link
                                                : Icons.link_off,
                                            size: 18,
                                            color: loc.subjectIds.isNotEmpty
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                : Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                          ),
                                          tooltip: "Link Subjects",
                                          onPressed: () {
                                            HapticFeedback.lightImpact();
                                            _linkSubjects(context, ref, loc);
                                          },
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.edit,
                                              size: 18,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant),
                                          tooltip: "Edit Location",
                                          onPressed: () {
                                            HapticFeedback.lightImpact();
                                            _editGeofenceLocation(
                                                context, ref, loc);
                                          },
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.delete_outline,
                                              size: 18,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .error),
                                          tooltip: "Delete Location",
                                          onPressed: () =>
                                              _deleteGeofenceLocation(
                                                  context, ref, loc.id),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withValues(alpha: 0.1),
                                    foregroundColor:
                                        Theme.of(context).colorScheme.primary,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: () =>
                                      _addGeofenceLocation(context, ref),
                                  icon: const Icon(Icons.add_location_alt,
                                      size: 16),
                                  label: Text(
                                    "Add Location",
                                    style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 8),
                // Wifi Trigger
                Row(
                  children: [
                    const Icon(Icons.wifi_outlined),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "WiFi Trigger",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "Mark when connected to Campus WiFi",
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
                      value: settings.enableWifiTrigger,
                      onChanged: (val) {
                        HapticFeedback.mediumImpact();
                        _handleWifiToggle(val, ref, context);
                      },
                    ),
                  ],
                ),
                if (settings.enableWifiTrigger)
                  Padding(
                    padding:
                        const EdgeInsets.only(left: 40, top: 12, bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surface
                            .withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .outline
                              .withValues(alpha: 0.08),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (settings.campusSsids.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Text(
                                "No WiFi networks added yet.",
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                          ...settings.campusSsids.map((ssid) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest
                                      .withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outline
                                        .withValues(alpha: 0.05),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.wifi,
                                        size: 16,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        ssid,
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.delete_outline,
                                          size: 18,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .error),
                                      onPressed: () =>
                                          _deleteWifi(context, ref, ssid),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.1),
                                foregroundColor:
                                    Theme.of(context).colorScheme.primary,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () => _addCurrentWifi(context, ref),
                              icon: const Icon(Icons.add, size: 16),
                              label: Text(
                                "Add Current WiFi",
                                style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 8),
                // Holiday Awareness
                Row(
                  children: [
                    const Icon(Icons.celebration_outlined),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Holiday Awareness",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "Skip reminders on holidays",
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
                      value: settings.enableHolidayAwareness,
                      onChanged: (val) {
                        HapticFeedback.mediumImpact();
                        notifier.toggleHolidayAwareness(val);
                      },
                    ),
                  ],
                ),
                if (settings.enableHolidayAwareness)
                  Padding(
                    padding:
                        const EdgeInsets.only(left: 40, top: 12, bottom: 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.1),
                          foregroundColor:
                              Theme.of(context).colorScheme.primary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const HolidayScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.edit_calendar, size: 16),
                        label: Text(
                          "Manage Holidays",
                          style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Center(child: _SectionHeader(title: "AI Settings")),
          const SizedBox(height: 16),
          const _GeminiSettingsCard(),
          const SizedBox(height: 24),
          Center(child: _SectionHeader(title: "Backup & Restore")),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // BACKUP COLUMN
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      Text("Backup",
                          style: GoogleFonts.outfit(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      // Create Point
                      _BackupActionButton(
                        icon: Icons.save_outlined,
                        label: "Create Point",
                        color: Theme.of(context).colorScheme.primary,
                        onTap: () async {
                          HapticFeedback.mediumImpact();
                          await ref
                              .read(attendanceProvider.notifier)
                              .createBackup();
                          if (context.mounted) {
                            MainScaffold.showGlassToast(
                                context, "Backup Created Successfully!");
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      // Export File
                      _BackupActionButton(
                        icon: Icons.upload_file,
                        label: "Export File",
                        color: Theme.of(context).colorScheme.tertiary,
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          showMorphDialog(
                            context: context,
                            builder: (context) => GlassDialogContainer(
                              title: "Export Backup",
                              actions: [
                                // Show QR removed from here

                                TextButton.icon(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    ref
                                        .read(attendanceProvider.notifier)
                                        .shareBackup();
                                  },
                                  icon: const Icon(Icons.share),
                                  label: const Text("Share"),
                                ),
                                FilledButton.icon(
                                  onPressed: () async {
                                    Navigator.pop(context);
                                    final path = await ref
                                        .read(attendanceProvider.notifier)
                                        .saveBackupToStorage();
                                    if (context.mounted) {
                                      if (path != null) {
                                        MainScaffold.showGlassToast(
                                            context, "Saved to: $path");
                                      } else {
                                        MainScaffold.showGlassToast(
                                            context, "Save Failed");
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.save_alt),
                                  label: const Text("Save to Storage"),
                                ),
                              ],
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.0),
                                child: Text(
                                  "Choose how you want to export your backup file.",
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // RESTORE COLUMN

              // RESTORE COLUMN
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      Text("Restore",
                          style: GoogleFonts.outfit(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      // Restore Point
                      _BackupActionButton(
                        icon: Icons.restore,
                        label: "Restore Point",
                        color: Theme.of(context).colorScheme.secondary,
                        onTap: () async {
                          HapticFeedback.mediumImpact();
                          final success = await ref
                              .read(attendanceProvider.notifier)
                              .restoreBackup();
                          if (context.mounted) {
                            if (success) {
                              MainScaffold.showGlassToast(
                                  context, "Backup Restored!");
                            } else {
                              MainScaffold.showGlassToast(
                                  context, "No Backup Found",
                                  isError: true);
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      // Scan Timetable
                      // Import File
                      _BackupActionButton(
                        icon: Icons.file_download,
                        label: "Import File",
                        color: Theme.of(context).colorScheme.primary,
                        onTap: () async {
                          HapticFeedback.mediumImpact();
                          final success = await ref
                              .read(attendanceProvider.notifier)
                              .importBackupFromFile();
                          if (context.mounted) {
                            if (success) {
                              MainScaffold.showGlassToast(
                                  context, "Backup Imported Successfully!");
                            } else {
                              MainScaffold.showGlassToast(
                                  context, "Import Failed or Cancelled",
                                  isError: true);
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      // Import File
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Center(child: _SectionHeader(title: "Account & Customization")),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                ListTile(
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  leading: const Icon(Icons.person_outline),
                  title: const Text("Edit User Card"),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    _showEditUserCardDialog(context, ref);
                  },
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                  ),
                  leading: const Icon(Icons.undo),
                  title: const Text("Undo Last Action"),
                  onTap: () async {
                    HapticFeedback.mediumImpact();
                    await ref
                        .read(attendanceProvider.notifier)
                        .undoGlobalChange();
                    if (context.mounted) {
                      MainScaffold.showGlassToast(context, "Action Undone");
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Center(child: _SectionHeader(title: "Support & Information")),
          const SizedBox(height: 8),
          Consumer(
            builder: (context, ref, _) {
              final isDebug = ref.watch(debugModeProvider);
              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    ListTile(
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(24),
                          topRight: Radius.circular(24),
                        ),
                      ),
                      leading: const Icon(Icons.info_outline),
                      title: const Text("About"),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        _showAboutDialog(context);
                      },
                    ),
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                      leading: const Icon(Icons.email_outlined),
                      title: const Text("Contact Support"),
                      subtitle: const Text("support@madbunky.dpdns.org"),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () async {
                        HapticFeedback.mediumImpact();
                        final Uri emailLaunchUri = Uri(
                          scheme: 'mailto',
                          path: 'support@madbunky.dpdns.org',
                          queryParameters: {
                            'subject': 'MadBunky Support Query',
                          },
                        );
                        try {
                          await launchUrl(emailLaunchUri);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Could not open email client"),
                              ),
                            );
                          }
                        }
                      },
                    ),
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(isDebug ? 0 : 24),
                          bottomRight: Radius.circular(isDebug ? 0 : 24),
                        ),
                      ),
                      leading: const Icon(Icons.bug_report_outlined),
                      title: const Text("Share Bug Report / Logs"),
                      subtitle:
                          const Text("Help us fix issues by sharing app logs"),
                      trailing: const Icon(Icons.share, size: 16),
                      onTap: () async {
                        HapticFeedback.mediumImpact();
                        await LogService().shareLogs();
                      },
                    ),
                    if (isDebug) ...[
                      const Divider(height: 1, indent: 56),
                      ListTile(
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(24),
                            bottomRight: Radius.circular(24),
                          ),
                        ),
                        leading: Icon(Icons.developer_board,
                            color: Theme.of(context).colorScheme.tertiary),
                        title: Text(
                          "Open Debug Console",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.tertiary,
                          ),
                        ),
                        subtitle: Text(
                          "Crash Lab, Service Monitor, Logs",
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .tertiary
                                .withValues(alpha: 0.7),
                          ),
                        ),
                        trailing: Icon(Icons.arrow_forward_ios,
                            size: 16,
                            color: Theme.of(context).colorScheme.tertiary),
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const DebugToolsScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.only(bottom: 0),
            child: Column(
              children: [
                Text(
                  "MadBunky",
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Version 1.0.0 • Made with ❤️ by AJ",
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showMorphDialog(
      context: context,
      builder: (context) {
        return const GlassDialogContainer(
          child: _AboutDialogContent(),
        );
      },
    );
  }

  void _showEditUserCardDialog(BuildContext context, WidgetRef ref) {
    final profile = ref.read(userProfileProvider);
    final nameController = TextEditingController(text: profile.name);
    final instituteController = TextEditingController(text: profile.institute);
    final nameNode = FocusNode();
    final instituteNode = FocusNode();

    Future<void> submit() async {
      HapticFeedback.mediumImpact();
      await ref.read(userProfileProvider.notifier).updateProfile(
            nameController.text.trim(),
            instituteController.text.trim(),
          );
      if (context.mounted) {
        Navigator.pop(context);
      }
    }

    showMorphDialog(
      context: context,
      builder: (context) {
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        return GlassDialogContainer(
          title: "Edit User Card",
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            FilledButton(
              onPressed: submit,
              child: const Text("Save"),
            ),
          ],
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameController,
                    focusNode: nameNode,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) =>
                        FocusScope.of(context).requestFocus(instituteNode),
                    decoration: InputDecoration(
                      labelText: "Name",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.3),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: instituteController,
                    focusNode: instituteNode,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => submit(),
                    decoration: InputDecoration(
                      labelText: "Institute / College",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.3),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _addGeofenceLocation(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(settingsProvider.notifier);

    final status = await Permission.locationWhenInUse.request();
    if (status.isGranted) {
      if (context.mounted) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const GeofencePickerScreen(),
          ),
        );

        if (result != null && result is Map) {
          final double lat = result['lat'];
          final double lng = result['lng'];
          final double radius = result['radius'];
          final String name = result['name'] ?? "Campus Location";

          // Create new Item
          final newItem = LocationItem(
            name: name,
            lat: lat,
            lng: lng,
            radius: radius,
          );

          await notifier.addCampusLocation(newItem);

          if (context.mounted) {
            MainScaffold.showGlassToast(context, "Location added!");
          }
        }
      }
    } else {
      if (context.mounted) {
        MainScaffold.showGlassToast(context, "Location permission required",
            isError: true);
      }
    }
  }

  Future<void> _editGeofenceLocation(
      BuildContext context, WidgetRef ref, LocationItem item) async {
    final notifier = ref.read(settingsProvider.notifier);

    final status = await Permission.locationWhenInUse.request();
    if (status.isGranted) {
      if (context.mounted) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GeofencePickerScreen(
              initialLocation: LatLng(item.lat, item.lng),
              initialRadius: item.radius,
              initialName: item.name,
            ),
          ),
        );

        if (result != null && result is Map) {
          final double lat = result['lat'];
          final double lng = result['lng'];
          final double radius = result['radius'];
          final String name = result['name'] ?? item.name;

          final updatedItem = item.copyWith(
            name: name,
            lat: lat,
            lng: lng,
            radius: radius,
          );

          await notifier.updateCampusLocation(updatedItem);

          if (context.mounted) {
            MainScaffold.showGlassToast(context, "Location updated!");
          }
        }
      }
    }
  }

  Future<void> _deleteGeofenceLocation(
      BuildContext context, WidgetRef ref, String id) async {
    final notifier = ref.read(settingsProvider.notifier);
    await notifier.removeCampusLocation(id);
    if (context.mounted) {
      MainScaffold.showGlassToast(context, "Location removed");
    }
  }

  Future<void> _linkSubjects(
      BuildContext context, WidgetRef ref, LocationItem item) async {
    final notifier = ref.read(settingsProvider.notifier);
    final subjects = ref.read(attendanceProvider).subjects;

    final selectedIds = await showMorphDialog<List<String>>(
      context: context,
      builder: (context) {
        return GlassDialogContainer(
          title: "Link Subjects",
          child: _SubjectSelectionDialogContent(
            initialSelection: item.subjectIds,
            allSubjects: subjects,
          ),
        );
      },
    );

    if (selectedIds != null) {
      final updatedItem = item.copyWith(subjectIds: selectedIds);
      await notifier.updateCampusLocation(updatedItem);
      if (context.mounted) {
        MainScaffold.showGlassToast(context,
            "Location linked to ${selectedIds.isEmpty ? 'All Subjects' : '${selectedIds.length} Subjects'}");
      }
    }
  }

  Future<void> _handleGeofenceToggle(
      bool value, WidgetRef ref, BuildContext context) async {
    final notifier = ref.read(settingsProvider.notifier);
    await notifier.toggleGeofence(value);

    if (value && context.mounted) {
      MainScaffold.showGlassToast(context, "Geofencing Active");
    }
  }

  Future<void> _addCurrentWifi(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(settingsProvider.notifier);
    final settings = ref.read(settingsProvider);

    // Check Permissions for SSID (Android 10+)
    var pStatus = await Permission.locationWhenInUse.status;
    if (!pStatus.isGranted) {
      pStatus = await Permission.locationWhenInUse.request();
    }

    if (pStatus.isGranted) {
      final info = NetworkInfo();
      try {
        var wifiName = await info.getWifiName();
        if (wifiName != null) {
          wifiName = wifiName.replaceAll('"', '');
          if (wifiName == "<unknown ssid>") {
            if (context.mounted) {
              MainScaffold.showGlassToast(
                  context, "Unknown SSID. Ensure Location is On.",
                  isError: true);
            }
            return;
          }

          if (settings.campusSsids.contains(wifiName)) {
            if (context.mounted) {
              MainScaffold.showGlassToast(context, "WiFi already added",
                  isError: true);
            }
            return;
          }

          await notifier.addCampusSsid(wifiName);
          if (context.mounted) {
            MainScaffold.showGlassToast(
                context, "WiFi '$wifiName' added successfully");
          }
        } else {
          if (context.mounted) {
            MainScaffold.showGlassToast(
                context, "Not connected to WiFi or could not read Name.",
                isError: true);
          }
        }
      } catch (e) {
        if (context.mounted) {
          MainScaffold.showGlassToast(context, "Error reading WiFi: $e",
              isError: true);
        }
      }
    } else {
      if (context.mounted) {
        MainScaffold.showGlassToast(
            context, "Location permission needed to read WiFi Name",
            isError: true);
      }
    }
  }

  Future<void> _deleteWifi(
      BuildContext context, WidgetRef ref, String ssid) async {
    final notifier = ref.read(settingsProvider.notifier);
    await notifier.removeCampusSsid(ssid);
    if (context.mounted) {
      MainScaffold.showGlassToast(context, "WiFi removed");
    }
  }

  Future<void> _handleWifiToggle(
      bool value, WidgetRef ref, BuildContext context) async {
    final notifier = ref.read(settingsProvider.notifier);

    if (value) {
      // Enabling: functionality check
      // 1. Check Permission
      var status = await Permission.locationWhenInUse.status;
      if (!status.isGranted) {
        status = await Permission.locationWhenInUse.request();
      }

      if (status.isGranted) {
        // 2. Check Service Status (GPS) - Required for SSID on Android 10+
        // Note: We don't force enable it, just warn if off.
        final serviceEnabled =
            await Permission.location.serviceStatus.isEnabled;
        if (!serviceEnabled) {
          if (context.mounted) {
            MainScaffold.showGlassToast(
              context,
              "Location must be ON to detect WiFi Name",
              isError: true,
            );
          }
          // We allow enabling, but warn user.
          // Or should we block? Let's block to be safe and avoid "not working" complaints.
          // Actually, let's allow it but show a specific warning dialog or toast.
          // User might enable GPS later.
        }
        await notifier.toggleWifiTrigger(true);
      } else {
        // Permission Denied
        if (context.mounted) {
          MainScaffold.showGlassToast(
            context,
            "Location permission required for WiFi Trigger",
            isError: true,
          );
        }
        // Do not enable
      }
    } else {
      // Disabling is always allowed
      await notifier.toggleWifiTrigger(false);
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _AnimatedMadBunkyLogo extends StatelessWidget {
  const _AnimatedMadBunkyLogo();

  @override
  Widget build(BuildContext context) {
    // Defines colors for "MadBunky" style
    final highContrastColor = Theme.of(context).colorScheme.onSurface;
    final lowContrastColor = Theme.of(context).colorScheme.onSurfaceVariant;

    // "M" and "B" always High Contrast (or Primary as per previous designs? Topbar uses HighContrast/White)
    // Wait, MainScaffold `_MadBunkyLogo` used `highContrastColor` (onSurface) for M/B.
    // The Settings screen previous Unicode one used `primary` for M/B.
    // "matching topbar" => Use onSurface (White/Black).
    final mbStyle = GoogleFonts.outfit(
      fontSize: 26,
      fontWeight: FontWeight.bold,
      letterSpacing: 1.0,
      color: highContrastColor,
    );

    // Animate from Low -> High on mount
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TweenAnimationBuilder<Color?>(
          duration: const Duration(milliseconds: 1500), // Slower breathe in
          curve: Curves.easeOutCubic,
          tween: ColorTween(
            begin: lowContrastColor,
            end: highContrastColor,
          ),
          builder: (context, color, _) {
            final animatedStyle = GoogleFonts.outfit(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
              color: color,
            );

            return RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                children: [
                  TextSpan(text: "M", style: mbStyle),
                  TextSpan(text: "ad", style: animatedStyle),
                  TextSpan(text: "B", style: mbStyle),
                  TextSpan(text: "unky", style: animatedStyle),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 2),
        Text(
          "v1.0.0",
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _AnimatedAjText extends StatelessWidget {
  const _AnimatedAjText();

  @override
  Widget build(BuildContext context) {
    final highContrastColor = Theme.of(context).colorScheme.onSurface;
    final lowContrastColor =
        Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3);

    return TweenAnimationBuilder<Color?>(
      duration: const Duration(milliseconds: 1500), // Same sync
      curve: Curves.easeOutCubic,
      tween: ColorTween(
        begin: lowContrastColor,
        end: highContrastColor,
      ),
      builder: (context, color, _) {
        return Text(
          "ΛJ",
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 100,
            letterSpacing: 4,
          ),
        );
      },
    );
  }
}

class _SocialRow extends StatelessWidget {
  final IconData icon;
  final String name;
  final VoidCallback onTap;
  const _SocialRow(
      {required this.icon, required this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.onSurface, size: 20),
          const SizedBox(width: 12),
          Text(name,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _BackupActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _BackupActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AboutDialogContent extends ConsumerStatefulWidget {
  const _AboutDialogContent();

  @override
  ConsumerState<_AboutDialogContent> createState() =>
      __AboutDialogContentState();
}

class __AboutDialogContentState extends ConsumerState<_AboutDialogContent> {
  int _unlockStage = 0;
  int _ajTapCount = 0;
  DateTime? _lastTapTime;

  void _handleAjTap() {
    final now = DateTime.now();

    // Reset if too slow between taps (2 seconds timeout)
    if (_lastTapTime == null || now.difference(_lastTapTime!).inSeconds > 2) {
      _ajTapCount = 1;
    } else {
      _ajTapCount++;
    }
    _lastTapTime = now;

    if (_unlockStage == 0) {
      // Stage 0: 5 Taps on Aj -> Stage 1
      if (_ajTapCount == 5) {
        HapticFeedback.mediumImpact();
        setState(() {
          _unlockStage = 1;
          _ajTapCount = 0;
        });
      } else {
        if (_ajTapCount > 2) HapticFeedback.selectionClick();
      }
    } else if (_unlockStage == 2) {
      // Stage 2: 5 Taps on Aj -> UNLOCK
      if (_ajTapCount == 5) {
        HapticFeedback.heavyImpact();
        ref.read(debugModeProvider.notifier).update((state) => !state);
        final isDebug = ref.read(debugModeProvider);
        if (mounted) {
          MainScaffold.showGlassToast(
              context,
              isDebug
                  ? "Developer Mode UNLOCKED 🛠️"
                  : "Developer Mode Disabled");
        }
        setState(() {
          _unlockStage = 0; // Reset
          _ajTapCount = 0;
        });
      } else {
        if (_ajTapCount > 2) HapticFeedback.selectionClick();
      }
    }
    // If Stage 1 (Waiting for Heart), ignore Aj taps or reset sequence?
    // Usually strict sequences reset on wrong input, but keeping it simple: just ignore or let timer reset count.
  }

  void _handleHeartTap() {
    if (_unlockStage == 1) {
      // Stage 1: 1 Tap on Heart -> Stage 2
      HapticFeedback.mediumImpact();
      setState(() {
        _unlockStage = 2;
        _ajTapCount = 0; // Reset count for next Aj sequence
      });
    }
  }

  void _handleLogoTap() {
    // Logo no longer part of unlock sequence
    // Maybe just some feedback or Easter egg?
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Avatar
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Designed With ",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  GestureDetector(
                    onTap: _handleHeartTap,
                    child: Text(
                      "❤️",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  Text(
                    " by",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _handleAjTap,
                child: const _AnimatedAjText(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        // App Info Row
        GestureDetector(
          onTap: _handleLogoTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: ClipOval(
                  child: Image.asset('assets/icon/mb.png', fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 16),
              const _AnimatedMadBunkyLogo(),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Socials
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Social",
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                  "join us on our platforms for updates, tips, discussion & ideas",
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13)),
              const SizedBox(height: 16),
              _SocialRow(
                  icon: Icons.telegram,
                  name: "Telegram",
                  onTap: () async {
                    final uri = Uri.parse('https://t.me/MadBunky_Channel');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    } else {
                      if (context.mounted) {
                        MainScaffold.showGlassToast(
                            context, "Could not launch Telegram");
                      }
                    }
                  }),
              const SizedBox(height: 16),
              _SocialRow(icon: Icons.discord, name: "Discord", onTap: () {}),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Legal & Info
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const FeatureListScreen()));
              },
              child: const Text("Features"),
            ),
            Text("|",
                style: TextStyle(color: Theme.of(context).colorScheme.outline)),
            TextButton(
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const PrivacyPolicyScreen()));
              },
              child: const Text("Features"),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _SubjectSelectionDialogContent extends StatefulWidget {
  final List<String> initialSelection;
  final List<Subject> allSubjects;

  const _SubjectSelectionDialogContent({
    required this.initialSelection,
    required this.allSubjects,
  });

  @override
  State<_SubjectSelectionDialogContent> createState() =>
      _SubjectSelectionDialogContentState();
}

class _SubjectSelectionDialogContentState
    extends State<_SubjectSelectionDialogContent> {
  late List<String> _selectedIds;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedIds = List.from(widget.initialSelection);
  }

  @override
  Widget build(BuildContext context) {
    // Filter subjects
    final filteredSubjects = widget.allSubjects.where((s) {
      return s.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    // Sort: Selected first, then alphabet
    filteredSubjects.sort((a, b) {
      final aSel = _selectedIds.contains(a.id);
      final bSel = _selectedIds.contains(b.id);
      if (aSel && !bSel) return -1;
      if (!aSel && bSel) return 1;
      return a.name.compareTo(b.name);
    });

    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Search & Select All
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: "Search Subjects...",
                    isDense: true,
                    prefixIcon: const Icon(Icons.search, size: 20),
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(width: 8),
              // Select All / None Button
              IconButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    if (_selectedIds.length == widget.allSubjects.length) {
                      _selectedIds.clear(); // Deselect All
                    } else {
                      _selectedIds = widget.allSubjects
                          .map((s) => s.id)
                          .toList(); // Select All
                    }
                  });
                },
                icon: Icon(
                  _selectedIds.length == widget.allSubjects.length
                      ? Icons.deselect
                      : Icons.select_all,
                  color: theme.colorScheme.primary,
                ),
                tooltip: "Toggle All",
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // List
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 300),
          child: filteredSubjects.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text("No subjects found",
                      style:
                          TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: filteredSubjects.length,
                  itemBuilder: (context, index) {
                    final subject = filteredSubjects[index];
                    final isSelected = _selectedIds.contains(subject.id);

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() {
                            if (isSelected) {
                              _selectedIds.remove(subject.id);
                            } else {
                              _selectedIds.add(subject.id);
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 8),
                          child: Row(
                            children: [
                              // Checkbox
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : Colors.transparent,
                                  border: Border.all(
                                      color: isSelected
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.outline,
                                      width: 2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: isSelected
                                    ? Icon(Icons.check,
                                        size: 14,
                                        color: theme.colorScheme.onPrimary)
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(subject.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14)),
                                    if (subject.teacherName != null)
                                      Text(subject.teacherName!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: theme.colorScheme
                                                  .onSurfaceVariant)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),

        const SizedBox(height: 16),
        // Active Status Text
        Text(
          _selectedIds.isEmpty
              ? "Applies to ALL Subjects (Default)"
              : "Applies to ${_selectedIds.length} Selected Subjects",
          style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.primary,
              fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 16),

        // Actions
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel")),
            const SizedBox(width: 8),
            FilledButton(
                onPressed: () {
                  Navigator.pop(context, _selectedIds);
                },
                child: const Text("Save Link")),
          ],
        ),
      ],
    );
  }
}

// ==========================================
// GEMINI SETTINGS CARD
// ==========================================
class _GeminiSettingsCard extends ConsumerStatefulWidget {
  const _GeminiSettingsCard();

  @override
  ConsumerState<_GeminiSettingsCard> createState() =>
      _GeminiSettingsCardState();
}

class _GeminiSettingsCardState extends ConsumerState<_GeminiSettingsCard> {
  bool _isTesting = false;
  late TextEditingController _customPromptController;
  String? _lastSyncedPrompt;

  @override
  void initState() {
    super.initState();
    final initialPrompt = ref.read(settingsProvider).geminiCustomPrompt;
    _customPromptController = TextEditingController(text: initialPrompt);
    _lastSyncedPrompt = initialPrompt;
    _customPromptController.addListener(_onPromptChanged);
  }

  void _onPromptChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _customPromptController.removeListener(_onPromptChanged);
    _customPromptController.dispose();
    super.dispose();
  }

  Future<void> _showApiKeyDialog(
      BuildContext context, String? currentKey) async {
    final controller = TextEditingController(text: currentKey);
    bool obscureText = true;

    await showMorphDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return GlassDialogContainer(
              title: "Gemini API Key",
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Cancel"),
                ),
                FilledButton(
                  onPressed: () async {
                    final key = controller.text.trim();
                    if (key.isEmpty) {
                      await GeminiService.instance.deleteApiKey();
                    } else {
                      await GeminiService.instance.saveApiKey(key);
                    }
                    ref.invalidate(geminiApiKeyProvider);
                    if (context.mounted) {
                      Navigator.pop(ctx);
                      MainScaffold.showGlassToast(context, "API Key Saved");
                    }
                  },
                  child: const Text("Save"),
                ),
              ],
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Get a free Gemini API Key from Google AI Studio to enable schedule scanning & extraction.",
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    obscureText: obscureText,
                    decoration: InputDecoration(
                      labelText: "API Key",
                      hintText: "AIzaSy...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(obscureText
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () =>
                            setState(() => obscureText = !obscureText),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final url = Uri.parse("https://aistudio.google.com/");
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url,
                            mode: LaunchMode.externalApplication);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.open_in_new,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            "Get API Key from Google AI Studio",
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _testConnection(String apiKey, String modelName) async {
    setState(() => _isTesting = true);
    final error = await GeminiService.instance.testApiKey(apiKey, modelName);
    if (mounted) {
      setState(() => _isTesting = false);
      if (error == null) {
        MainScaffold.showGlassToast(context, "Gemini Connection Successful!");
      } else {
        MainScaffold.showGlassToast(context, "Connection failed: $error",
            isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final apiKeyAsync = ref.watch(geminiApiKeyProvider);

    if (_lastSyncedPrompt != settings.geminiCustomPrompt) {
      _lastSyncedPrompt = settings.geminiCustomPrompt;
      _customPromptController.text = settings.geminiCustomPrompt;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                color: settings.enableGeminiAI
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Gemini AI Timetable Parsing",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "Use Gemini to extract classes and dates",
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
                value: settings.enableGeminiAI,
                onChanged: (val) {
                  HapticFeedback.mediumImpact();
                  notifier.toggleGeminiAI(val);
                },
              ),
            ],
          ),
          if (settings.enableGeminiAI) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            apiKeyAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator.adaptive()),
              error: (err, stack) => Text("Error loading API key: $err"),
              data: (apiKey) {
                final hasKey = apiKey != null && apiKey.isNotEmpty;
                final displayKey = hasKey ? "••••••••" : "Not Set";
                return Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.vpn_key_outlined),
                        const SizedBox(width: 16),
                        const Text(
                          "Gemini API Key",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => _showApiKeyDialog(context, apiKey),
                          child: Text(
                            displayKey,
                            style: TextStyle(
                              color: hasKey
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.psychology_outlined),
                        const SizedBox(width: 16),
                        const Text(
                          "AI Model",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: [
                              'gemini-3.1-pro-preview',
                              'gemini-3.1-flash-lite',
                            ].contains(settings.geminiModel)
                                ? settings.geminiModel
                                : 'gemini-3.1-flash-lite',
                            alignment: Alignment.centerRight,
                            style: GoogleFonts.outfit(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            items: const [
                              DropdownMenuItem(
                                  value: "gemini-3.1-pro-preview",
                                  child: Text("3.1 Pro")),
                              DropdownMenuItem(
                                  value: "gemini-3.1-flash-lite",
                                  child: Text("3.1 Flash-Lite")),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                HapticFeedback.lightImpact();
                                notifier.updateGeminiModel(val);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.edit_note),
                            const SizedBox(width: 16),
                            const Text(
                              "Custom Extraction Prompt",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          minLines: 1,
                          maxLines: 2,
                          controller: _customPromptController,
                          style: GoogleFonts.outfit(fontSize: 14),
                          decoration: InputDecoration(
                            hintText:
                                "e.g. Ignore Saturday classes, map CSE to Computer Science, start from June 1st",
                            hintStyle: GoogleFonts.outfit(
                              fontSize: 13,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant
                                  .withValues(alpha: 0.6),
                            ),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            suffixIcon: _customPromptController.text !=
                                    settings.geminiCustomPrompt
                                ? IconButton(
                                    icon: const Icon(Icons.check, size: 20),
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    tooltip: "Save Prompt",
                                    onPressed: () async {
                                      HapticFeedback.mediumImpact();
                                      await notifier.updateGeminiCustomPrompt(
                                          _customPromptController.text);
                                      if (context.mounted) {
                                        FocusScope.of(context).unfocus();
                                        MainScaffold.showGlassToast(
                                            context, "Prompt Saved");
                                      }
                                    },
                                  )
                                : null,
                          ),
                        ),
                      ],
                    ),
                    if (hasKey) ...[
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.network_ping),
                          const SizedBox(width: 16),
                          const Text(
                            "Test API Key",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          _isTesting
                              ? const CircularProgressIndicator.adaptive()
                              : TextButton.icon(
                                  icon: const Icon(Icons.play_arrow),
                                  label: const Text("Test Connection"),
                                  onPressed: () => _testConnection(
                                      apiKey, settings.geminiModel),
                                ),
                        ],
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

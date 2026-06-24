import 'package:flutter/material.dart';
import '../models/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';

class PrivacyPolicyScreen extends ConsumerWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final isDark = settings.themeMode == ThemeType.dark ||
        (settings.themeMode == ThemeType.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.grey[100],
      appBar: AppBar(
        title: const Text("Privacy Policy"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildCard(
            context,
            title: "Data Privacy",
            content:
                "MadBunky Pro is designed with privacy as a priority. All your data, including attendance logs, subjects, schedules, and settings, is stored locally on your device. We do not upload your data to any cloud server unless you explicitly use the Backup/Restore feature with a file.",
            icon: Icons.security,
          ),
          const SizedBox(height: 16),
          _buildCard(
            context,
            title: "Location Services",
            content:
                "Location data is used exclusively for the Geofence Automation feature to remind you to mark attendance when entering campus. Your location coordinates are stored locally on your device and are never shared.",
            icon: Icons.location_on,
          ),
          const SizedBox(height: 16),
          _buildCard(
            context,
            title: "WiFi & Network",
            content:
                "We access your WiFi network name (SSID) solely for the WiFi Trigger automation feature. This allows the app to know when you are at the campus. This information is processed locally.",
            icon: Icons.wifi,
          ),
          const SizedBox(height: 16),
          _buildCard(
            context,
            title: "Analytics",
            content:
                "MadBunky Pro does not track your usage or collect personal analytics.",
            icon: Icons.analytics_outlined,
          ),
          const SizedBox(height: 24),
          Center(
              child:
                  Text("Version 1.0.0", style: TextStyle(color: Colors.grey))),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context,
      {required String title,
      required String content,
      required IconData icon}) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              content,
              style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

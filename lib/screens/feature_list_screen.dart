import 'package:flutter/material.dart';
import '../models/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';

class FeatureListScreen extends ConsumerWidget {
  const FeatureListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final isDark = settings.themeMode == ThemeType.dark ||
        (settings.themeMode == ThemeType.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.grey[100],
      appBar: AppBar(
        title: const Text("Features"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildFeatureGroup(context, "Attendance Management", [
            "Smart Bunking Logic: Tells you exactly how many classes you can miss or must attend.",
            "Detailed Analytics: Visual charts and stats for every subject.",
            "Proxy Support: Track proxies separately.",
            "Edit History: View logs of all your attendance actions."
          ]),
          _buildFeatureGroup(context, "Scheduling", [
            "Dynamic Time Table: Auto-updates based on current day.",
            "Holiday Awareness: Skips notifications on holidays (configurable).",
            "Event Support: Add one-time events or extra classes."
          ]),
          _buildFeatureGroup(context, "Automation", [
            "Geofence Triggers: Reminds you when you enter campus.",
            "WiFi Triggers: Marks attendance/notifies when connecting to college WiFi.",
            "Notification Actions: Mark attendance directly from notifications."
          ]),
          _buildFeatureGroup(context, "Customization", [
            "Material You: Adapts to your system wallpaper colors.",
            "Dark/Light Mode: Full theme support.",
          ]),
        ],
      ),
    );
  }

  Widget _buildFeatureGroup(
      BuildContext context, String title, List<String> features) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4),
          child: Text(
            title,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Card(
          elevation: 0,
          color: Theme.of(context).colorScheme.surfaceContainer,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: features
                .map((f) => ListTile(
                      leading: Icon(Icons.check_circle_outline,
                          color: Theme.of(context).colorScheme.tertiary,
                          size: 20),
                      title: Text(f, style: TextStyle(fontSize: 14)),
                      dense: true,
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

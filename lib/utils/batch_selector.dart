import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/gemini_service.dart';
import 'morph_dialog.dart';

/// Shows a step-by-step glassmorphic dialog asking the user to choose their batch
/// for each detected category (e.g. Clinics, Practicals), then filters and returns the final sessions.
Future<List<ClassSession>> showBatchSelectorAndFilter(
  BuildContext context,
  ScheduleExtractionResult result,
) async {
  final batchGroups = result.batchGroups;
  final sessions = result.sessions;

  if (batchGroups.isEmpty) {
    return sessions;
  }

  final Map<String, String> selectedBatches = {};

  for (var category in batchGroups.keys) {
    final options = batchGroups[category];
    if (options == null || options.isEmpty) continue;

    // Show step-by-step picker dialog
    final selectedOption = await showMorphDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return GlassDialogContainer(
          title: "Select $category Batch",
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'All'),
              child: Text(
                "All Batches / Skip",
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "We found multiple batch groups for '$category' in this schedule. Which batch do you belong to?",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: options.map((option) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: InkWell(
                          onTap: () => Navigator.pop(context, option),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    option,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  color: Colors.white70,
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selectedOption != null && selectedOption != 'All') {
      selectedBatches[category] = selectedOption;
    }
  }

  // Apply filtering logic based on selectedBatches
  List<ClassSession> filteredSessions = List.from(sessions);

  for (var entry in selectedBatches.entries) {
    final category = entry.key;
    final selectedValue = entry.value;
    final categoryOptions = batchGroups[category] ?? [];

    filteredSessions = filteredSessions.where((session) {
      final sessionBatch = session.batch;
      if (sessionBatch == null || sessionBatch.isEmpty) return true; // Keep general sessions

      // Check if session's batch belongs to this category's options (case-insensitive)
      final belongsToCategory = categoryOptions.any(
        (opt) => opt.trim().toLowerCase() == sessionBatch.trim().toLowerCase(),
      );

      if (!belongsToCategory) return true; // Keep if it's part of another category or not in this one

      // If it belongs to this category, only keep if it matches the selected value
      return sessionBatch.trim().toLowerCase() == selectedValue.trim().toLowerCase();
    }).toList();
  }

  return filteredSessions;
}

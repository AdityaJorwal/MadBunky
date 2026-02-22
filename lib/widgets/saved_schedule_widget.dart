import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../screens/schedules_grid_screen.dart';
import '../utils/morph_dialog.dart';

class SavedScheduleWidget extends ConsumerWidget {
  const SavedScheduleWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduleFiles = ref.watch(savedScheduleProvider);

    // Helper to prompt for name and save
    Future<void> uploadNewSchedule() async {
      // Renamed
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result != null && result.files.single.path != null) {
        final imagePath = result.files.single.path!;
        // Prompt for Name
        final TextEditingController nameController = TextEditingController();
        if (context.mounted) {
          showMorphDialog(
              context: context,
              builder: (ctx) => GlassDialogContainer(
                  title: "Save Schedule",
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text("Cancel")),
                    FilledButton(
                        onPressed: () {
                          if (nameController.text.trim().isNotEmpty) {
                            Navigator.pop(ctx);
                            ref
                                .read(savedScheduleProvider.notifier)
                                .save(imagePath, nameController.text.trim());
                          }
                        },
                        child: const Text("Save"))
                  ],
                  child: TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                        labelText: "Schedule Name",
                        hintText: "e.g. Exam Schedule"),
                    autofocus: true,
                  )));
        }
      }
    }

    if (scheduleFiles.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: GestureDetector(
          onTap: uploadNewSchedule, // Updated usage
          child: Container(
            height: 140,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .outline
                    .withValues(alpha: 0.2),
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.upload_file_rounded,
                    size: 32,
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.8)),
                const SizedBox(height: 8),
                Text(
                  "Upload Schedule Image",
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7), // Fixed alpha warning style
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "Select from Gallery",
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.4), // Fixed alpha warning style
                    fontSize: 12,
                  ),
                )
              ],
            ),
          ),
        ),
      );
    }

    // Show the first (latest) schedule
    final latestFile = scheduleFiles.first;

    return Padding(
      padding: const EdgeInsets.only(left: 0, right: 0, top: 0, bottom: 16),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const SchedulesGridScreen(),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Theme.of(context)
                  .colorScheme
                  .outline
                  .withValues(alpha: 0.1), // Fixed alpha warning style
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black
                    .withValues(alpha: 0.1), // Fixed alpha warning style
                blurRadius: 12,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                // Display the Image
                Image.file(
                  latestFile,
                  key: ValueKey(latestFile.path),
                  fit: BoxFit.fitWidth,
                  width: double.infinity,
                ),

                // Button to open grid (Bottom Right)
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surface
                              .withValues(
                                  alpha: 0.8), // Fixed alpha warning style
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .outline
                                .withValues(
                                    alpha: 0.3), // Fixed alpha warning style
                          )),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.grid_view_rounded,
                            size: 20,
                            color: Theme.of(context).colorScheme.onSurface),
                        const SizedBox(width: 8),
                        Text("View All",
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.bold)),
                      ]),
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

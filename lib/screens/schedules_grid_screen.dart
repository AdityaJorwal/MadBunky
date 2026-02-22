import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:file_picker/file_picker.dart';

import '../providers/providers.dart';
import '../utils/morph_dialog.dart';
import 'schedule_viewer_screen.dart';

class SchedulesGridScreen extends ConsumerWidget {
  const SchedulesGridScreen({super.key});

  Future<void> _uploadNewSchedule(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      final imagePath = result.files.single.path!;
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
                  ),
                ));
      }
    }
  }

  void _renameSchedule(BuildContext context, WidgetRef ref, File file) {
    final TextEditingController nameController =
        TextEditingController(text: path.basenameWithoutExtension(file.path));
    showMorphDialog(
        context: context,
        builder: (ctx) => GlassDialogContainer(
            title: "Rename Schedule",
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
                          .rename(file, nameController.text.trim());
                    }
                  },
                  child: const Text("Rename")),
            ],
            child: TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "New Name"),
              autofocus: true,
            )));
  }

  void _deleteSchedule(BuildContext context, WidgetRef ref, File file) {
    showMorphDialog(
        context: context,
        builder: (ctx) => GlassDialogContainer(
            title: "Delete Schedule?",
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text("Cancel",
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface))),
              FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    ref.read(savedScheduleProvider.notifier).delete(file);
                  },
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text("Delete")),
            ],
            child: Text(
                "This will permanently remove '${path.basenameWithoutExtension(file.path)}'.")));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduleFiles = ref.watch(savedScheduleProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Saved Schedules"),
        leading: const BackButton(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _uploadNewSchedule(context, ref),
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text("Add Schedule"),
      ),
      body: scheduleFiles.isEmpty
          ? const Center(child: Text("No saved schedules yet."))
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.75,
              ),
              itemCount: scheduleFiles.length,
              itemBuilder: (context, index) {
                final file = scheduleFiles[index];
                final name = path.basenameWithoutExtension(file.path);

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ScheduleViewerScreen(initialFile: file),
                      ),
                    );
                  },
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withValues(alpha: 0.2),
                      ),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Image Preview
                        Image.file(
                          file,
                          key: ValueKey(file.path),
                          fit: BoxFit.cover,
                        ),
                        // Gradient & Title at bottom
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.8),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Options Menu (Top Right)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Material(
                            color: Colors.transparent,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                              ),
                              child: PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert,
                                    color: Colors.white, size: 20),
                                tooltip: 'Options',
                                onSelected: (value) async {
                                  if (value == 'view') {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ScheduleViewerScreen(
                                            initialFile: file),
                                      ),
                                    );
                                  } else if (value == 'rename') {
                                    _renameSchedule(context, ref, file);
                                  } else if (value == 'remove') {
                                    _deleteSchedule(context, ref, file);
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'view',
                                    child: Row(
                                      children: [
                                        Icon(Icons.fullscreen, size: 20),
                                        SizedBox(width: 8),
                                        Text("View"),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'rename',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit_outlined, size: 20),
                                        SizedBox(width: 8),
                                        Text("Rename"),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'remove',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete_outline,
                                            size: 20, color: Colors.redAccent),
                                        SizedBox(width: 8),
                                        Text("Delete",
                                            style: TextStyle(
                                                color: Colors.redAccent)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

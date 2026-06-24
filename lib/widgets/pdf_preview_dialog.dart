import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../utils/morph_dialog.dart';
import '../screens/main_scaffold.dart';

class PdfPreviewDialog extends ConsumerStatefulWidget {
  final List<String> imagePaths;
  final Function() onConfirm;

  const PdfPreviewDialog({
    super.key,
    required this.imagePaths,
    required this.onConfirm,
  });

  @override
  ConsumerState<PdfPreviewDialog> createState() => _PdfPreviewDialogState();
}

class _PdfPreviewDialogState extends ConsumerState<PdfPreviewDialog> {
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return GlassDialogContainer(
      child: SizedBox(
        width: size.width * 0.9,
        height: size.height * 0.85,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const Text(
                    "PDF Preview",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "${widget.imagePaths.length} pages generated",
                    style: TextStyle(
                        color: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.color
                            ?.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            ),

            // Image List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: widget.imagePaths.length,
                itemBuilder: (context, index) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).dividerColor),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.black12,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              color: Theme.of(context).cardColor,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("Page ${index + 1}",
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16)),
                                  // Save this page as schedule button
                                  TextButton.icon(
                                    onPressed: () async {
                                      final TextEditingController
                                          nameController =
                                          TextEditingController();
                                      showMorphDialog(
                                          context: context,
                                          builder: (ctx) =>
                                              GlassDialogContainer(
                                                  title: "Save Schedule",
                                                  actions: [
                                                    TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(ctx),
                                                        child: const Text(
                                                            "Cancel")),
                                                    FilledButton(
                                                        onPressed: () {
                                                          if (nameController
                                                              .text
                                                              .trim()
                                                              .isNotEmpty) {
                                                            Navigator.pop(
                                                                ctx); // Close the name input dialog
                                                            Navigator.pop(
                                                                context); // Close the PdfPreviewDialog
                                                            ref
                                                                .read(savedScheduleProvider
                                                                    .notifier)
                                                                .save(
                                                                    widget.imagePaths[
                                                                        index],
                                                                    nameController
                                                                        .text
                                                                        .trim());
                                                            MainScaffold
                                                                .showGlassToast(
                                                                    context,
                                                                    "Schedule Saved!");
                                                          }
                                                        },
                                                        child:
                                                            const Text("Save"))
                                                  ],
                                                  child: TextField(
                                                    controller: nameController,
                                                    decoration:
                                                        const InputDecoration(
                                                            labelText:
                                                                "Schedule Name"),
                                                    autofocus: true,
                                                  )));
                                    },
                                    icon: const Icon(Icons.star_outline,
                                        size: 20),
                                    label: const Text("Set as Week Schedule"),
                                  )
                                ],
                              ),
                            ),
                            InteractiveViewer(
                              panEnabled:
                                  true, // Enable panning so user can look around when zoomed
                              minScale: 1.0,
                              maxScale: 4.0,
                              child: Image.file(
                                File(widget.imagePaths[index]),
                                fit: BoxFit.fitWidth,
                                cacheHeight: 1000,
                              ),
                            ),
                          ]),
                    ),
                  );
                },
              ),
            ),

            // Footer Actions
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16))),
                      child: const Text("Cancel"),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onConfirm();
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16))),
                      child: const Text("Scan Pages",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

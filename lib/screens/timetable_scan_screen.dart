import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/providers.dart';
import '../services/gemini_service.dart';
import '../widgets/pdf_confirmation_dialog.dart';

import 'main_scaffold.dart';
import '../services/document_scanner_service.dart';
import '../utils/morph_dialog.dart';

class TimetableScanScreen extends ConsumerStatefulWidget {
  const TimetableScanScreen({super.key});

  @override
  ConsumerState<TimetableScanScreen> createState() =>
      _TimetableScanScreenState();
}

class _TimetableScanScreenState extends ConsumerState<TimetableScanScreen> {
  final DocumentScannerService _scannerService = DocumentScannerService();
  File? _imageFile;
  bool _showPreview = false;
  bool _isLoading = false;

  File? _originalImageFile; // Store original for reverting filter
  bool _isFiltered = false;

  @override
  void dispose() {
    _scannerService.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    String? path;
    if (source == ImageSource.camera) {
      path = await _scannerService.scanDocument();
    } else {
      path = await _scannerService.pickAndCropImage(context);
    }

    if (path != null) {
      if (!mounted) return;
      final validPath = path;
      setState(() {
        _imageFile = File(validPath);
        _originalImageFile = File(validPath);
        _showPreview = true;
        _isFiltered = false;
      });
    }
  }

  Future<void> _pickPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() => _isLoading = true);

        final pdfPath = result.files.single.path!;
        // Convert to image
        final imagePath =
            await ref.read(pdfServiceProvider).convertPdfToImage(pdfPath);

        if (imagePath != null) {
          if (!mounted) return;
          setState(() {
            _imageFile = File(imagePath);
            _originalImageFile = File(imagePath); // Save original
            _showPreview = true;
            _isFiltered = false;
          });
        } else {
          if (!mounted) return;
          MainScaffold.showGlassToast(context, "Failed to import PDF",
              isError: true);
        }
      }
    } catch (e) {
      debugPrint("PDF Pick error: $e");
      if (mounted) {
        MainScaffold.showGlassToast(context, "Error picking PDF",
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // NEW: Crop functionality
  Future<void> _cropCurrentImage() async {
    if (_imageFile == null) return;

    // We always crop the CURRENT image (whether filtered or not, users expect WYSIWYG)
    // OR we could crop the original and re-apply filter?
    // Let's crop the current one for simplicity,
    // BUT if we want to support "Reset Filter" properly, we should crop the underlying source?
    // Simpler flow: Crop always updates both "current" and "original" if filter is off,
    // If filter is on, it's tricky.
    // Let's crop the *visible* image.

    try {
      final croppedPath =
          await _scannerService.cropImage(context, _imageFile!.path);
      if (croppedPath != null) {
        setState(() {
          _imageFile = File(croppedPath);
          // Update original if we weren't filtered, or if we want to commit the crop
          if (!_isFiltered) {
            _originalImageFile = File(croppedPath);
          } else {
            // If we cropped a filtered image, that new cropped image IS the new "base"
            // potentially, but re-filtering already filtered image is bad.
            // Best UX: Crop edits the file.
            _originalImageFile = File(croppedPath); // Commit crop
          }
        });
      }
    } catch (e) {
      debugPrint("Crop error: $e");
    }
  }

  // NEW: Filter functionality
  Future<void> _toggleFilter() async {
    if (_imageFile == null || _originalImageFile == null) return;

    if (_isFiltered) {
      // Revert to original
      setState(() {
        _imageFile = _originalImageFile;
        _isFiltered = false;
      });
    } else {
      // Apply Filter
      setState(() => _isLoading = true);
      try {
        final enhancedPath =
            await _scannerService.enhanceImage(_originalImageFile!.path);
        if (mounted) {
          setState(() {
            _imageFile = File(enhancedPath);
            _isFiltered = true;
          });
        }
      } catch (e) {
        if (mounted) {
          MainScaffold.showGlassToast(context, "Filter failed", isError: true);
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _setAsSchedule() async {
    if (_imageFile == null) return;

    final TextEditingController nameController = TextEditingController();

    // Show Name Dialog
    await showMorphDialog(
      context: context,
      builder: (ctx) => GlassDialogContainer(
        title: "Save Schedule",
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) {
                MainScaffold.showGlassToast(context, "Please enter a name",
                    isError: true);
                return;
              }
              Navigator.pop(ctx);
              // Proceed to save
              _performSave(nameController.text.trim());
            },
            child: const Text("Save"),
          ),
        ],
        child: TextField(
          controller: nameController,
          decoration: const InputDecoration(
              labelText: "Schedule Name", hintText: "e.g. Class Schedule"),
          autofocus: true,
        ),
      ),
    );
  }

  Future<void> _performSave(String name) async {
    try {
      // Save the image using the provider
      await ref
          .read(savedScheduleProvider.notifier)
          .save(_imageFile!.path, name);

      if (!mounted) return;

      MainScaffold.showGlassToast(context, "Schedule Appended!");
      Navigator.pop(context); // Close the screen
    } catch (e) {
      if (mounted) {
        MainScaffold.showGlassToast(context, "Failed to save: $e",
            isError: true);
      }
    }
  }

  Future<void> _extractClassesWithAI() async {
    if (_imageFile == null) return;

    final settings = ref.read(settingsProvider);
    final apiKey = await GeminiService.instance.getApiKey();

    if (!mounted) return;

    if (apiKey == null || apiKey.isEmpty) {
      MainScaffold.showGlassToast(context, "Gemini API Key is not set in Settings.", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final mimeType = _imageFile!.path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
      final subjects = ref.read(attendanceProvider).subjects;

      final extractedSessions = await GeminiService.instance.extractSchedule(
        file: _imageFile!,
        mimeType: mimeType,
        apiKey: apiKey,
        modelName: settings.geminiModel,
        existingSubjects: subjects,
        customPrompt: settings.geminiCustomPrompt,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (extractedSessions.isEmpty) {
        MainScaffold.showGlassToast(context, "No classes could be extracted.", isError: true);
        return;
      }

      // Launch PdfConfirmationDialog
      showMorphDialog(
        context: context,
        builder: (c) => PdfConfirmationDialog(
          extractedSessions: extractedSessions,
          initialDate: DateTime.now(),
          instituteName: "Gemini AI",
          showSaveOption: false,
          onConfirm: (confirmedSessions, selectedDate, _) {
            final notifier = ref.read(attendanceProvider.notifier);
            for (var session in confirmedSessions) {
              notifier.addClassSession(session);
            }
            if (mounted) {
              MainScaffold.showGlassToast(
                context,
                "Imported ${confirmedSessions.length} classes using Gemini!",
              );
              Navigator.pop(context); // Close the scanner screen too
            }
          },
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        MainScaffold.showGlassToast(context, "AI extraction failed: $e", isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Set Schedule Reference",
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : !_showPreview
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                          Icons
                              .wallpaper_rounded, // Changed icon to represent static image
                          size: 64,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(height: 16),
                      Text("Import Schedule",
                          style: GoogleFonts.outfit(fontSize: 20)),
                      const SizedBox(height: 8),
                      Text("Set a photo as your schedule reference",
                          style: GoogleFonts.outfit(color: Colors.grey)),
                    ],
                  ),
                )
              : _buildPreviewUi(),
      floatingActionButton: !_showPreview && !_isLoading
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: 'cam',
                  onPressed: () => _pickImage(ImageSource.camera),
                  tooltip: "Scan with Camera",
                  child: const Icon(Icons.camera_alt),
                ),
                const SizedBox(height: 16),
                FloatingActionButton(
                  heroTag: 'gall',
                  onPressed: () => _pickImage(ImageSource.gallery),
                  tooltip: "Pick from Gallery",
                  child: const Icon(Icons.photo_library),
                ),
                const SizedBox(height: 16),
                FloatingActionButton(
                  heroTag: 'pdf',
                  onPressed: _pickPdf,
                  tooltip: "Import PDF",
                  child: const Icon(Icons.picture_as_pdf),
                ),
              ],
            )
          : null,
    );
  }

  Widget _buildPreviewUi() {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(_imageFile!, fit: BoxFit.contain),
            ),
          ),
        ),

        // Editor Toolbar
        Container(
          height: 60,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                onPressed: _cropCurrentImage,
                icon: const Icon(Icons.crop),
                tooltip: "Crop",
              ),
              Container(
                  width: 1,
                  height: 24,
                  color: Colors.grey.withValues(alpha: 0.3)),
              IconButton(
                onPressed: _toggleFilter,
                icon: Icon(_isFiltered
                    ? Icons.filter_b_and_w_rounded
                    : Icons.filter_b_and_w_outlined),
                color:
                    _isFiltered ? Theme.of(context).colorScheme.primary : null,
                tooltip: "High Contrast Filter",
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, -4),
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              (() {
                final settings = ref.watch(settingsProvider);
                if (settings.enableGeminiAI) {
                  return Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _extractClassesWithAI,
                          icon: const Icon(Icons.auto_awesome),
                          label: const Text("Extract Classes (AI)"),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.all(16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _setAsSchedule,
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text("Set as Schedule Reference"),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.all(16),
                          ),
                        ),
                      ),
                    ],
                  );
                } else {
                  return SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _setAsSchedule,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text("Set as Schedule Reference"),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  );
                }
              })(),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  setState(() {
                    _showPreview = false;
                    _imageFile = null;
                    _originalImageFile = null;
                    _isFiltered = false;
                  });
                },
                child: const Text("Cancel"),
              ),
            ],
          ),
        )
      ],
    );
  }
}

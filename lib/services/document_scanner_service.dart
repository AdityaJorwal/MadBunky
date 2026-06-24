import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Added for compute
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class DocumentScannerService {
  final _docScanner = DocumentScanner(
    options: DocumentScannerOptions(
      documentFormat: DocumentFormat.jpeg,
      mode: ScannerMode.full,
      isGalleryImport: true, // Allow native gallery import if supported
      pageLimit: 1, // specific for timetable scanning
    ),
  );

  final _picker = ImagePicker();

  /// Launches the native document scanner (Camera).
  /// Returns the path to the scanned file (JPEG), or null if cancelled.
  Future<String?> scanDocument() async {
    try {
      final result = await _docScanner.scanDocument();
      if (result.images.isNotEmpty) {
        return result.images.first;
      }
    } catch (e) {
      debugPrint("Document Scan failed: $e");
    }
    return null;
  }

  /// Picks an image from gallery and launches the Cropper.
  Future<String?> pickAndCropImage(BuildContext context) async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return null;
      if (!context.mounted) return null;
      final primaryColor = Theme.of(context).colorScheme.primary;

      final cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Timetable',
            toolbarColor: primaryColor,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: 'Crop Timetable',
          ),
        ],
      );

      return cropped?.path;
    } catch (e) {
      debugPrint("Pick/Crop failed: $e");
      return null;
    }
  }

  /// Explicitly opens the cropper on a given file path.
  Future<String?> cropImage(BuildContext context, String filePath) async {
    try {
      if (!context.mounted) return null;
      final primaryColor = Theme.of(context).colorScheme.primary;

      final cropped = await ImageCropper().cropImage(
        sourcePath: filePath,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Timetable',
            toolbarColor: primaryColor,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: 'Crop Timetable',
          ),
        ],
      );

      return cropped?.path;
    } catch (e) {
      debugPrint("Crop failed: $e");
      return null;
    }
  }

  /// Enhances the image for "Scanned" look (Grayscale + High Contrast).
  /// Returns path to the processed file.
  Future<String> enhanceImage(String inputPath) async {
    try {
      if (inputPath.isEmpty) return inputPath;

      // Use compute to offload heavy image processing
      final resultPath = await compute(_enhanceImageOnIsolate, inputPath);
      return resultPath ?? inputPath;
    } catch (e) {
      debugPrint("Enhance failed: $e");
      return inputPath; // Return original on failure
    }
  }

  void dispose() {
    _docScanner.close();
  }
}

/// Top-level function for isolate
Future<String?> _enhanceImageOnIsolate(String inputPath) async {
  try {
    final file = File(inputPath);
    if (!await file.exists()) return null;

    final bytes = await file.readAsBytes();
    final image = img.decodeImage(bytes);

    if (image == null) return null;

    // Apply Grayscale
    final grayscale = img.grayscale(image);

    // Increase contrast
    // Since 'adjustColor' might vary by version, we use standard logic if available
    // or fallback to simple pixel manipulation if needed.
    // Assuming image package v4.
    final enhanced = img.adjustColor(
      grayscale,
      contrast: 1.6, // Boost contrast heavily for document look
      brightness: 1.05, // Slight brightness boost
      saturation: 0.0, // Ensure no color
    );

    final tempDir = await getTemporaryDirectory();
    final destPath =
        '${tempDir.path}/enhanced_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(destPath).writeAsBytes(img.encodeJpg(enhanced, quality: 85));

    return destPath;
  } catch (e) {
    debugPrint("Isolate enhance error: $e");
    return null;
  }
}

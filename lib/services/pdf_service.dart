import 'dart:io';
// import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:uuid/uuid.dart';

class PdfService {
  /// Converts the first page of a PDF file to an image (PNG).
  /// Returns the path to the generated image file.
  Future<String?> convertPdfToImage(String pdfPath) async {
    try {
      final pdfFile = File(pdfPath);
      if (!await pdfFile.exists()) {
        debugPrint("PDF not found at $pdfPath");
        return null;
      }

      final bytes = await pdfFile.readAsBytes();
      final docsDir = await getApplicationDocumentsDirectory();

      // OPTIMIZED: Standard DPI (300) - Balanced for Performance
      // We only take the first page
      await for (final page in Printing.raster(bytes, dpi: 300)) {
        final uniqueId = const Uuid().v4();
        final targetPath = '${docsDir.path}/bunky_pdf_import_$uniqueId.png';
        final targetFile = File(targetPath);

        // Convert to PNG
        final pngBytes = await page.toPng();

        // Write to Stable Storage
        await targetFile.writeAsBytes(pngBytes, flush: true);

        // Verification
        if (await targetFile.exists()) {
          return targetFile.path;
        } else {
          debugPrint("Failed to verify image creation at $targetPath");
          return null;
        }
      }
    } catch (e) {
      debugPrint("Error converting PDF to image: $e");
    }
    return null;
  }
}

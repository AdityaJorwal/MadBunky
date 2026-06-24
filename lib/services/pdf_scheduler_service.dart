import 'dart:io';
// import 'dart:typed_data';

// import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For compute
import 'package:image/image.dart' as img;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'package:mad_bunky/models/models.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:uuid/uuid.dart';

import 'mega_schedule_parser.dart';

class PdfSchedulerService {
  final TextRecognizer _textRecognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  MegaScheduleParser? _megaParser;

  Future<ScheduleExtractionResult> processImage(
      String filePath, List<Subject> existingSubjects,
      {ScanOptions options = const ScanOptions(),
      List<String>? selectedBatches,
      List<String>? selectedPracticalBatches,
      List<String>? selectedClinicBatches,
      List<String>? knownTeachers,
      List<ClassSession>? history}) async {
    // Determine type and route accordingly
    if (filePath.toLowerCase().endsWith('.pdf')) {
      return _processPdfFile(filePath, existingSubjects,
          options: options,
          selectedBatches: selectedBatches,
          selectedPracticalBatches: selectedPracticalBatches,
          selectedClinicBatches: selectedClinicBatches,
          knownTeachers: knownTeachers,
          history: history);
    } else {
      // For single image files (JPG/PNG), we still need robust handling
      // but we'll use the direct parser pipeline
      return _processSingleImageFile(filePath, existingSubjects,
          options: options,
          selectedBatches: selectedBatches,
          selectedPracticalBatches: selectedPracticalBatches,
          selectedClinicBatches: selectedClinicBatches,
          knownTeachers: knownTeachers,
          history: history);
    }
  }

  // ---------------------------------------------------------------------------
  // PIPELINE 1: PDF PROCESSING (The Critical Path)
  // ---------------------------------------------------------------------------
  Future<ScheduleExtractionResult> _processPdfFile(
      String pdfPath, List<Subject> existingSubjects,
      {ScanOptions options = const ScanOptions(),
      List<String>? selectedBatches,
      List<String>? selectedPracticalBatches,
      List<String>? selectedClinicBatches,
      List<String>? knownTeachers,
      List<ClassSession>? history}) async {
    List<ClassSession> allSessions = [];
    String? instituteName;
    Set<String> allDetectedBatches = {};
    Set<String> allPracticalBatches = {};
    Set<String> allClinicBatches = {};
    List<String> logs = [];

    logs.add("--- PDF PIPELINE START ---");
    logs.add("Source: $pdfPath");

    try {
      final pdfFile = File(pdfPath);
      if (!await pdfFile.exists()) {
        return ScheduleExtractionResult(
            sessions: [],
            debugLogs: ["CRITICAL: Input PDF not found at $pdfPath"]);
      }

      final bytes = await pdfFile.readAsBytes();
      logs.add("PDF loaded: ${bytes.length} bytes");

      // Stable Storage: Application Documents Directory
      final docsDir = await getApplicationDocumentsDirectory();
      logs.add("Storage Root: ${docsDir.path}");

      int pageIndex = 1;

      // OPTIMIZED: Standard DPI (300) - Balanced for Performance
      await for (final page in Printing.raster(bytes, dpi: 300)) {
        final uniqueId = const Uuid().v4();
        // Construct ABSOLUTE path
        final targetPath =
            '${docsDir.path}/bunky_page_${pageIndex}_$uniqueId.png';
        final targetFile = File(targetPath);

        logs.add(">>> Processing Page $pageIndex");

        try {
          // 1. Convert to PNG
          var pngBytes = await page.toPng();

          if (pngBytes.length < 100) {
            logs.add("WARN: Page $pageIndex yielded empty bytes. Skipping.");
            continue;
          }

          // INTELLIGENT POST-PROCESSING: THICKEN LINES
          if (options.useLineEnhancement) {
            try {
              final sw = Stopwatch()..start();
              pngBytes = await compute(enhanceTableLines, pngBytes);
              logs.add("Image Enhanced in ${sw.elapsedMilliseconds}ms");
            } catch (e) {
              logs.add("WARN: Image enhancement failed: $e");
            }
          } else {
            logs.add("Line enhancement disabled by user.");
          }

          // 2. Write to Stable Storage (FLUSH = TRUE)
          if (await targetFile.exists()) {
            await targetFile.delete(); // Ensure clean slate
          }
          await targetFile.writeAsBytes(pngBytes, flush: true);

          // 3. MANDATORY SETTLING DELAY
          // Give the filesystem time to commit the inode
          await Future.delayed(const Duration(milliseconds: 250));

          // 4. Verify Physical Existence
          if (!await targetFile.exists()) {
            logs.add(
                "CRITICAL ERROR: File wrote successfully but strict exists() check failed: $targetPath");
            // Last ditch: try to just use it anyway? No, safer to fail for this page.
            continue;
          }

          final fileSize = await targetFile.length();
          logs.add(
              "File Verified: ${targetFile.absolute.path} ($fileSize bytes)");

          // 5. Create InputImage from ABSOLUTE path
          final inputImage = InputImage.fromFilePath(targetFile.absolute.path);

          // 6. Perform OCR (The danger zone)
          final recognizedText = await _textRecognizer.processImage(inputImage);
          logs.add(
              "OCR Success: Found ${recognizedText.blocks.length} text blocks");

          // 7. Parse Text
          _megaParser ??= MegaScheduleParser(existingSubjects);

          // Detect batches (if needed for selection logic)
          final batchGroups = _megaParser!.detectBatchGroups(recognizedText);
          final detectedBatches = {
            ...batchGroups['practicals']!,
            ...batchGroups['clinics']!
          };
          if (detectedBatches.isNotEmpty && selectedBatches == null) {
            allDetectedBatches.addAll(detectedBatches);
            allPracticalBatches.addAll(batchGroups['practicals']!);
            allClinicBatches.addAll(batchGroups['clinics']!);
          }

          final parseResult = await _megaParser!.parse(recognizedText,
              selectedBatches: selectedBatches,
              selectedPracticalBatches: selectedPracticalBatches,
              selectedClinicBatches: selectedClinicBatches,
              knownTeachers: knownTeachers,
              history: history,
              useGridAnalysis: options.useGridAnalysis);

          // 8. Accumulate Results
          logs.addAll(parseResult.debugLogs);
          allSessions.addAll(parseResult.sessions);
          instituteName ??= parseResult.instituteName;
        } catch (e, stack) {
          logs.add("ERROR on Page $pageIndex: $e");
          logs.add(stack.toString());
        } finally {
          // 9. CLEANUP (Safe Delete)
          // Only delete after we are 100% done with this file iteration
          try {
            if (await targetFile.exists()) {
              await targetFile.delete();
              logs.add("Cleaned up temp file.");
            }
          } catch (e) {
            logs.add("WARN: Failed to cleanup file: $e");
          }
        }

        pageIndex++;
      }
    } catch (e) {
      logs.add("CRITICAL PIPELINE FAILURE: $e");
    }

    // EARLY RETURN logic for Batches (User Selection needed)
    if (allDetectedBatches.isNotEmpty && selectedBatches == null) {
      logs.add("Halting: User needs to select batches.");
      return ScheduleExtractionResult(
          sessions: [],
          instituteName: "Detected Grid",
          availableBatches: allDetectedBatches,
          practicalBatches: allPracticalBatches,
          clinicBatches: allClinicBatches,
          debugLogs: logs);
    }

    return ScheduleExtractionResult(
        sessions: allSessions, instituteName: instituteName, debugLogs: logs);
  }

  // ---------------------------------------------------------------------------
  // PIPELINE 2: SINGLE IMAGE (Legacy/Gallery Support)
  // ---------------------------------------------------------------------------
  Future<ScheduleExtractionResult> _processSingleImageFile(
      String filePath, List<Subject> existingSubjects,
      {ScanOptions options = const ScanOptions(),
      List<String>? selectedBatches,
      List<String>? selectedPracticalBatches,
      List<String>? selectedClinicBatches,
      List<String>? knownTeachers,
      List<ClassSession>? history}) async {
    // For single images, we treat them as ALREADY persistent (gallery/camera),
    // but just in case they are temp files, we verify them.

    List<String> logs = ["--- SINGLE IMAGE PIPELINE ---", "File: $filePath"];

    try {
      final file = File(filePath);

      // Robust verify before assuming failure
      if (!await file.exists()) {
        // Give it a tiny moment if it was just written
        await Future.delayed(const Duration(milliseconds: 200));
        if (!await file.exists()) {
          return ScheduleExtractionResult(sessions: [], debugLogs: [
            "ERROR: Input file does not exist (persistent): $filePath"
          ]);
        }
      }

      logs.add("File exists. Size: ${await file.length()} bytes");

      final inputImage = InputImage.fromFilePath(file.absolute.path);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      _megaParser ??= MegaScheduleParser(existingSubjects);

      final batchGroups = _megaParser!.detectBatchGroups(recognizedText);
      final detectedBatches = {
        ...batchGroups['practicals']!,
        ...batchGroups['clinics']!
      };
      if (detectedBatches.isNotEmpty && selectedBatches == null) {
        logs.add("Batches detected, requesting user selection.");
        return ScheduleExtractionResult(
            sessions: [],
            instituteName: "Standard Grid",
            availableBatches: detectedBatches,
            practicalBatches: batchGroups['practicals']!,
            clinicBatches: batchGroups['clinics']!,
            debugLogs: logs);
      }

      final result = await _megaParser!.parse(recognizedText,
          selectedBatches: selectedBatches,
          selectedPracticalBatches: selectedPracticalBatches,
          selectedClinicBatches: selectedClinicBatches,
          knownTeachers: knownTeachers,
          history: history,
          useGridAnalysis: options.useGridAnalysis);

      logs.addAll(result.debugLogs);

      return ScheduleExtractionResult(
          sessions: result.sessions,
          instituteName: result.instituteName,
          debugLogs: logs);
    } catch (e, stack) {
      logs.add("CRITICAL SINGLE FILE ERROR: $e");
      logs.add(stack.toString());
      return ScheduleExtractionResult(sessions: [], debugLogs: logs);
    }
  }

  // Helper for direct conversions if needed elsewhere
  Future<List<String>> convertPdfToImages(String filePath,
      {ScanOptions options = const ScanOptions()}) async {
    final docsDir = await getApplicationDocumentsDirectory();
    if (!await docsDir.exists()) {
      await docsDir.create(recursive: true);
    }
    List<String> paths = [];
    final file = File(filePath);

    if (!await file.exists()) {
      return [];
    }

    final bytes = await file.readAsBytes();
    int i = 0;

    // Unique Session ID for this batch of images to prevent collisions
    final batchId = const Uuid().v4();

    // OPTIMIZED: Standard DPI (300) - Balanced for Performance
    await for (final page in Printing.raster(bytes, dpi: 300)) {
      // Use Unique Filename to avoid race conditions or overwrites
      final fileName = 'bunky_legacy_${batchId}_page_$i.png';
      final path = '${docsDir.path}/$fileName';
      final targetFile = File(path);

      // Clean start (though UUID guarantees newness usually)
      if (await targetFile.exists()) {
        await targetFile.delete();
      }

      // Write with Flush to force filesystem sync
      var pngBytes = await page.toPng();

      // OPTIMIZATION: Thicken Lines Here too
      if (options.useLineEnhancement) {
        try {
          pngBytes = await compute(enhanceTableLines, pngBytes);
        } catch (e) {
          debugPrint("Enhancement error in convertPdfToImages: $e");
        }
      }

      await targetFile.writeAsBytes(pngBytes, flush: true);

      // Mandatory delay for filesystem consistently (Android Scoped Storage)
      await Future.delayed(const Duration(milliseconds: 150));

      // Robust Verification Loop
      bool exists = await targetFile.exists();
      int retries = 0;
      while (!exists && retries < 3) {
        await Future.delayed(const Duration(milliseconds: 200));
        exists = await targetFile.exists();
        retries++;
      }

      if (exists) {
        paths.add(targetFile.absolute.path);
        // debugPrint("Generated Page $i: ${targetFile.absolute.path} (${pngBytes.length} bytes)");
      } else {
        // Log critical failure but continue to try other pages
        // debugPrint("CRITICAL: Failed to verify file creation: $path");
      }

      i++;
    }
    return paths;
  }

  void dispose() {
    _textRecognizer.close();
  }
}

/// CORE ALGORITHM: Segment Stitching Line Detection (Max Accuracy)
/// 1. Scans for dark pixels (high sensitivity).
/// 2. Stitches collinear segments together if gaps are small (handling broken lines).
/// 3. Filters short segments to avoid text.
/// 4. Thickens identified lines significantly.
Uint8List enhanceTableLines(Uint8List inputBytes) {
  final image = img.decodePng(inputBytes);
  if (image == null) return inputBytes;

  // Parameters: Projection-Based Grid Synthesis
  // Goal: Reconstruct the global table grid "Behind" the text.

  const double scale = 300 / 300;
  final int w = image.width;
  final int h = image.height;

  // 1. ANALYSIS: Filter Text (< 50px)
  final int minFeatureSize = (50 * scale).round();
  const int darkThreshold = 240;
  final int thickness = (3 * scale).round();

  // Store segments: [pos, start, end]
  // pos = Y for horizontal, X for vertical
  List<List<int>> horizontalSegments = [];
  List<List<int>> verticalSegments = [];

  // Helper: Extract segments from a scanline
  void extractSegments(
      int limit, int fixed, bool isHorizontal, List<List<int>> storage) {
    int start = -1;
    for (int i = 0; i < limit; i++) {
      final p =
          isHorizontal ? image.getPixel(i, fixed) : image.getPixel(fixed, i);

      if (p.luminance < darkThreshold) {
        if (start == -1) start = i;
      } else {
        if (start != -1) {
          // Feature found. Filter it.
          if ((i - start) > minFeatureSize) {
            storage.add([fixed, start, i]);
          }
          start = -1;
        }
      }
    }
    if (start != -1 && (limit - start) > minFeatureSize) {
      storage.add([fixed, start, limit]);
    }
  }

  // Scan Horizontal
  for (int y = 0; y < h; y++) {
    extractSegments(w, y, true, horizontalSegments);
  }
  // Scan Vertical
  for (int x = 0; x < w; x++) {
    extractSegments(h, x, false, verticalSegments);
  }

  // 2. CLUSTERING & SYNTHESIS (The "Smart" Part)

  // Helper: Synthesize Global Lines from segments
  List<List<int>> synthesizeLines(
      List<List<int>> raw, int limit, bool isHorizontal) {
    if (raw.isEmpty) return [];

    // Sort by position (Y or X)
    raw.sort((a, b) => a[0].compareTo(b[0]));

    List<List<int>> synthesized = [];
    List<List<int>> cluster = [raw.first];

    // Dynamic Clustering Tolerance ( Jitter )
    const int jitter = 3;

    void processCluster() {
      if (cluster.isEmpty) return;

      // A. Calculate Cluster Stats
      double avgPos = 0;
      int minStart = 999999;
      int maxEnd = -1;

      for (var s in cluster) {
        avgPos += s[0];
        if (s[1] < minStart) minStart = s[1];
        if (s[2] > maxEnd) maxEnd = s[2];
      }
      int finalPos = (avgPos / cluster.length).round();
      int span = maxEnd - minStart;

      // B. RECONSTRUCTION LOGIC
      if (isHorizontal) {
        // Rule: If Horizontal Cluster spans > 30% of page -> FORCE FULL WIDTH
        if (span > (limit * 0.30)) {
          synthesized.add([finalPos, 0, limit]); // Edge-to-Edge
        } else {
          // Keep merged partial line
          synthesized.add([finalPos, minStart, maxEnd]);
        }
      } else {
        // Rule: Vertical -> Just merge/bridge (don't force full height usually)
        // We could extend column lines if they are very long (> 50% height)
        if (span > (limit * 0.50)) {
          synthesized.add([finalPos, minStart, maxEnd]);
        } else {
          // For shorter vertical bits, we might want to keep them or Drop if they are too isolated?
          // Let's keep them merged.
          synthesized.add([finalPos, minStart, maxEnd]);
        }
      }
    }

    for (int i = 1; i < raw.length; i++) {
      final curr = raw[i];
      final prev = cluster.last;

      if ((curr[0] - prev[0]).abs() <= jitter) {
        cluster.add(curr);
      } else {
        processCluster();
        cluster = [curr];
      }
    }
    processCluster(); // Last one

    return synthesized;
  }

  final finalH = synthesizeLines(horizontalSegments, w, true);
  final finalV = synthesizeLines(verticalSegments, h, false);

  // 3. SAFE RENDERING (Behind-Text Mode)
  // Only draw if pixel is currently WHITE (background). Never overwrite DARK (text).

  void drawSafeLine(int start, int end, int fixed, bool isHorizontal) {
    int tStart = fixed - (thickness ~/ 2);
    int tEnd = tStart + thickness;

    for (int t = tStart; t < tEnd; t++) {
      for (int i = start; i < end; i++) {
        int x = isHorizontal ? i : t;
        int y = isHorizontal ? t : i;

        if (x >= 0 && x < w && y >= 0 && y < h) {
          final p = image.getPixel(x, y);
          // SAFE CHECK: Only darken if it's NOT already dark (Text)
          // Threshold: If luminance > 200 (Paper), make it black.
          // If luminance < 200 (Text/Ink), Leave it alone!
          if (p.luminance > 200) {
            image.setPixelRgb(x, y, 0, 0, 0);
          }
        }
      }
    }
  }

  // Draw Horizontal
  for (var line in finalH) {
    drawSafeLine(line[1], line[2], line[0], true);
  }
  // Draw Vertical
  for (var line in finalV) {
    drawSafeLine(line[1], line[2], line[0], false);
  }

  return img.encodePng(image);
}

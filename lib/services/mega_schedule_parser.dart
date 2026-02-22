import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:mad_bunky/models/models.dart';

class MegaScheduleParser {
  MegaScheduleParser(List<dynamic> existingSubjects);

  Map<String, Set<String>> detectBatchGroups(RecognizedText recognizedText) {
    return {'practicals': {}, 'clinics': {}};
  }

  Future<ScheduleExtractionResult> parse(
    RecognizedText recognizedText, {
    List<String>? selectedBatches,
    List<String>? selectedPracticalBatches,
    List<String>? selectedClinicBatches,
    List<String>? knownTeachers,
    List<ClassSession>? history,
    bool useGridAnalysis = false,
  }) async {
    return ScheduleExtractionResult(sessions: [], debugLogs: []);
  }
}

class ScheduleExtractionResult {
  final List<ClassSession> sessions;
  final String? instituteName;
  final String? dateRange;
  final String? standardInfo;
  final Set<String> availableBatches;
  final Set<String> practicalBatches;
  final Set<String> clinicBatches;
  final List<String> debugLogs;

  ScheduleExtractionResult(
      {required this.sessions,
      this.instituteName,
      this.dateRange,
      this.standardInfo,
      this.availableBatches = const {},
      this.practicalBatches = const {},
      this.clinicBatches = const {},
      this.debugLogs = const []});
}

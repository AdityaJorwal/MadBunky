import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:http/http.dart' as http;

class GoogleDriveService {
  final GoogleSignIn _googleSignIn;

  GoogleDriveService(this._googleSignIn);

  GoogleSignInAccount? get currentUser =>
      _googleSignIn.currentUser; // Added public getter

  /// Get authenticated HTTP client
  Future<http.Client?> get _httpClient async {
    return await _googleSignIn.authenticatedClient();
  }

  /// List backups in App Data Folder
  Future<List<drive.File>> listBackups() async {
    final client = await _httpClient;
    if (client == null) return [];

    final driveApi = drive.DriveApi(client);
    try {
      final fileList = await driveApi.files.list(
        spaces: 'appDataFolder',
        q: "mimeType = 'application/json' and trashed = false", // Only list JSON files we uploaded
        $fields: 'files(id, name, createdTime, size)',
      );
      return fileList.files ?? [];
    } catch (e) {
      debugPrint("GoogleDriveService: Error listing files: $e");
      return [];
    }
  }

  /// Upload backup file
  /// Returns file ID on success
  Future<String?> uploadBackup(String fileName, String content) async {
    final client = await _httpClient;
    if (client == null) return null;

    final driveApi = drive.DriveApi(client);
    try {
      // 1. Create File Metadata
      final fileToUpload = drive.File();
      fileToUpload.name = fileName;
      fileToUpload.parents = ['appDataFolder']; // Crucial: Hidden App Data
      fileToUpload.mimeType = 'application/json';

      // 2. Create Media
      final bytes = utf8.encode(content);
      final media = drive.Media(
        Stream.fromIterable([bytes]),
        bytes.length,
      );

      // 3. Upload
      final result = await driveApi.files.create(
        fileToUpload,
        uploadMedia: media,
      );

      debugPrint("GoogleDriveService: Uploaded $fileName (ID: ${result.id})");
      return result.id;
    } catch (e) {
      debugPrint("GoogleDriveService: Error uploading file: $e");
      rethrow;
    }
  }

  /// Download backup file content
  Future<String?> downloadBackup(String fileId) async {
    final client = await _httpClient;
    if (client == null) return null;

    final driveApi = drive.DriveApi(client);
    try {
      final media = await driveApi.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final List<int> dataStore = [];
      await for (final data in media.stream) {
        dataStore.addAll(data);
      }
      return utf8.decode(dataStore);
    } catch (e) {
      debugPrint("GoogleDriveService: Error downloading file: $e");
      rethrow;
    }
  }

  /// Delete a backup file
  Future<void> deleteFile(String fileId) async {
    final client = await _httpClient;
    if (client == null) return;

    final driveApi = drive.DriveApi(client);
    try {
      await driveApi.files.delete(fileId);
      debugPrint("GoogleDriveService: Deleted file $fileId");
    } catch (e) {
      debugPrint("GoogleDriveService: Error deleting file: $e");
    }
  }
}

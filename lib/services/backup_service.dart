import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:crypto/crypto.dart';
import '../services/google_drive_service.dart';

class BackupService {
  final GoogleDriveService _driveService;
  final SharedPreferences _prefs;
  Timer? _debounceTimer;

  static const String _backupFilename = 'madbunky_backup.json';
  // Static secret salt - in a real app, use a more secure method or user password.
  // Using a hardcoded salt + user email allows determining the key deterministically on a new device.
  static const String _staticSalt = 'madbunky_secure_salt_v1';

  BackupService(this._driveService, this._prefs);

  /// Keys to backup
  static const List<String> _keysToBackup = [
    'subjects',
    'groups',
    'schedule',
    'sessions',
    'userName',
    'userInstitute',
    'themeMode',
    'themePreset',
    'useMaterialYou',
    'showCalendar',
    'enableNotifications',
    'enableSmartBunking',
    'enableGeofence',
    'enableWifiTrigger',
    'enableHolidayAwareness',
    'enableLiveActivity',
    'enableClassAlerts',
    'enableSilentNotifications',
    'campusSsids',
    'campusLocations',
    'customThemeColor',
    'syncServiceEnabled',
    'enableBackgroundStatusNotification',
    'enableGeofenceAlerts',
    'enableBatterySaver',
    'autoSyncGoogleCalendar',
    'isNeon',
  ];

  /// Generate Encryption Key based on user email
  encrypt.Key _generateKey(String email) {
    final bytes = utf8.encode(email + _staticSalt);
    final digest = sha256.convert(bytes);
    return encrypt.Key(Uint8List.fromList(digest.bytes));
  }

  /// Trigger Auto Backup (Debounced)
  void triggerAutoBackup() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(minutes: 1), () async {
      final autoSync = _prefs.getBool('enableAutoBackup') ??
          false; // Check setting manually here or pass it
      if (autoSync) {
        debugPrint("BackupService: Auto-Backup triggering...");
        try {
          await createBackup();
          // Update last backup time? UI might need to know.
          // We can save 'lastBackupTime' to prefs too, but don't loop backup!
          await _prefs.setString(
              'lastBackupTime', DateTime.now().toIso8601String());
        } catch (e) {
          debugPrint("BackupService: Auto-Backup failed: $e");
        }
      }
    });
  }

  /// Create and Upload Backup
  Future<void> createBackup() async {
    final currentUser = _driveService.currentUser;
    if (currentUser == null) throw Exception("User not signed in");

    // 1. Collect Data
    final Map<String, dynamic> backupData = {};
    for (var key in _keysToBackup) {
      if (_prefs.containsKey(key)) {
        backupData[key] = _prefs.get(key);
      }
    }

    final String jsonString = jsonEncode({
      'version': 1,
      'timestamp': DateTime.now().toIso8601String(),
      'device': 'Android', // Metadata
      'data': backupData,
    });

    // 2. Encrypt
    final key = _generateKey(currentUser.email);
    final iv = encrypt.IV.fromLength(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));

    final encrypted = encrypter.encrypt(jsonString, iv: iv);
    // Combine IV and Ciphertext for storage: IV + Ciphertext
    // We assume Base64 encoding.
    // Format: "IV_BASE64:CIPHERTEXT_BASE64"
    final encryptedPayload = "${iv.base64}:${encrypted.base64}";

    // 3. Upload (Create new file, optionally delete old ones later)
    // For simplicity, we just create a new one. We can list and delete old ones to keep it clean.
    await _deleteOldBackups(); // Clean up first/after?
    await _driveService.uploadBackup(_backupFilename, encryptedPayload);
  }

  /// Restore from Backup
  Future<void> restoreBackup(String fileId) async {
    final currentUser = _driveService.currentUser;
    if (currentUser == null) throw Exception("User not signed in");

    // 1. Download
    final encryptedPayload = await _driveService.downloadBackup(fileId);
    if (encryptedPayload == null) throw Exception("Failed to download file");

    // 2. Decrypt
    try {
      final parts = encryptedPayload.split(':');
      if (parts.length != 2) throw Exception("Invalid backup format");

      final iv = encrypt.IV.fromBase64(parts[0]);
      final key = _generateKey(currentUser.email);
      final encrypter = encrypt.Encrypter(encrypt.AES(key));

      final decrypted = encrypter.decrypt64(parts[1], iv: iv);
      final Map<String, dynamic> root = jsonDecode(decrypted);
      final Map<String, dynamic> data = root['data'];

      // 3. Restore to Prefs
      for (var key in data.keys) {
        final value = data[key];
        if (value is String) {
          await _prefs.setString(key, value);
        } else if (value is int) {
          await _prefs.setInt(key, value);
        } else if (value is bool) {
          await _prefs.setBool(key, value);
        } else if (value is double) {
          await _prefs.setDouble(key, value);
        } else if (value is List) {
          // getStringList support
          await _prefs.setStringList(key, List<String>.from(value));
        }
      }

      debugPrint("BackupService: Restore complete.");
    } catch (e) {
      debugPrint("BackupService: Restore failed/Decryption error: $e");
      throw Exception(
          "Failed to decrypt or parse backup. Wrong account or corrupted file.");
    }
  }

  /// Helper to delete old backups, keeping only the latest 1 or 2
  Future<void> _deleteOldBackups() async {
    try {
      final files = await _driveService.listBackups();
      // Sort by createdTime desc
      // files from API usually have createdTime String. We need to parse/sort?
      // Drive API list ordering might not be guaranteed unless requested.
      // We can just keep it simple: if there are ANY files with name _backupFilename, delete them all before uploading new one?
      // Or safer: create new, then delete old.

      // Let's just delete all previous backups with our filename to avoid clutter.
      // This is "single slot" backup.
      final myBackups = files.where((f) => f.name == _backupFilename).toList();
      for (var f in myBackups) {
        if (f.id != null) {
          await _driveService.deleteFile(f.id!);
        }
      }
    } catch (e) {
      debugPrint("BackupService: Error cleaning old backups: $e");
    }
  }
}

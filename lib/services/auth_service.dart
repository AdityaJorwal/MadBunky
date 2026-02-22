import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SharedPreferences _prefs;

  AuthService(this._prefs);

  // Initialize GoogleSignIn.
  // Note: If you need to share instances with GoogleCalendarService,
  // you might need to coordinate scopes. For now, using default.
  // Initialize GoogleSignIn with Calendar scopes.
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'https://www.googleapis.com/auth/calendar.readonly',
      'https://www.googleapis.com/auth/drive.appdata',
    ],
  );

  GoogleSignIn get googleSignIn => _googleSignIn;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  /// Signs in with Google and Firebase.
  /// Returns the signed-in User or null if canceled/failed.
  Future<User?> signInWithGoogle() async {
    try {
      // 1. Trigger Google Sign In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User canceled the sign-in
        return null;
      }

      // 2. Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // 3. Create a new credential
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4. Sign in to Firebase with the credential
      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);

      // Persist intent
      await persistAuthType('google');

      return userCredential.user;
    } catch (e) {
      if (kDebugMode) {
        print("Error signing in with Google: $e");
      }
      rethrow;
    }
  }

  /// Signs out from both Firebase and Google.
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
      await clearAuthType();
    } catch (e) {
      if (kDebugMode) {
        print("Error signing out: $e");
      }
      rethrow;
    }
  }

  /// Signs in anonymously (Guest Mode).
  Future<User?> signInAnonymously() async {
    try {
      final UserCredential userCredential = await _auth.signInAnonymously();
      await persistAuthType('guest');
      return userCredential.user;
    } catch (e) {
      if (kDebugMode) {
        print("Error signing in anonymously: $e");
      }
      rethrow;
    }
  }

  // --- Persistence Helpers ---

  Future<void> persistAuthType(String type) async {
    await _prefs.setString('auth_type', type);
  }

  Future<void> clearAuthType() async {
    await _prefs.remove('auth_type');
  }

  Future<void> restoreSession() async {
    final type = _prefs.getString('auth_type');
    if (type == 'guest') {
      if (_auth.currentUser == null) {
        debugPrint("AuthService: Restoring Guest Session...");
        await signInAnonymously();
      }
    } else if (type == 'google') {
      if (_auth.currentUser == null) {
        debugPrint("AuthService: Restoring Google Session...");
        // Attempt silent sign-in; this updates currentUser stream
        final googleUser = await _googleSignIn.signInSilently();

        if (googleUser != null) {
          final GoogleSignInAuthentication googleAuth =
              await googleUser.authentication;
          final OAuthCredential credential = GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          );
          await _auth.signInWithCredential(credential);
          debugPrint(
              "AuthService: Firebase Session Restored via Google Silent Sign-in");
        }
      }
    }
  }
}

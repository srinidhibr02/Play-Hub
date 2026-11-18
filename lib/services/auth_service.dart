import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Thin wrapper around Firebase Auth (email/password and Google).
class AuthService {
  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  // Same OAuth client the app already used for Google sign-in.
  static const String _googleClientId =
      '371130915379-54ket1adu7iqt2lqdoh4oqhvi3fedlnj.apps.googleusercontent.com';

  static bool _googleReady = false;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> registerWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await credential.user?.updateDisplayName(name);
    await credential.user?.reload();
  }

  Future<void> sendPasswordReset(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  /// Returns normally if the user cancels the Google dialog.
  Future<void> signInWithGoogle() async {
    if (kIsWeb) {
      await _auth.signInWithPopup(GoogleAuthProvider());
      return;
    }

    try {
      if (!_googleReady) {
        await GoogleSignIn.instance.initialize(clientId: _googleClientId);
        _googleReady = true;
      }
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      await _auth.signInWithCredential(credential);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return;
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      if (!kIsWeb && _googleReady) {
        await GoogleSignIn.instance.signOut();
      }
    } catch (_) {
      // Signing out of Google is best effort.
    }
    await _auth.signOut();
  }

  /// Turns an error from the methods above into something a person can read.
  static String friendlyError(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return 'That email address does not look right.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Email or password is incorrect.';
        case 'email-already-in-use':
          return 'An account with this email already exists. Try signing in.';
        case 'weak-password':
          return 'Choose a stronger password (at least 6 characters).';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'too-many-requests':
          return 'Too many attempts. Please wait a moment and try again.';
        case 'network-request-failed':
          return 'No internet connection. Check your network and retry.';
        default:
          return error.message ?? 'Something went wrong. Please try again.';
      }
    }
    if (error is GoogleSignInException) {
      return 'Google sign-in failed. Please try again.';
    }
    return 'Something went wrong. Please try again.';
  }
}

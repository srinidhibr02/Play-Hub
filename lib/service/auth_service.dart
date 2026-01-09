import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:play_hub/constants/constants.dart';
import 'package:play_hub/helpers/error_messages.dart';

class AuthService {
  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;
  String? get currentUserEmailId => _auth.currentUser?.email;
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  bool get isLoggedIn => _auth.currentUser != null;

  // Google Sign-In current user
  GoogleSignInAccount? _currentGoogleUser;
  bool _isAuthorized = false;

  GoogleSignInAccount? get currentGoogleUser => _currentGoogleUser;
  bool get isAuthorized => _isAuthorized;

  // ==================== REGISTER ====================
  Future<AuthResult> registerWithEmail({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        return AuthResult(
          success: false,
          message: 'Failed to create user account',
        );
      }

      await user.updateDisplayName(fullName);

      await _firestore.collection('users').doc(user.email).set({
        'uid': user.uid,
        'email': email,
        'fullName': fullName,
        'phoneNumber': phoneNumber,
        'role': 'user',
        'profileImageUrl': '',
        'clubMemberships': [],
        'hostedTournaments': [],
        'isActive': true,
        'loginMethod': 'email',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return AuthResult(
        success: true,
        message: 'Registration successful!',
        user: user,
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult(success: false, message: getAuthErrorMessage(e.code));
    } catch (e, stack) {
      print('Register Error: $e');
      print('Stacktrace: $stack');
      return AuthResult(
        success: false,
        message: 'An unexpected error occurred. Please try again.',
      );
    }
  }

  // ==================== LOGIN ====================
  Future<AuthResult> loginWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update last login
      if (userCredential.user != null) {
        await _firestore
            .collection('users')
            .doc(userCredential.user!.email)
            .update({'updatedAt': FieldValue.serverTimestamp()});
      }

      return AuthResult(
        success: true,
        message: 'Login successful!',
        user: userCredential.user,
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult(success: false, message: getAuthErrorMessage(e.code));
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'An unexpected error occurred. Please try again.',
      );
    }
  }

  // ==================== LOGOUT ====================
  Future<void> logout() async {
    try {
      await Future.wait([
        _auth.signOut(),
        GoogleSignIn.instance.disconnect(), // Use disconnect to reset state
      ]);
      _currentGoogleUser = null;
      _isAuthorized = false;
    } catch (e) {
      print('Logout error: $e');
    }
  }

  // ==================== RESET PASSWORD ====================
  Future<AuthResult> resetPassword({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return AuthResult(
        success: true,
        message: 'Password reset email sent. Please check your inbox.',
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult(success: false, message: getAuthErrorMessage(e.code));
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Failed to send reset email. Please try again.',
      );
    }
  }

  // ==================== UPDATE PROFILE ====================
  Future<AuthResult> updateProfile({
    String? fullName,
    String? phoneNumber,
    String? profileImageUrl,
  }) async {
    try {
      final user = currentUser;
      if (user == null) {
        return AuthResult(
          success: false,
          message: 'No user is currently logged in',
        );
      }

      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (fullName != null) {
        await user.updateDisplayName(fullName);
        updates['fullName'] = fullName;
      }

      if (phoneNumber != null) {
        updates['phoneNumber'] = phoneNumber;
      }

      if (profileImageUrl != null) {
        updates['profileImageUrl'] = profileImageUrl;
      }

      await _firestore.collection('users').doc(user.email).update(updates);

      return AuthResult(
        success: true,
        message: 'Profile updated successfully',
        user: user,
      );
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Failed to update profile. Please try again.',
      );
    }
  }

  Future<Map<String, dynamic>?> getUserData(String email) async {
    try {
      final doc = await _firestore.collection('users').doc(email).get();
      return doc.data();
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getCurrentUserData() async {
    final uid = currentUserEmailId;
    if (uid == null) return null;
    return getUserData(uid);
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>>? streamUserData(
    String emailId,
  ) {
    try {
      return _firestore.collection('users').doc(emailId).snapshots();
    } catch (e) {
      return null;
    }
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>>? streamCurrentUserData() {
    final uid = currentUserEmailId;
    if (uid == null) return null;
    return streamUserData(uid);
  }

  // ==================== DELETE ACCOUNT ====================
  Future<AuthResult> deleteAccount() async {
    try {
      final user = currentUser;
      if (user == null) {
        return AuthResult(
          success: false,
          message: 'No user is currently logged in',
        );
      }

      // Delete user document
      await _firestore.collection('users').doc(user.email).delete();

      // Sign out from Google if signed in
      if (_currentGoogleUser != null) {
        await GoogleSignIn.instance.disconnect();
      }

      // Delete auth account
      await user.delete();

      return AuthResult(success: true, message: 'Account deleted successfully');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        return AuthResult(
          success: false,
          message: 'Please log in again before deleting your account',
        );
      }
      return AuthResult(success: false, message: getAuthErrorMessage(e.code));
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Failed to delete account. Please try again.',
      );
    }
  }

  // ==================== REAUTHENTICATE ====================
  Future<AuthResult> reauthenticateWithPassword(String password) async {
    try {
      final user = currentUser;
      if (user == null || user.email == null) {
        return AuthResult(
          success: false,
          message: 'No user is currently logged in',
        );
      }

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );

      await user.reauthenticateWithCredential(credential);

      return AuthResult(success: true, message: 'Reauthentication successful');
    } on FirebaseAuthException catch (e) {
      return AuthResult(success: false, message: getAuthErrorMessage(e.code));
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Reauthentication failed. Please try again.',
      );
    }
  }

  // ==================== CHANGE PASSWORD ====================
  Future<AuthResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      // First reauthenticate
      final reauth = await reauthenticateWithPassword(currentPassword);
      if (!reauth.success) {
        return reauth;
      }

      // Then update password
      await currentUser?.updatePassword(newPassword);

      return AuthResult(
        success: true,
        message: 'Password changed successfully',
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult(success: false, message: getAuthErrorMessage(e.code));
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Failed to change password. Please try again.',
      );
    }
  }
}

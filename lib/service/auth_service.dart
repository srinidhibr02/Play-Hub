import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AuthService {
  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Check if user is logged in
  bool get isLoggedIn => _auth.currentUser != null;

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

      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': email,
        'fullName': fullName,
        'phoneNumber': phoneNumber,
        'role': 'user',
        'profileImageUrl': '',
        'clubMemberships': [],
        'hostedTournaments': [],
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return AuthResult(
        success: true,
        message: 'Registration successful!',
        user: user,
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult(success: false, message: _getAuthErrorMessage(e.code));
    } catch (e, stack) {
      print('Register Error: $e');
      print('Stacktrace: $stack');
      return AuthResult(
        success: false,
        message: 'An unexpected error occurred. Please try again.',
      );
    }
  }

  Future<AuthResult> loginWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      return AuthResult(
        success: true,
        message: 'Login successful!',
        user: userCredential.user,
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult(success: false, message: _getAuthErrorMessage(e.code));
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
      await Future.wait([_auth.signOut()]);
    } catch (e) {
      // Silent fail - user will be logged out anyway
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
      return AuthResult(success: false, message: _getAuthErrorMessage(e.code));
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

      await _firestore.collection('users').doc(user.uid).update(updates);

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

  // ==================== GET USER DATA ====================
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.data();
    } catch (e) {
      return null;
    }
  }

  // ==================== GET CURRENT USER DATA ====================
  Future<Map<String, dynamic>?> getCurrentUserData() async {
    final uid = currentUserId;
    if (uid == null) return null;
    return getUserData(uid);
  }

  // ==================== STREAM USER DATA ====================
  Stream<DocumentSnapshot<Map<String, dynamic>>>? streamUserData(String uid) {
    try {
      return _firestore.collection('users').doc(uid).snapshots();
    } catch (e) {
      return null;
    }
  }

  // ==================== STREAM CURRENT USER DATA ====================
  Stream<DocumentSnapshot<Map<String, dynamic>>>? streamCurrentUserData() {
    final uid = currentUserId;
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
      await _firestore.collection('users').doc(user.uid).delete();

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
      return AuthResult(success: false, message: _getAuthErrorMessage(e.code));
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
      return AuthResult(success: false, message: _getAuthErrorMessage(e.code));
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
      return AuthResult(success: false, message: _getAuthErrorMessage(e.code));
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Failed to change password. Please try again.',
      );
    }
  }

  // ==================== ERROR MESSAGE HELPER ====================
  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'This email is already registered. Please login instead.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'operation-not-allowed':
        return 'This operation is not allowed. Please contact support.';
      case 'weak-password':
        return 'Password is too weak. Please use a stronger password.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'user-not-found':
        return 'No account found with this email. Please register first.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-credential':
        return 'Invalid credentials. Please check your email and password.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      case 'requires-recent-login':
        return 'Please log in again to complete this action.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }
}

// ==================== AUTH RESULT MODEL ====================
class AuthResult {
  final bool success;
  final String message;
  final User? user;

  AuthResult({required this.success, required this.message, this.user});

  @override
  String toString() {
    return 'AuthResult(success: $success, message: $message, user: ${user?.uid})';
  }
}

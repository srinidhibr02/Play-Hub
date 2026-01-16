import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:play_hub/constants/constants.dart';
import 'package:play_hub/helpers/error_messages.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Loading state
  final ValueNotifier<bool> isLoading = ValueNotifier<bool>(false);
  final ValueNotifier<String> loadingMessage = ValueNotifier<String>('');

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

  // Helper methods
  void _setLoading(bool value, {String message = ''}) {
    isLoading.value = value;
    loadingMessage.value = message;
    debugPrint('🔄 Loading: $value - $message');
  }

  void _logError(String method, String error, [StackTrace? stackTrace]) {
    debugPrint('❌ [$method] Error: $error');
    if (stackTrace != null) {
      debugPrint('Stack trace: $stackTrace');
    }
  }

  void _logSuccess(String method, String message) {
    debugPrint('✅ [$method] $message');
  }

  // ==================== REGISTER ====================
  Future<AuthResult> registerWithEmail({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
  }) async {
    try {
      _setLoading(true, message: 'Creating account...');
      debugPrint('📝 Registering user: $email');

      // Validate inputs
      if (email.isEmpty || password.isEmpty || fullName.isEmpty) {
        return AuthResult(
          success: false,
          message: 'Please fill in all required fields',
        );
      }

      if (password.length < 6) {
        return AuthResult(
          success: false,
          message: 'Password must be at least 6 characters',
        );
      }

      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        return AuthResult(
          success: false,
          message: 'Failed to create user account',
        );
      }

      _setLoading(true, message: 'Setting up profile...');

      await user.updateDisplayName(fullName);

      await _firestore.collection('users').doc(user.email).set({
        'uid': user.uid,
        'email': email.trim(),
        'fullName': fullName.trim(),
        'phoneNumber': phoneNumber.trim(),
        'role': 'user',
        'profileImageUrl': '',
        'clubMemberships': [],
        'hostedTournaments': [],
        'isActive': true,
        'loginMethod': 'email',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _logSuccess('registerWithEmail', 'User registered successfully: $email');
      _setLoading(false);

      return AuthResult(
        success: true,
        message: 'Registration successful!',
        user: user,
      );
    } on FirebaseAuthException catch (e) {
      _logError('registerWithEmail', 'Firebase Auth Error: ${e.code}');
      _setLoading(false);
      return AuthResult(success: false, message: getAuthErrorMessage(e.code));
    } catch (e, stack) {
      _logError('registerWithEmail', e.toString(), stack);
      _setLoading(false);
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
      _setLoading(true, message: 'Signing in...');
      debugPrint('🔐 Logging in user: $email');

      if (email.isEmpty || password.isEmpty) {
        return AuthResult(
          success: false,
          message: 'Email and password are required',
        );
      }

      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (userCredential.user != null) {
        _setLoading(true, message: 'Loading profile...');

        await _firestore
            .collection('users')
            .doc(userCredential.user!.email)
            .update({'updatedAt': FieldValue.serverTimestamp()});

        _logSuccess('loginWithEmail', 'User logged in: $email');
      }

      _setLoading(false);

      return AuthResult(
        success: true,
        message: 'Login successful!',
        user: userCredential.user,
      );
    } on FirebaseAuthException catch (e) {
      _logError('loginWithEmail', 'Firebase Auth Error: ${e.code}');
      _setLoading(false);
      return AuthResult(success: false, message: getAuthErrorMessage(e.code));
    } catch (e, stack) {
      _logError('loginWithEmail', e.toString(), stack);
      _setLoading(false);
      return AuthResult(
        success: false,
        message: 'An unexpected error occurred. Please try again.',
      );
    }
  }

  // ==================== LOGOUT ====================
  Future<void> logout() async {
    try {
      _setLoading(true, message: 'Signing out...');
      debugPrint('🚪 User logging out');

      await Future.wait([GoogleSignIn.instance.disconnect(), _auth.signOut()]);

      _currentGoogleUser = null;
      _isAuthorized = false;

      _logSuccess('logout', 'User logged out successfully');
      _setLoading(false);
    } catch (e, stack) {
      _logError('logout', e.toString(), stack);
      _setLoading(false);
    }
  }

  // ==================== RESET PASSWORD ====================
  Future<AuthResult> resetPassword({required String email}) async {
    try {
      _setLoading(true, message: 'Sending reset email...');
      debugPrint('📧 Resetting password for: $email');

      if (email.isEmpty) {
        return AuthResult(
          success: false,
          message: 'Please enter your email address',
        );
      }

      await _auth.sendPasswordResetEmail(email: email.trim());

      _logSuccess('resetPassword', 'Reset email sent to: $email');
      _setLoading(false);

      return AuthResult(
        success: true,
        message: 'Password reset email sent. Please check your inbox.',
      );
    } on FirebaseAuthException catch (e) {
      _logError('resetPassword', 'Firebase Auth Error: ${e.code}');
      _setLoading(false);
      return AuthResult(success: false, message: getAuthErrorMessage(e.code));
    } catch (e, stack) {
      _logError('resetPassword', e.toString(), stack);
      _setLoading(false);
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
      _setLoading(true, message: 'Updating profile...');
      debugPrint('👤 Updating user profile');

      final user = currentUser;
      if (user == null || user.email == null) {
        return AuthResult(
          success: false,
          message: 'No user is currently logged in',
        );
      }

      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (fullName != null && fullName.isNotEmpty) {
        await user.updateDisplayName(fullName.trim());
        updates['fullName'] = fullName.trim();
      }

      if (phoneNumber != null && phoneNumber.isNotEmpty) {
        updates['phoneNumber'] = phoneNumber.trim();
      }

      if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
        updates['profileImageUrl'] = profileImageUrl.trim();
      }

      await _firestore.collection('users').doc(user.email).update(updates);

      _logSuccess('updateProfile', 'Profile updated successfully');
      _setLoading(false);

      return AuthResult(
        success: true,
        message: 'Profile updated successfully',
        user: user,
      );
    } catch (e, stack) {
      _logError('updateProfile', e.toString(), stack);
      _setLoading(false);
      return AuthResult(
        success: false,
        message: 'Failed to update profile. Please try again.',
      );
    }
  }

  // ==================== GET USER DATA ====================
  Future<Map<String, dynamic>?> getUserData(String email) async {
    try {
      debugPrint('📂 Fetching user data for: $email');

      final doc = await _firestore.collection('users').doc(email).get();

      if (!doc.exists) {
        _logError('getUserData', 'User document not found: $email');
        return null;
      }

      _logSuccess('getUserData', 'User data fetched successfully');
      return doc.data();
    } catch (e, stack) {
      _logError('getUserData', e.toString(), stack);
      return null;
    }
  }

  Future<Map<String, dynamic>?> getCurrentUserData() async {
    final uid = currentUserEmailId;
    if (uid == null) {
      _logError('getCurrentUserData', 'No user logged in');
      return null;
    }
    return getUserData(uid);
  }

  // ==================== STREAM USER DATA ====================
  Stream<DocumentSnapshot<Map<String, dynamic>>>? streamUserData(
    String emailId,
  ) {
    try {
      debugPrint('📡 Streaming user data: $emailId');
      return _firestore.collection('users').doc(emailId).snapshots();
    } catch (e, stack) {
      _logError('streamUserData', e.toString(), stack);
      return null;
    }
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>>? streamCurrentUserData() {
    final uid = currentUserEmailId;
    if (uid == null) {
      _logError('streamCurrentUserData', 'No user logged in');
      return null;
    }
    return streamUserData(uid);
  }

  // ==================== DELETE ACCOUNT ====================
  Future<AuthResult> deleteAccount({required String password}) async {
    try {
      _setLoading(true, message: 'Deleting account...');
      debugPrint('🗑️ Deleting user account');

      final user = currentUser;
      if (user == null || user.email == null) {
        return AuthResult(
          success: false,
          message: 'No user is currently logged in',
        );
      }

      // Reauthenticate first
      _setLoading(true, message: 'Verifying identity...');
      final reauth = await reauthenticateWithPassword(password);
      if (!reauth.success) {
        _setLoading(false);
        return reauth;
      }

      _setLoading(true, message: 'Removing data...');

      // Delete user document
      await _firestore.collection('users').doc(user.email).delete();

      // Sign out from Google if signed in
      if (_currentGoogleUser != null) {
        await GoogleSignIn.instance.disconnect();
      }

      // Delete auth account
      await user.delete();

      _logSuccess('deleteAccount', 'Account deleted successfully');
      _setLoading(false);

      return AuthResult(success: true, message: 'Account deleted successfully');
    } on FirebaseAuthException catch (e) {
      _logError('deleteAccount', 'Firebase Auth Error: ${e.code}');
      _setLoading(false);

      if (e.code == 'requires-recent-login') {
        return AuthResult(
          success: false,
          message: 'Please log in again before deleting your account',
        );
      }
      return AuthResult(success: false, message: getAuthErrorMessage(e.code));
    } catch (e, stack) {
      _logError('deleteAccount', e.toString(), stack);
      _setLoading(false);
      return AuthResult(
        success: false,
        message: 'Failed to delete account. Please try again.',
      );
    }
  }

  // ==================== REAUTHENTICATE ====================
  Future<AuthResult> reauthenticateWithPassword(String password) async {
    try {
      debugPrint('🔑 Reauthenticating user');

      final user = currentUser;
      if (user == null || user.email == null) {
        return AuthResult(
          success: false,
          message: 'No user is currently logged in',
        );
      }

      if (password.isEmpty) {
        return AuthResult(success: false, message: 'Password is required');
      }

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );

      await user.reauthenticateWithCredential(credential);

      _logSuccess('reauthenticateWithPassword', 'Reauthentication successful');
      return AuthResult(success: true, message: 'Reauthentication successful');
    } on FirebaseAuthException catch (e) {
      _logError('reauthenticateWithPassword', 'Firebase Auth Error: ${e.code}');
      return AuthResult(success: false, message: getAuthErrorMessage(e.code));
    } catch (e, stack) {
      _logError('reauthenticateWithPassword', e.toString(), stack);
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
      _setLoading(true, message: 'Verifying current password...');
      debugPrint('🔐 Changing password');

      if (currentPassword.isEmpty || newPassword.isEmpty) {
        return AuthResult(
          success: false,
          message: 'Both passwords are required',
        );
      }

      if (newPassword.length < 6) {
        return AuthResult(
          success: false,
          message: 'New password must be at least 6 characters',
        );
      }

      if (currentPassword == newPassword) {
        return AuthResult(
          success: false,
          message: 'New password must be different from current password',
        );
      }

      // First reauthenticate
      final reauth = await reauthenticateWithPassword(currentPassword);
      if (!reauth.success) {
        _setLoading(false);
        return reauth;
      }

      _setLoading(true, message: 'Updating password...');

      // Then update password
      await currentUser?.updatePassword(newPassword);

      _logSuccess('changePassword', 'Password changed successfully');
      _setLoading(false);

      return AuthResult(
        success: true,
        message: 'Password changed successfully',
      );
    } on FirebaseAuthException catch (e) {
      _logError('changePassword', 'Firebase Auth Error: ${e.code}');
      _setLoading(false);
      return AuthResult(success: false, message: getAuthErrorMessage(e.code));
    } catch (e, stack) {
      _logError('changePassword', e.toString(), stack);
      _setLoading(false);
      return AuthResult(
        success: false,
        message: 'Failed to change password. Please try again.',
      );
    }
  }
}

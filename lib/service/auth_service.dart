import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:play_hub/constants/constants.dart';

class AuthService {
  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // OAuth 2.0 Client ID
  static const String _clientId =
      '371130915379-54ket1adu7iqt2lqdoh4oqhvi3fedlnj.apps.googleusercontent.com';

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

  // ==================== INITIALIZE GOOGLE SIGN-IN ====================
  Future<void> initializeGoogleSignIn() async {
    final GoogleSignIn signIn = GoogleSignIn.instance;

    // Initialize with client ID following Flutter's example pattern
    await signIn.initialize(clientId: _clientId).then((_) {
      // Listen to authentication events
      signIn.authenticationEvents
          .listen(_handleAuthenticationEvent)
          .onError(_handleAuthenticationError);

      // Attempt lightweight authentication (silent sign-in)
      // This tries to sign in the user without UI if they're already signed in
      // unawaited(signIn.attemptLightweightAuthentication());
    });
  }

  // Handle Google Sign-In authentication events (following Flutter's example)
  Future<void> _handleAuthenticationEvent(
    GoogleSignInAuthenticationEvent event,
  ) async {
    final GoogleSignInAccount? user = switch (event) {
      GoogleSignInAuthenticationEventSignIn() => event.user,
      GoogleSignInAuthenticationEventSignOut() => null,
    };

    _currentGoogleUser = user;
    _isAuthorized = user != null;

    // If user signed in, automatically sign them into Firebase
    if (user != null) {
      await _signInToFirebaseWithGoogle(user);
    }
  }

  // Handle authentication errors (following Flutter's example)
  Future<void> _handleAuthenticationError(Object e) async {
    _currentGoogleUser = null;
    _isAuthorized = false;

    final errorMessage = e is GoogleSignInException
        ? _getGoogleSignInErrorMessage(e)
        : 'Unknown error: $e';

    print('Google Sign-In Error: $errorMessage');
  }

  // Sign in to Firebase with Google credentials
  Future<AuthResult> _signInToFirebaseWithGoogle(
    GoogleSignInAccount googleUser,
  ) async {
    try {
      const scopes = [
        'https://www.googleapis.com/auth/userinfo.email',
        'https://www.googleapis.com/auth/userinfo.profile',
        'openid',
      ];

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final googleAuthorization = await googleUser.authorizationClient
          .authorizationForScopes(scopes);

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuthorization!.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user == null) {
        return AuthResult(
          success: false,
          message: 'Failed to sign in with Google',
        );
      }

      // Check if user document exists, if not create it
      final userDoc = await _firestore
          .collection('users')
          .doc(user.email)
          .get();

      if (!userDoc.exists) {
        await _firestore.collection('users').doc(user.email).set({
          'uid': user.uid,
          'email': user.email ?? '',
          'fullName': user.displayName ?? '',
          'phoneNumber': user.phoneNumber ?? '',
          'role': 'user',
          'profileImageUrl': user.photoURL ?? '',
          'clubMemberships': [],
          'hostedTournaments': [],
          'isActive': true,
          'loginMethod': 'google',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Update last login
        await _firestore.collection('users').doc(user.email).update({
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      return AuthResult(
        success: true,
        message: 'Signed in with Google successfully!',
        user: user,
      );
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Failed to sign in to Firebase: $e',
      );
    }
  }

  // ==================== GOOGLE SIGN-IN (following Flutter's example) ====================
  Future<AuthResult> signInWithGoogle() async {
    try {
      // Check if Google Sign-In supports authenticate on this platform
      if (GoogleSignIn.instance.supportsAuthenticate()) {
        // Use authenticate() for platforms that support it
        await GoogleSignIn.instance.authenticate();

        // User sign-in will be handled by the authentication event stream
        // Return success immediately
        return AuthResult(
          success: true,
          message: 'Google Sign-In initiated',
          user: currentUser,
        );
      } else {
        // For platforms that don't support authenticate (like web)
        return AuthResult(
          success: false,
          message: 'Google Sign-In is not supported on this platform',
        );
      }
    } on GoogleSignInException catch (e) {
      return AuthResult(
        success: false,
        message: _getGoogleSignInErrorMessage(e),
      );
    } catch (e) {
      return AuthResult(success: false, message: 'Google Sign-In failed: $e');
    }
  }

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

  // ==================== GET USER DATA ====================
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

  // ==================== STREAM USER DATA ====================
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

  // ==================== ERROR MESSAGE HELPERS ====================
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

  String _getGoogleSignInErrorMessage(GoogleSignInException e) {
    // Following Flutter's example pattern for error handling
    return switch (e.code) {
      GoogleSignInExceptionCode.canceled => 'Sign in was cancelled',
      GoogleSignInExceptionCode.interrupted =>
        'Network error. Please check your connection.',
      _ =>
        'GoogleSignInException ${e.code}: ${e.description ?? "Unknown error"}',
    };
  }
}

// ==================== AUTH RESULT MODEL ====================

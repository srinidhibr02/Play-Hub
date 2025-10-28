import 'dart:async';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleSignInService {
  // Singleton pattern
  static final GoogleSignInService _instance = GoogleSignInService._internal();
  factory GoogleSignInService() => _instance;
  GoogleSignInService._internal();

  // Your OAuth 2.0 Client ID
  static const String _clientId =
      '371130915379-54ket1adu7iqt2lqdoh4oqhvi3fedlnj.apps.googleusercontent.com';

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  // Get current user
  GoogleSignInAccount? _currentUser;

  // Check if user is signed in
  bool get isSignedIn => _currentUser != null;

  // Initialize Google Sign-In with client ID and set up listeners
  Future<void> initialize({
    required Function(GoogleSignInAccount?) onUserChanged,
    required Function(Object) onError,
  }) async {
    try {
      // Initialize with client ID
      await _googleSignIn.initialize(clientId: _clientId);

      // Listen to authentication events
      _googleSignIn.authenticationEvents.listen((
        GoogleSignInAuthenticationEvent event,
      ) {
        final GoogleSignInAccount? user = switch (event) {
          GoogleSignInAuthenticationEventSignIn() => event.user,
          GoogleSignInAuthenticationEventSignOut() => null,
        };
        onUserChanged(user);
      }, onError: onError);

      // Attempt lightweight authentication (silent sign-in)
      unawaited(_googleSignIn.attemptLightweightAuthentication());
    } catch (e) {
      onError(e);
    }
  }

  // Sign in with Google
  Future<GoogleSignInResult> signIn() async {
    try {
      // Check if Google Sign-In supports authenticate on this platform
      if (_googleSignIn.supportsAuthenticate()) {
        // Use authenticate() for platforms that support it
        await _googleSignIn.authenticate();

        return GoogleSignInResult(
          success: true,
          message: 'Sign-in initiated successfully',
          user: _currentUser,
        );
      } else {
        // For platforms that don't support authenticate (like web),
        // you would need to use platform-specific approaches
        return GoogleSignInResult(
          success: false,
          message:
              'Google Sign-In authenticate is not supported on this platform',
          user: null,
        );
      }
    } on GoogleSignInException catch (e) {
      return GoogleSignInResult(
        success: false,
        message: _getErrorMessage(e),
        user: null,
      );
    } catch (e) {
      return GoogleSignInResult(
        success: false,
        message: 'Sign-in failed: $e',
        user: null,
      );
    }
  }

  // Sign out
  Future<GoogleSignInResult> signOut() async {
    try {
      await _googleSignIn.signOut();
      return GoogleSignInResult(
        success: true,
        message: 'Signed out successfully',
        user: null,
      );
    } catch (e) {
      return GoogleSignInResult(
        success: false,
        message: 'Sign-out failed: $e',
        user: null,
      );
    }
  }

  // Disconnect (revoke access)
  Future<GoogleSignInResult> disconnect() async {
    try {
      await _googleSignIn.disconnect();
      return GoogleSignInResult(
        success: true,
        message: 'Disconnected successfully',
        user: null,
      );
    } catch (e) {
      return GoogleSignInResult(
        success: false,
        message: 'Disconnect failed: $e',
        user: null,
      );
    }
  }

  // Request authorization for specific scopes
  Future<GoogleSignInResult> authorizeScopes(
    List<String> scopes,
    GoogleSignInAccount user,
  ) async {
    try {
      await user.authorizationClient.authorizeScopes(scopes);

      return GoogleSignInResult(
        success: true,
        message: 'Scopes authorized successfully',
        user: user,
      );
    } catch (e) {
      return GoogleSignInResult(
        success: false,
        message: 'Authorization failed: $e',
        user: user,
      );
    }
  }

  // Check if authorization has been granted for specific scopes
  Future<bool> checkScopesAuthorized(
    List<String> scopes,
    GoogleSignInAccount user,
  ) async {
    try {
      final authorization = await user.authorizationClient
          .authorizationForScopes(scopes);
      return authorization != null;
    } catch (e) {
      return false;
    }
  }

  // Request server auth code
  Future<GoogleSignInServerAuthorization?> requestServerAuthCode(
    List<String> scopes,
    GoogleSignInAccount user,
  ) async {
    try {
      return await user.authorizationClient.authorizeServer(scopes);
    } catch (e) {
      return null;
    }
  }

  // Get user-friendly error message
  String _getErrorMessage(GoogleSignInException e) {
    switch (e.code) {
      case GoogleSignInExceptionCode.canceled:
        return 'Sign in was cancelled';
      case GoogleSignInExceptionCode.interrupted:
        return 'Network error. Please check your connection.';
      default:
        return 'Error: ${e.description ?? "Unknown error"}';
    }
  }

  // Check if platform supports authenticate method
  bool supportsAuthenticate() {
    return _googleSignIn.supportsAuthenticate();
  }

  // Check if authorization requires user interaction
  bool authorizationRequiresUserInteraction() {
    return _googleSignIn.authorizationRequiresUserInteraction();
  }
}

// Result class for Google Sign-In operations
class GoogleSignInResult {
  final bool success;
  final String message;
  final GoogleSignInAccount? user;

  GoogleSignInResult({
    required this.success,
    required this.message,
    required this.user,
  });
}

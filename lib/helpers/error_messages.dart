import 'package:google_sign_in/google_sign_in.dart';

String getAuthErrorMessage(String code) {
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

String getGoogleSignInErrorMessage(GoogleSignInException e) {
  // Following Flutter's example pattern for error handling
  return switch (e.code) {
    GoogleSignInExceptionCode.canceled => 'Sign in was cancelled',
    GoogleSignInExceptionCode.interrupted =>
      'Network error. Please check your connection.',
    _ => 'GoogleSignInException ${e.code}: ${e.description ?? "Unknown error"}',
  };
}

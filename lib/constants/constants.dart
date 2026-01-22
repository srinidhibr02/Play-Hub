import 'package:firebase_auth/firebase_auth.dart';

class AuthResult {
  final bool success;
  final String message;
  final User? user;

  AuthResult({required this.success, required this.message, this.user});

  @override
  String toString() {
    return 'AuthResult(success: $success, message: $message, user: ${user?.email})';
  }
}

String get seVersion => '1.0.4';

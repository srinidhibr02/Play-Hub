import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:play_hub/constants/constants.dart';
import 'package:play_hub/screens/home_screen.dart';
import 'package:play_hub/service/auth_service.dart';

class GoogleSignInButton extends StatefulWidget {
  const GoogleSignInButton({super.key});

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInState();
}

class _GoogleSignInState extends State<GoogleSignInButton> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final currentUser = AuthService().currentUser;

  static const String _clientId =
      '371130915379-54ket1adu7iqt2lqdoh4oqhvi3fedlnj.apps.googleusercontent.com';

  GoogleSignInAccount? _currentUser;
  bool _isAuthorized = false;
  String _contactText = '';
  String _errorMessage = '';
  String _serverAuthCode = '';
  bool _isLoading = false;
  String _loadingMessage = '';

  final List<String> scopes = <String>[
    'https://www.googleapis.com/auth/contacts.readonly',
  ];

  @override
  void initState() {
    super.initState();
    final GoogleSignIn signIn = GoogleSignIn.instance;
    unawaited(
      signIn.initialize(clientId: _clientId).then((_) {
        signIn.authenticationEvents
            .listen(_handleAuthenticationEvent)
            .onError(_handleAuthenticationError);
      }),
    );
  }

  Widget _buildSocialButton(IconData icon, VoidCallback? onPressed) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.teal.shade200, width: 2),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, size: 30, color: Colors.teal.shade700),
        onPressed: onPressed,
      ),
    );
  }

  void _showLoadingDialog(String message) {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _loadingMessage = message;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return PopScope(
          canPop: false,
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha((255 * 0.2).toInt()),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Animated loading indicator
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.teal.shade600,
                        ),
                        strokeWidth: 4,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Loading message
                    Text(
                      _loadingMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Secondary message
                    Text(
                      'Please wait...',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _hideLoadingDialog() {
    if (_isLoading && mounted) {
      Navigator.of(context).pop();
      setState(() {
        _isLoading = false;
        _loadingMessage = '';
      });
    }
  }

  Future<void> _handleAuthenticationEvent(
    GoogleSignInAuthenticationEvent event,
  ) async {
    final GoogleSignInAccount? user = switch (event) {
      GoogleSignInAuthenticationEventSignIn() => event.user,
      GoogleSignInAuthenticationEventSignOut() => null,
    };

    final GoogleSignInClientAuthorization? authorization = await user
        ?.authorizationClient
        .authorizationForScopes(scopes);

    if (!mounted) return;
    setState(() {
      _currentUser = user;
      _isAuthorized = authorization != null;
      _errorMessage = '';
    });

    if (user != null && authorization != null) {
      unawaited(_handleGetContact(user));
    }
  }

  Future<void> _handleAuthenticationError(Object e) async {
    if (!mounted) return;

    setState(() {
      _currentUser = null;
      _isAuthorized = false;
      _errorMessage = e is GoogleSignInException
          ? _errorMessageFromSignInException(e)
          : 'Unknown error: $e';
    });
  }

  String _errorMessageFromSignInException(GoogleSignInException e) {
    return switch (e.code) {
      GoogleSignInExceptionCode.canceled => 'Sign in canceled',
      _ => 'GoogleSignInException ${e.code}: ${e.description}',
    };
  }

  Future<void> _handleGetContact(GoogleSignInAccount user) async {
    setState(() {
      _contactText = 'Loading contact info...';
    });
    final Map<String, String>? headers = await user.authorizationClient
        .authorizationHeaders(scopes);
    if (headers == null) {
      setState(() {
        _contactText = '';
        _errorMessage = 'Failed to construct authorization headers.';
      });
      return;
    }
    final http.Response response = await http.get(
      Uri.parse(
        'https://people.googleapis.com/v1/people/me/connections'
        '?requestMask.includeField=person.names',
      ),
      headers: headers,
    );
    if (response.statusCode != 200) {
      if (response.statusCode == 401 || response.statusCode == 403) {
        setState(() {
          _isAuthorized = false;
          _errorMessage =
              'People API gave a ${response.statusCode} response. '
              'Please re-authorize access.';
        });
      } else {
        setState(() {
          _contactText =
              'People API gave a ${response.statusCode} '
              'response. Check logs for details.';
        });
      }
      return;
    }
    final Map<String, dynamic> data =
        json.decode(response.body) as Map<String, dynamic>;
    final String? namedContact = _pickFirstNamedContact(data);
    setState(() {
      if (namedContact != null) {
        _contactText = 'I see you know $namedContact!';
      } else {
        _contactText = 'No contacts to display.';
      }
    });
  }

  String? _pickFirstNamedContact(Map<String, dynamic> data) {
    final List<dynamic>? connections = data['connections'] as List<dynamic>?;
    final Map<String, dynamic>? contact =
        connections?.firstWhere(
              (dynamic contact) =>
                  (contact as Map<Object?, dynamic>)['names'] != null,
              orElse: () => null,
            )
            as Map<String, dynamic>?;
    if (contact != null) {
      final List<dynamic> names = contact['names'] as List<dynamic>;
      final Map<String, dynamic>? name =
          names.firstWhere(
                (dynamic name) =>
                    (name as Map<Object?, dynamic>)['displayName'] != null,
                orElse: () => null,
              )
              as Map<String, dynamic>?;
      if (name != null) {
        return name['displayName'] as String?;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildSocialButton(Icons.g_mobiledata, handleGoogleSignIn),
        const SizedBox(width: 20),
        _buildSocialButton(Icons.apple, null),
      ],
    );
  }

  Future<void> handleGoogleSignIn() async {
    try {
      _showLoadingDialog('Signing in with Google...');

      final result = await GoogleSignIn.instance.authenticate();

      if (mounted) {
        _hideLoadingDialog();
        _showLoadingDialog('Authenticating with Firebase...');
      }

      final authResult = await _signInToFirebaseWithGoogle(result);

      if (mounted) {
        _hideLoadingDialog();
      }

      if (authResult.success) {
        _showMessage(authResult.message, isError: false);
        if (mounted) {
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const HomePage()),
              );
            }
          });
        }
      } else {
        setState(() {
          _errorMessage = authResult.message;
        });
        _showMessage(authResult.message, isError: true);
      }
    } catch (e) {
      if (mounted) {
        _hideLoadingDialog();
      }
      setState(() {
        _errorMessage = e.toString();
      });
      _showMessage('Sign in failed: $e', isError: true);
    }
  }

  void _showMessage(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<AuthResult> _signInToFirebaseWithGoogle(
    GoogleSignInAccount googleUser,
  ) async {
    try {
      const scopes = [
        'https://www.googleapis.com/auth/userinfo.email',
        'https://www.googleapis.com/auth/userinfo.profile',
        'openid',
      ];

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      final googleAuthorization = await googleUser.authorizationClient
          .authorizationForScopes(scopes);

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuthorization!.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user == null) {
        return AuthResult(
          success: false,
          message: 'Failed to sign in with Google',
        );
      }

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
}

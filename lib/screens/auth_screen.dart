import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:play_hub/screens/home_screen.dart';
import 'package:play_hub/service/auth_service.dart';
import 'package:play_hub/service/google_signin_service.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();

  final _authService = AuthService();
  final _googleSignInService = GoogleSignInService();

  // Login controllers
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();

  // Register controllers
  final _registerNameController = TextEditingController();
  final _registerEmailController = TextEditingController();
  final _registerPhoneController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _registerConfirmPasswordController = TextEditingController();

  bool _loginPasswordVisible = false;
  bool _registerPasswordVisible = false;
  bool _confirmPasswordVisible = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeGoogleSignIn();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _registerNameController.dispose();
    _registerEmailController.dispose();
    _registerPhoneController.dispose();
    _registerPasswordController.dispose();
    _registerConfirmPasswordController.dispose();
    super.dispose();
  }

  // Initialize Google Sign-In service
  Future<void> _initializeGoogleSignIn() async {
    try {
      await _googleSignInService.initialize(
        onUserChanged: _handleGoogleUserChanged,
        onError: _handleGoogleError,
      );
    } catch (e) {
      // Handle initialization error
      debugPrint('Google Sign-In initialization error: $e');
    }
  }

  // Handle Google Sign-In user changes
  void _handleGoogleUserChanged(GoogleSignInAccount? user) {
    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    // If user signed in successfully, navigate to home
    if (user != null) {
      _showMessage(
        'Signed in as ${user.displayName ?? user.email}',
        isError: false,
      );
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      });
    }
  }

  // Handle Google Sign-In errors
  void _handleGoogleError(Object error) {
    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    _showMessage('Google Sign-In error: $error', isError: true);
  }

  // Login Handler
  Future<void> _handleLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final result = await _authService.loginWithEmail(
        email: _loginEmailController.text.trim(),
        password: _loginPasswordController.text.trim(),
      );

      if (!mounted) return;

      if (result.success) {
        _showMessage(result.message, isError: false);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      } else {
        _showMessage(result.message, isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage('Login failed: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Register Handler
  Future<void> _handleRegister() async {
    if (!_registerFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final result = await _authService.registerWithEmail(
        email: _registerEmailController.text.trim(),
        password: _registerPasswordController.text.trim(),
        fullName: _registerNameController.text.trim(),
        phoneNumber: _registerPhoneController.text.trim(),
      );

      if (!mounted) return;

      if (result.success) {
        _showMessage(result.message, isError: false);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      } else {
        _showMessage(result.message, isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage('Registration failed: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Google Sign In Handler
  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    try {
      final result = await _googleSignInService.signIn();

      if (!mounted) return;

      if (!result.success) {
        setState(() => _isLoading = false);
        _showMessage(result.message, isError: true);
      }
      // Success handling happens in _handleGoogleUserChanged callback
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage('Google Sign-In failed: $e', isError: true);
    }
  }

  // Forgot Password Handler
  void _handleForgotPassword() {
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reset Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your email to receive a password reset link'),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = emailController.text.trim();

              if (email.isEmpty) {
                _showMessage('Please enter your email', isError: true);
                return;
              }

              Navigator.pop(context);

              // TODO: Uncomment and use AuthService
              /*
              final result = await _authService.resetPassword(email: email);
              _showMessage(result.message, isError: !result.success);
              */

              // Temporary
              _showMessage(
                'Password reset link sent to $email',
                isError: false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Send Link'),
          ),
        ],
      ),
    );
  }

  // Show message helper
  void _showMessage(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(color: Colors.white),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                const SizedBox(height: 40),
                // Logo
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    child: Image.asset(
                      'images/whiteBGlogo.png',
                      width: 120,
                      height: 120,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Welcome Back!',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Manage your sports events efficiently',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 24),
                // Tab Bar
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary,
                          Colors.teal.shade700,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(40),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.grey.shade700,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    padding: const EdgeInsets.all(6),
                    tabs: const [
                      Tab(text: 'Login', height: 48),
                      Tab(text: 'Register', height: 48),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Tab Views
                Flexible(
                  child: TabBarView(
                    controller: _tabController,
                    children: [_buildLoginForm(), _buildRegisterForm()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return SingleChildScrollView(
      child: Form(
        key: _loginFormKey,
        child: Column(
          children: [
            _buildTextField(
              controller: _loginEmailController,
              label: 'Email',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your email';
                }
                if (!RegExp(
                  r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                ).hasMatch(value)) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            _buildTextField(
              controller: _loginPasswordController,
              label: 'Password',
              icon: Icons.lock_outline,
              obscureText: !_loginPasswordVisible,
              suffixIcon: IconButton(
                icon: Icon(
                  _loginPasswordVisible
                      ? Icons.visibility
                      : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(
                    () => _loginPasswordVisible = !_loginPasswordVisible,
                  );
                },
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your password';
                }
                if (value.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _handleForgotPassword,
                child: Text(
                  'Forgot Password?',
                  style: TextStyle(
                    color: Colors.teal.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
            _buildGradientButton(
              text: 'Login',
              onPressed: _isLoading ? null : _handleLogin,
            ),
            const SizedBox(height: 20),
            const Text(
              'Or continue with',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildSocialButton(
                  Icons.g_mobiledata,
                  _isLoading ? null : _handleGoogleSignIn,
                ),
                const SizedBox(width: 20),
                _buildSocialButton(Icons.apple, null),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterForm() {
    return SingleChildScrollView(
      child: Form(
        key: _registerFormKey,
        child: Column(
          children: [
            _buildTextField(
              controller: _registerNameController,
              label: 'Full Name',
              icon: Icons.person_outline,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your name';
                }
                if (value.length < 3) {
                  return 'Name must be at least 3 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _registerEmailController,
              label: 'Email',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your email';
                }
                if (!RegExp(
                  r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                ).hasMatch(value)) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _registerPhoneController,
              label: 'Phone Number',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your phone number';
                }
                if (!RegExp(r'^[0-9]{10}$').hasMatch(value)) {
                  return 'Please enter a valid 10-digit phone number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _registerPasswordController,
              label: 'Password',
              icon: Icons.lock_outline,
              obscureText: !_registerPasswordVisible,
              suffixIcon: IconButton(
                icon: Icon(
                  _registerPasswordVisible
                      ? Icons.visibility
                      : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(
                    () => _registerPasswordVisible = !_registerPasswordVisible,
                  );
                },
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a password';
                }
                if (value.length < 8) {
                  return 'Password must be at least 8 characters';
                }
                if (!RegExp(
                  r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)',
                ).hasMatch(value)) {
                  return 'Must contain uppercase, lowercase & number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _registerConfirmPasswordController,
              label: 'Confirm Password',
              icon: Icons.lock_outline,
              obscureText: !_confirmPasswordVisible,
              suffixIcon: IconButton(
                icon: Icon(
                  _confirmPasswordVisible
                      ? Icons.visibility
                      : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(
                    () => _confirmPasswordVisible = !_confirmPasswordVisible,
                  );
                },
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please confirm your password';
                }
                if (value != _registerPasswordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
            const SizedBox(height: 30),
            _buildGradientButton(
              text: 'Register',
              onPressed: _isLoading ? null : _handleRegister,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade600),
        prefixIcon: Icon(icon, color: Colors.teal.shade700),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.teal.shade700, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildGradientButton({
    required String text,
    required VoidCallback? onPressed,
  }) {
    return Container(
      width: double.infinity,
      height: 55,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Theme.of(context).colorScheme.primary, Colors.teal.shade700],
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.shade300.withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Text(
                text,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
              ),
      ),
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
}

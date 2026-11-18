import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:play_hub/core/theme/app_theme.dart';
import 'package:play_hub/core/widgets/entrance.dart';
import 'package:play_hub/core/widgets/sport_badge.dart';
import 'package:play_hub/models/sport.dart';
import 'package:play_hub/providers/providers.dart';
import 'package:play_hub/services/auth_service.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _registerMode = false;
  bool _busy = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool error = true}) {
    if (!mounted) return;
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? scheme.error : null,
        ),
      );
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      _showMessage(AuthService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    final auth = ref.read(authServiceProvider);
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    await _run(() {
      if (_registerMode) {
        return auth.registerWithEmail(
          name: _nameController.text.trim(),
          email: email,
          password: password,
        );
      }
      return auth.signInWithEmail(email: email, password: password);
    });
  }

  Future<void> _google() async {
    FocusScope.of(context).unfocus();
    await _run(() => ref.read(authServiceProvider).signInWithGoogle());
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (!email.contains('@')) {
      _showMessage('Enter your email above first, then tap "Forgot password".');
      return;
    }
    await _run(() async {
      await ref.read(authServiceProvider).sendPasswordReset(email);
      _showMessage('Password reset email sent to $email.', error: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.brandGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 28),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: _buildForm(theme),
                      ),
                    ).entrance(index: 2),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < Sport.values.length; i++) ...[
              if (i > 0) const SizedBox(width: 14),
              SportBadge(sport: Sport.values[i], size: 56).entrance(index: i),
            ],
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'Run your local\ntournament like a pro',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            height: 1.2,
            fontWeight: FontWeight.w800,
          ),
        ).entrance(index: 3),
        const SizedBox(height: 10),
        Text(
          'Fixtures, scores and standings for badminton,\ncricket and football.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.88),
            fontSize: 14,
            height: 1.4,
          ),
        ).entrance(index: 4),
      ],
    );
  }

  Widget _buildForm(ThemeData theme) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _registerMode ? 'Create your account' : 'Welcome back',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 20),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _registerMode
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.name],
                      decoration: const InputDecoration(
                        labelText: 'Full name',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      validator: (value) =>
                          (value == null || value.trim().length < 2)
                              ? 'Enter your name'
                              : null,
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.mail_outline_rounded),
            ),
            validator: (value) {
              final v = value?.trim() ?? '';
              if (v.isEmpty || !v.contains('@') || !v.contains('.')) {
                return 'Enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onFieldSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            validator: (value) => (value == null || value.length < 6)
                ? 'At least 6 characters'
                : null,
          ),
          if (!_registerMode)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _busy ? null : _forgotPassword,
                child: const Text('Forgot password?'),
              ),
            )
          else
            const SizedBox(height: 12),
          const SizedBox(height: 4),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : Text(_registerMode ? 'Create account' : 'Sign in'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'or',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _busy ? null : _google,
            icon: const Icon(Icons.login_rounded),
            label: const Text('Continue with Google'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _busy
                ? null
                : () => setState(() => _registerMode = !_registerMode),
            child: Text(
              _registerMode
                  ? 'Already have an account? Sign in'
                  : "New here? Create an account",
            ),
          ),
        ],
      ),
    );
  }
}

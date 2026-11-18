import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:play_hub/core/theme/app_theme.dart';
import 'package:play_hub/features/auth/auth_screen.dart';
import 'package:play_hub/features/auth/splash_screen.dart';
import 'package:play_hub/features/home/home_screen.dart';
import 'package:play_hub/flavor_config.dart';
import 'package:play_hub/providers/providers.dart';

class TournamentApp extends StatelessWidget {
  const TournamentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: FlavorConfig.title,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: const AuthGate(),
    );
  }
}

/// Shows the splash while Firebase restores the session, then either the
/// sign-in screen or the home screen.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      switchInCurve: Curves.easeOut,
      child: auth.when(
        loading: () => const SplashScreen(key: ValueKey('splash')),
        error: (error, stack) => const AuthScreen(key: ValueKey('auth')),
        data: (user) => user == null
            ? const AuthScreen(key: ValueKey('auth'))
            : const HomeScreen(key: ValueKey('home')),
      ),
    );
  }
}

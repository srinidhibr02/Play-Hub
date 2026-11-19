import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:play_hub/core/theme/app_theme.dart';

/// Shown while Firebase restores the session. The logo image has the same
/// teal as the background, so it appears to float on the screen.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.brand,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(AppTheme.logoOnTeal, width: 240, height: 240)
                .animate()
                .scale(
                  begin: const Offset(0.85, 0.85),
                  end: const Offset(1, 1),
                  duration: 700.ms,
                  curve: Curves.easeOutBack,
                )
                .fadeIn(duration: 500.ms),
            const SizedBox(height: 8),
            Text(
              'Sports Event & Tournament Manager',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 14,
                letterSpacing: 0.4,
              ),
            ).animate(delay: 450.ms).fadeIn(duration: 500.ms),
            const SizedBox(height: 28),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            ).animate(delay: 800.ms).fadeIn(duration: 400.ms),
          ],
        ),
      ),
    );
  }
}

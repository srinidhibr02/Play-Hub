import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Fade-and-rise entrance animation, staggered by list position.
extension EntranceAnimation on Widget {
  Widget entrance({int index = 0}) {
    // Cap the stagger so long lists do not feel slow.
    final step = math.min(index, 8);
    return animate(delay: (step * 55).ms)
        .fadeIn(duration: 380.ms, curve: Curves.easeOut)
        .slideY(
          begin: 0.08,
          end: 0,
          duration: 380.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

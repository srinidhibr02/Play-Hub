import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:play_hub/models/tournament.dart';

/// Small status label. A live status gets a gently pulsing dot.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.status, this.onGradient = false});

  final TournamentStatus status;

  /// Use white styling when drawn on top of a sport gradient.
  final bool onGradient;

  Color get _color => switch (status) {
        TournamentStatus.upcoming => const Color(0xFFF59E0B),
        TournamentStatus.live => const Color(0xFF22C55E),
        TournamentStatus.completed => const Color(0xFF64748B),
      };

  @override
  Widget build(BuildContext context) {
    final dotColor = onGradient ? Colors.white : _color;
    final textColor = onGradient ? Colors.white : _color;
    final background = onGradient
        ? Colors.white.withValues(alpha: 0.2)
        : _color.withValues(alpha: 0.14);

    Widget dot = Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
    );
    if (status == TournamentStatus.live) {
      dot = dot
          .animate(onPlay: (controller) => controller.repeat(reverse: true))
          .fade(begin: 0.35, end: 1, duration: 800.ms);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          dot,
          const SizedBox(width: 6),
          Text(
            status.label,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

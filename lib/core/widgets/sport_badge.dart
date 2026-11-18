import 'package:flutter/material.dart';

import 'package:play_hub/models/sport.dart';

/// Rounded square with the sport's icon on its gradient.
class SportBadge extends StatelessWidget {
  const SportBadge({super.key, required this.sport, this.size = 48});

  final Sport sport;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: sport.gradient,
        borderRadius: BorderRadius.circular(size * 0.32),
        boxShadow: [
          BoxShadow(
            color: sport.color.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(sport.icon, color: Colors.white, size: size * 0.56),
    );
  }
}

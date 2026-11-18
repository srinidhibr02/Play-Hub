import 'package:flutter/material.dart';

import 'package:play_hub/core/utils/formatters.dart';
import 'package:play_hub/models/tournament_match.dart';

/// One fixture in the list: both sides, the status and (if set) the time.
class MatchTile extends StatelessWidget {
  const MatchTile({super.key, required this.match, required this.accent});

  final TournamentMatch match;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SideLine(
                    name: match.teamAName,
                    isWinner:
                        match.winnerId != null && match.winnerId == match.teamAId,
                  ),
                  const SizedBox(height: 8),
                  _SideLine(
                    name: match.teamBName,
                    isWinner:
                        match.winnerId != null && match.winnerId == match.teamBId,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _MatchStatusChip(status: match.status),
                if (match.scheduledAt != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    formatDateTime(match.scheduledAt!),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SideLine extends StatelessWidget {
  const _SideLine({required this.name, required this.isWinner});

  final String? name;
  final bool isWinner;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTbd = name == null;

    return Row(
      children: [
        Expanded(
          child: Text(
            isTbd ? 'To be decided' : name!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: isWinner ? FontWeight.w800 : FontWeight.w600,
              fontStyle: isTbd ? FontStyle.italic : FontStyle.normal,
              color: isTbd
                  ? theme.colorScheme.onSurfaceVariant
                  : theme.colorScheme.onSurface,
            ),
          ),
        ),
        if (isWinner)
          const Padding(
            padding: EdgeInsets.only(left: 6),
            child: Icon(
              Icons.emoji_events_rounded,
              size: 16,
              color: Color(0xFFF59E0B),
            ),
          ),
      ],
    );
  }
}

class _MatchStatusChip extends StatelessWidget {
  const _MatchStatusChip({required this.status});

  final MatchStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      MatchStatus.scheduled => const Color(0xFF64748B),
      MatchStatus.live => const Color(0xFF22C55E),
      MatchStatus.completed => const Color(0xFF2563EB),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

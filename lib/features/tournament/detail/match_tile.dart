import 'package:flutter/material.dart';

import 'package:play_hub/core/utils/formatters.dart';
import 'package:play_hub/core/widgets/pressable_scale.dart';
import 'package:play_hub/logic/match_rules.dart';
import 'package:play_hub/models/sport.dart';
import 'package:play_hub/models/tournament_match.dart';

/// One fixture in the list: both sides, their scores, the status and (if
/// set) the time. When [onTap] is given the tile is tappable (organizers use
/// it to enter a score).
class MatchTile extends StatelessWidget {
  const MatchTile({
    super.key,
    required this.match,
    required this.sport,
    this.onTap,
  });

  final TournamentMatch match;
  final Sport sport;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final score = match.score;
    final isLive = match.status == MatchStatus.live;

    String? scoreOf(bool sideA) {
      final s = score;
      if (s == null || match.status == MatchStatus.scheduled) return null;
      return MatchRules.sideScore(sport: sport, score: s, sideA: sideA);
    }

    final summary = (match.isCompleted && score != null)
        ? MatchRules.summary(
            sport: sport,
            score: score,
            teamAName: match.teamAName,
            teamBName: match.teamBName,
            teamAId: match.teamAId,
            winnerId: match.winnerId,
          )
        : null;

    return PressableScale(
      onTap: onTap,
      child: Card(
        shape: isLive
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Color(0xFF22C55E), width: 1.5),
              )
            : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SideLine(
                          name: match.teamAName,
                          score: scoreOf(true),
                          isWinner: match.winnerId != null &&
                              match.winnerId == match.teamAId,
                        ),
                        const SizedBox(height: 8),
                        _SideLine(
                          name: match.teamBName,
                          score: scoreOf(false),
                          isWinner: match.winnerId != null &&
                              match.winnerId == match.teamBId,
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
                      if (onTap != null) ...[
                        const SizedBox(height: 6),
                        Icon(
                          match.isCompleted
                              ? Icons.edit_outlined
                              : Icons.sports_score_rounded,
                          size: 18,
                          color: sport.color,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              if (summary != null) ...[
                const SizedBox(height: 10),
                Text(
                  summary,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SideLine extends StatelessWidget {
  const _SideLine({
    required this.name,
    required this.score,
    required this.isWinner,
  });

  final String? name;
  final String? score;
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
        if (score != null)
          Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Text(
              score!,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: isWinner ? FontWeight.w900 : FontWeight.w700,
              ),
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

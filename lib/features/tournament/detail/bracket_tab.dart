import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:play_hub/core/widgets/empty_state.dart';
import 'package:play_hub/core/widgets/entrance.dart';
import 'package:play_hub/logic/match_rules.dart';
import 'package:play_hub/models/sport.dart';
import 'package:play_hub/models/tournament.dart';
import 'package:play_hub/models/tournament_match.dart';
import 'package:play_hub/providers/providers.dart';

/// Knockout bracket: one column per round, scrolling sideways.
class BracketTab extends ConsumerWidget {
  const BracketTab({super.key, required this.tournament});

  final Tournament tournament;

  static const double _cardWidth = 216;
  static const double _cardHeight = 92;
  static const double _gap = 14;
  static const double _columnGap = 28;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = tournament;
    final matchesAsync = ref.watch(matchesProvider(t.id));

    if (matchesAsync.hasError) {
      return const EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Could not load the bracket',
        message: 'Check your connection and try again.',
      );
    }
    final all = matchesAsync.valueOrNull;
    if (all == null) return const Center(child: CircularProgressIndicator());

    // Byes are stored but never shown; the team simply appears next round.
    final matches = all.where((m) => !m.isBye).toList();
    if (matches.isEmpty) {
      return EmptyState(
        icon: Icons.account_tree_rounded,
        color: t.sport.color,
        title: 'No bracket yet',
        message: 'The bracket appears once the organizer draws the fixtures.',
      );
    }

    final byRound = <int, List<TournamentMatch>>{};
    for (final m in matches) {
      byRound.putIfAbsent(m.round, () => []).add(m);
    }
    final rounds = byRound.keys.toList()..sort();
    for (final list in byRound.values) {
      list.sort((a, b) => a.order.compareTo(b.order));
    }
    final tallest = byRound.values.map((l) => l.length).reduce(math.max);
    final columnHeight = tallest * (_cardHeight + _gap);

    // Champion: the winner of the last match of the last round.
    final finalMatch = byRound[rounds.last]!.last;
    final championId = finalMatch.isCompleted ? finalMatch.winnerId : null;
    final championName = championId == null
        ? null
        : (championId == finalMatch.teamAId
            ? finalMatch.teamAName
            : finalMatch.teamBName);

    return ListView(
      key: const PageStorageKey('bracket'),
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 40),
      children: [
        if (championName != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: _ChampionBanner(name: championName, sport: t.sport)
                .entrance(),
          ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var r = 0; r < rounds.length; r++) ...[
                if (r > 0) const SizedBox(width: _columnGap),
                SizedBox(
                  width: _cardWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          byRound[rounds[r]]!.first.roundLabel,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      SizedBox(
                        height: columnHeight,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            for (final m in byRound[rounds[r]]!)
                              SizedBox(
                                height: _cardHeight,
                                child: _BracketCard(
                                  match: m,
                                  sport: t.sport,
                                ),
                              ).entrance(index: r),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _BracketCard extends StatelessWidget {
  const _BracketCard({required this.match, required this.sport});

  final TournamentMatch match;
  final Sport sport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final live = match.status == MatchStatus.live;
    final score = match.score;
    final showScore = score != null && match.status != MatchStatus.scheduled;

    Widget side(String? name, String? id, bool sideA) {
      final won = match.winnerId != null && match.winnerId == id;
      final lost = match.isCompleted && match.winnerId != null && !won;
      final tbd = name == null;
      return Expanded(
        child: Row(
          children: [
            Expanded(
              child: Text(
                tbd ? 'To be decided' : name!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: won ? FontWeight.w900 : FontWeight.w600,
                  fontStyle: tbd ? FontStyle.italic : FontStyle.normal,
                  color: (tbd || lost)
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.onSurface,
                ),
              ),
            ),
            if (won)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(
                  Icons.check_circle_rounded,
                  size: 16,
                  color: Color(0xFF16A34A),
                ),
              ),
            if (showScore)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  MatchRules.sideScore(
                    sport: sport,
                    score: score!,
                    sideA: sideA,
                  ),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: won ? FontWeight.w900 : FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: live
            ? const BorderSide(color: Color(0xFF22C55E), width: 1.5)
            : BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
              ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            side(match.teamAName, match.teamAId, true),
            Divider(
              height: 1,
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
            ),
            side(match.teamBName, match.teamBId, false),
          ],
        ),
      ),
    );
  }
}

class _ChampionBanner extends StatelessWidget {
  const _ChampionBanner({required this.name, required this.sport});

  final String name;
  final Sport sport;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: sport.gradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.emoji_events_rounded,
            color: Color(0xFFFBBF24),
            size: 40,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CHAMPION',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

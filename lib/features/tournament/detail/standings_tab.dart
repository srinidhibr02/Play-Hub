import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:play_hub/core/widgets/empty_state.dart';
import 'package:play_hub/core/widgets/entrance.dart';
import 'package:play_hub/logic/standings.dart';
import 'package:play_hub/models/sport.dart';
import 'package:play_hub/models/tournament.dart';
import 'package:play_hub/providers/providers.dart';

/// League table, recalculated live from the match results.
class StandingsTab extends ConsumerWidget {
  const StandingsTab({super.key, required this.tournament});

  final Tournament tournament;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = tournament;
    final teamsAsync = ref.watch(teamsProvider(t.id));
    final matchesAsync = ref.watch(matchesProvider(t.id));

    if (teamsAsync.hasError || matchesAsync.hasError) {
      return const EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Could not load the table',
        message: 'Check your connection and try again.',
      );
    }
    final teams = teamsAsync.valueOrNull;
    final matches = matchesAsync.valueOrNull;
    if (teams == null || matches == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (matches.isEmpty) {
      return EmptyState(
        icon: Icons.leaderboard_rounded,
        color: t.sport.color,
        title: 'No table yet',
        message: 'The table appears once the fixtures are drawn and results '
            'start coming in.',
      );
    }

    final rows = Standings.compute(
      sport: t.sport,
      settings: t.settings,
      teams: teams,
      matches: matches,
    );
    final anyPlayed = rows.any((r) => r.played > 0);

    return ListView(
      key: const PageStorageKey('standings'),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        _TableCard(
          sport: t.sport,
          rows: rows,
          highlightLeader: anyPlayed,
        ).entrance(),
        const SizedBox(height: 14),
        _Legend(tournament: t),
      ],
    );
  }
}

class _Column {
  const _Column(this.label, this.width, this.value, {this.bold = false});

  final String label;
  final double width;
  final String Function(Standing) value;
  final bool bold;
}

String _signed(int v) => v > 0 ? '+$v' : '$v';

List<_Column> _columnsFor(Sport sport) {
  const w = 36.0;
  switch (sport) {
    case Sport.football:
      return [
        _Column('P', w, (s) => '${s.played}'),
        _Column('W', w, (s) => '${s.won}'),
        _Column('D', w, (s) => '${s.drawn}'),
        _Column('L', w, (s) => '${s.lost}'),
        _Column('GD', 44, (s) => _signed(s.goalDifference)),
        _Column('Pts', 44, (s) => '${s.points}', bold: true),
      ];
    case Sport.cricket:
      return [
        _Column('P', w, (s) => '${s.played}'),
        _Column('W', w, (s) => '${s.won}'),
        _Column('L', w, (s) => '${s.lost}'),
        _Column('T', w, (s) => '${s.drawn}'),
        _Column(
          'NRR',
          60,
          (s) => '${s.netRunRate >= 0 ? '+' : ''}'
              '${s.netRunRate.toStringAsFixed(3)}',
        ),
        _Column('Pts', 44, (s) => '${s.points}', bold: true),
      ];
    case Sport.badminton:
      return [
        _Column('P', w, (s) => '${s.played}'),
        _Column('W', w, (s) => '${s.won}'),
        _Column('L', w, (s) => '${s.lost}'),
        _Column('GD', 44, (s) => _signed(s.gameDifference)),
        _Column('PD', 48, (s) => _signed(s.pointDifference)),
        _Column('Pts', 44, (s) => '${s.points}', bold: true),
      ];
  }
}

class _TableCard extends StatelessWidget {
  const _TableCard({
    required this.sport,
    required this.rows,
    required this.highlightLeader,
  });

  final Sport sport;
  final List<Standing> rows;
  final bool highlightLeader;

  static const double _rankWidth = 30;
  static const double _nameWidth = 140;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final columns = _columnsFor(sport);
    final statsWidth = columns.fold<double>(0, (sum, c) => sum + c.width);
    final needed = _rankWidth + _nameWidth + statsWidth + 24;

    final headerStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w800,
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = math.max(constraints.maxWidth, needed);
          final nameWidth = width - _rankWidth - statsWidth - 24;

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: width,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: _rankWidth,
                          child: Text('#', style: headerStyle),
                        ),
                        SizedBox(
                          width: nameWidth,
                          child: Text(
                            sport.participantNoun.toUpperCase(),
                            style: headerStyle,
                          ),
                        ),
                        for (final c in columns)
                          SizedBox(
                            width: c.width,
                            child: Text(
                              c.label,
                              textAlign: TextAlign.center,
                              style: headerStyle,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  for (var i = 0; i < rows.length; i++)
                    _Row(
                      rank: i + 1,
                      standing: rows[i],
                      columns: columns,
                      nameWidth: nameWidth,
                      accent: sport.color,
                      leader: highlightLeader && i == 0,
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.rank,
    required this.standing,
    required this.columns,
    required this.nameWidth,
    required this.accent,
    required this.leader,
  });

  final int rank;
  final Standing standing;
  final List<_Column> columns;
  final double nameWidth;
  final Color accent;
  final bool leader;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: leader ? accent.withValues(alpha: 0.10) : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: _TableCard._rankWidth,
            child: leader
                ? Icon(Icons.emoji_events_rounded,
                    size: 18, color: const Color(0xFFF59E0B))
                : Text(
                    '$rank',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
          ),
          SizedBox(
            width: nameWidth,
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Color(standing.team.colorValue),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    standing.team.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: leader ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (final c in columns)
            SizedBox(
              width: c.width,
              child: Text(
                c.value(standing),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: c.bold ? FontWeight.w900 : FontWeight.w500,
                  color: c.bold ? accent : null,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.tournament});

  final Tournament tournament;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = tournament.settings;

    final text = switch (tournament.sport) {
      Sport.football =>
        'P played, W won, D drawn, L lost, GD goal difference, Pts points '
            '(${s.winPoints} for a win, ${s.drawPoints} for a draw). Ties on '
            'points are split by goal difference, then goals scored.',
      Sport.cricket =>
        'P played, W won, L lost, T tied, NRR net run rate, Pts points '
            '(${s.winPoints} for a win, ${s.drawPoints} for a tie). A side '
            'bowled out is counted as having faced its full ${s.overs} overs.',
      Sport.badminton =>
        'P played, W won, L lost, GD game difference, PD point difference, '
            'Pts points (${s.winPoints} for a win). Ties on points are split '
            'by game difference, then point difference.',
    };

    return Text(
      text,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        height: 1.4,
      ),
    );
  }
}

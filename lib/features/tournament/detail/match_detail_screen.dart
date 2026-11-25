import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:play_hub/core/utils/formatters.dart';
import 'package:play_hub/core/utils/share.dart';
import 'package:play_hub/logic/match_events.dart';
import 'package:play_hub/logic/match_rules.dart';
import 'package:play_hub/logic/share_text.dart';
import 'package:play_hub/models/sport.dart';
import 'package:play_hub/models/tournament.dart';
import 'package:play_hub/models/tournament_match.dart';
import 'package:play_hub/providers/providers.dart';

/// Read-only view of one match: result, goals and cards, scorecards or game
/// scores. Live: it follows the match as the organizer updates it.
class MatchDetailScreen extends ConsumerWidget {
  const MatchDetailScreen({
    super.key,
    required this.tournament,
    required this.matchId,
  });

  final Tournament tournament;
  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matches = ref.watch(matchesProvider(tournament.id)).valueOrNull;
    TournamentMatch? match;
    for (final m in matches ?? const <TournamentMatch>[]) {
      if (m.id == matchId) match = m;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(match?.roundLabel ?? 'Match'),
        actions: [
          if (match != null)
            IconButton(
              tooltip: 'Share',
              icon: const Icon(Icons.share_outlined),
              onPressed: () => shareText(
                context,
                ShareText.match(tournament: tournament, match: match!),
                subject: tournament.name,
              ),
            ),
        ],
      ),
      body: match == null
          ? const Center(child: CircularProgressIndicator())
          : _Body(tournament: tournament, match: match),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.tournament, required this.match});

  final Tournament tournament;
  final TournamentMatch match;

  Sport get _sport => tournament.sport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = match;
    final score = m.score;
    final live = m.status == MatchStatus.live;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: _sport.gradient,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (live)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  Text(
                    m.isCompleted ? 'Full time' : (live ? 'In progress' : 'Upcoming'),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _TeamName(m.teamAName)),
                  Text(
                    score == null
                        ? 'vs'
                        : '${MatchRules.sideScore(sport: _sport, score: score, sideA: true)}'
                            '  -  '
                            '${MatchRules.sideScore(sport: _sport, score: score, sideA: false)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Expanded(child: _TeamName(m.teamBName)),
                ],
              ),
              if (m.isCompleted && score != null) ...[
                const SizedBox(height: 14),
                Text(
                  MatchRules.summary(
                    sport: _sport,
                    score: score,
                    teamAName: m.teamAName,
                    teamBName: m.teamBName,
                    teamAId: m.teamAId,
                    winnerId: m.winnerId,
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (m.scheduledAt != null)
          _InfoLine(Icons.schedule_rounded, formatDateTime(m.scheduledAt!)),
        if (m.venue.isNotEmpty) _InfoLine(Icons.place_outlined, m.venue),
        const SizedBox(height: 8),
        if (score == null)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Text(
              'Details will appear here once the match starts.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          ...switch (_sport) {
            Sport.football => _football(context, score),
            Sport.cricket => _cricket(context, score),
            Sport.badminton => _badminton(context, score),
          },
      ],
    );
  }

  // -------------------------------------------------------------- football

  List<Widget> _football(BuildContext context, MatchScore score) {
    final theme = Theme.of(context);
    final events = MatchEvents.sorted(score.events);
    final lineups = (score.lineupA.isNotEmpty || score.lineupB.isNotEmpty)
        ? _Section(
            title: 'Lineups',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final entry in [
                  (match.teamAName ?? 'Team A', score.lineupA),
                  (match.teamBName ?? 'Team B', score.lineupB),
                ])
                  if (entry.$2.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.$1,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            entry.$2.join(', '),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          )
        : null;
    if (events.isEmpty) {
      return [
        if (lineups != null) lineups,
        _Section(
          title: 'Match events',
          child: Text(
            'No goal scorers or cards were recorded.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ];
    }

    String teamName(String id) =>
        id == match.teamAId ? (match.teamAName ?? 'Team A') : (match.teamBName ?? 'Team B');

    IconData icon(MatchEventType t) => switch (t) {
          MatchEventType.goal => Icons.sports_soccer_rounded,
          MatchEventType.penaltyGoal => Icons.adjust_rounded,
          MatchEventType.ownGoal => Icons.replay_rounded,
          MatchEventType.yellowCard => Icons.style_rounded,
          MatchEventType.redCard => Icons.style_rounded,
          MatchEventType.substitution => Icons.swap_vert_rounded,
        };
    Color color(MatchEventType t) => switch (t) {
          MatchEventType.yellowCard => const Color(0xFFEAB308),
          MatchEventType.redCard => const Color(0xFFDC2626),
          _ => _sport.color,
        };

    return [
      if (lineups != null) lineups,
      _Section(
        title: 'Match events',
        child: Column(
          children: [
            for (final e in events)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(icon(e.type), color: color(e.type)),
                title: Text(
                  e.type.isSubstitution
                      ? '${e.player} on, ${e.playerOff} off'
                      : e.player,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  [
                    '${e.type.label} · ${teamName(e.teamId)}',
                    if (e.assist.isNotEmpty) 'assist ${e.assist}',
                  ].join(' · '),
                ),
                trailing: e.minute == null
                    ? null
                    : Text(
                        "${e.minute}'",
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
              ),
          ],
        ),
      ),
    ];
  }

  // --------------------------------------------------------------- cricket

  List<Widget> _cricket(BuildContext context, MatchScore score) {
    final first = score.battedFirstA;
    Widget innings(bool sideA, String title) {
      final name =
          (sideA ? match.teamAName : match.teamBName) ?? (sideA ? 'Team A' : 'Team B');
      final runs = sideA ? score.runsA : score.runsB;
      final wickets = sideA ? score.wicketsA : score.wicketsB;
      final balls = sideA ? score.ballsA : score.ballsB;
      final batters = sideA ? score.battersA : score.battersB;
      // The bowlers who bowled at this innings belong to the other side.
      final bowlers = sideA ? score.bowlersB : score.bowlersA;
      final extras = runs - batters.fold<int>(0, (s, b) => s + b.runs);

      return _Section(
        title: '$title · $name',
        trailing: '$runs/$wickets (${MatchRules.oversText(balls)} ov)',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (batters.isEmpty && bowlers.isEmpty)
              const Text('No scorecard recorded for this innings.'),
            if (batters.isNotEmpty) ...[
              const _TableHeader(['Batter', 'R', 'B', '4s', '6s', 'SR']),
              for (final b in batters)
                _TableRow(
                  main: b.name,
                  sub: b.out ? (b.dismissal.isEmpty ? 'out' : b.dismissal) : 'not out',
                  cells: [
                    '${b.runs}',
                    b.balls == 0 ? '-' : '${b.balls}',
                    '${b.fours}',
                    '${b.sixes}',
                    b.strikeRate == null ? '-' : b.strikeRate!.toStringAsFixed(0),
                  ],
                  boldFirst: true,
                ),
              if (extras > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Extras and unlisted runs: $extras'),
                ),
            ],
            if (bowlers.isNotEmpty) ...[
              const SizedBox(height: 14),
              const _TableHeader(['Bowler', 'O', 'M', 'R', 'W', 'Eco']),
              for (final b in bowlers)
                _TableRow(
                  main: b.name,
                  cells: [
                    MatchRules.oversText(b.balls),
                    '${b.maidens}',
                    '${b.runs}',
                    '${b.wickets}',
                    b.economy == null ? '-' : b.economy!.toStringAsFixed(1),
                  ],
                  boldFirst: false,
                  boldWickets: true,
                ),
            ],
          ],
        ),
      );
    }

    return [
      innings(first, '1st innings'),
      innings(!first, '2nd innings'),
    ];
  }

  // ------------------------------------------------------------- badminton

  List<Widget> _badminton(BuildContext context, MatchScore score) {
    if (score.games.isEmpty) return const [];
    return [
      _Section(
        title: 'Games',
        child: Column(
          children: [
            for (var i = 0; i < score.games.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Text(
                      'Game ${i + 1}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    Text(
                      '${score.games[i].a}  -  ${score.games[i].b}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ];
  }
}

class _TeamName extends StatelessWidget {
  const _TeamName(this.name);

  final String? name;

  @override
  Widget build(BuildContext context) => Text(
        name ?? 'TBD',
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      );
}

class _InfoLine extends StatelessWidget {
  const _InfoLine(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.trailing});

  final String title;
  final String? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (trailing != null)
                    Text(
                      trailing!,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// Widths of the numeric columns in the scorecard tables.
const double _cell = 38;

class _TableHeader extends StatelessWidget {
  const _TableHeader(this.labels);

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w800,
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(child: Text(labels.first.toUpperCase(), style: style)),
          for (final l in labels.skip(1))
            SizedBox(
              width: _cell,
              child: Text(l, textAlign: TextAlign.center, style: style),
            ),
        ],
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({
    required this.main,
    required this.cells,
    required this.boldFirst,
    this.sub,
    this.boldWickets = false,
  });

  final String main;
  final String? sub;
  final List<String> cells;
  final bool boldFirst;
  final bool boldWickets;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  main,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (sub != null)
                  Text(
                    sub!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          for (var i = 0; i < cells.length; i++)
            SizedBox(
              width: _cell,
              child: Text(
                cells[i],
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: ((boldFirst && i == 0) ||
                          (boldWickets && i == 3))
                      ? FontWeight.w900
                      : FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:play_hub/core/utils/formatters.dart';
import 'package:play_hub/logic/match_rules.dart';
import 'package:play_hub/logic/standings.dart';
import 'package:play_hub/logic/team_profile.dart';
import 'package:play_hub/models/sport.dart';
import 'package:play_hub/models/team.dart';
import 'package:play_hub/models/tournament.dart';
import 'package:play_hub/providers/providers.dart';

/// Bottom sheet with one team's table position, recent form and matches.
Future<void> showTeamProfileSheet(
  BuildContext context, {
  required Tournament tournament,
  required Team team,
  required List<Team> teams,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (context, controller) => _ProfileBody(
        tournament: tournament,
        team: team,
        teams: teams,
        controller: controller,
      ),
    ),
  );
}

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody({
    required this.tournament,
    required this.team,
    required this.teams,
    required this.controller,
  });

  final Tournament tournament;
  final Team team;
  final List<Team> teams;
  final ScrollController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final t = tournament;
    final matches =
        ref.watch(matchesProvider(t.id)).valueOrNull ?? const [];
    final history = TeamProfile.matchesFor(team.id, matches);
    final form = TeamProfile.form(history);
    final next = TeamProfile.next(history);

    final table = Standings.compute(
      sport: t.sport,
      settings: t.settings,
      teams: teams,
      matches: matches,
    );
    final index = table.indexWhereTeam(team.id);
    final row = index < 0 ? null : table[index];
    final anyPlayed = table.any((r) => r.played > 0);
    final color = Color(team.colorValue);

    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        Row(
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                team.shortName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    team.name,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (row != null && anyPlayed)
                    Text(
                      'Ranked ${index + 1} of ${table.length}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (row != null && row.played > 0) ...[
          const SizedBox(height: 18),
          Row(
            children: [
              _Stat('Played', '${row.played}'),
              _Stat('Won', '${row.won}'),
              if (t.sport != Sport.badminton || row.drawn > 0)
                _Stat('Drawn', '${row.drawn}'),
              _Stat('Lost', '${row.lost}'),
              _Stat('Points', '${row.points}', color: t.sport.color),
            ],
          ),
        ],
        if (form.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text('Form', style: _heading(theme)),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final f in form) _FormChip(f),
              const SizedBox(width: 8),
              Text(
                'oldest to latest',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
        if (team.players.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(
            t.sport == Sport.badminton ? 'Pair' : 'Squad',
            style: _heading(theme),
          ),
          const SizedBox(height: 6),
          for (final p in team.players)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(p, style: theme.textTheme.bodyMedium),
            ),
        ],
        const SizedBox(height: 18),
        Text('Matches', style: _heading(theme)),
        const SizedBox(height: 6),
        if (history.isEmpty)
          Text(
            'No matches yet. They appear once fixtures are drawn.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          for (final h in history)
            _MatchLine(
              sport: t.sport,
              entry: h,
              highlight: identical(h, next),
            ),
      ],
    );
  }

  TextStyle? _heading(ThemeData theme) =>
      theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800);
}

extension on List<Standing> {
  int indexWhereTeam(String id) => indexWhere((r) => r.team.id == id);
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, {this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _FormChip extends StatelessWidget {
  const _FormChip(this.result);

  final FormResult result;

  @override
  Widget build(BuildContext context) {
    final color = switch (result) {
      FormResult.win => const Color(0xFF16A34A),
      FormResult.draw => const Color(0xFF9CA3AF),
      FormResult.loss => const Color(0xFFDC2626),
    };
    return Container(
      width: 30,
      height: 30,
      margin: const EdgeInsets.only(right: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(
        result.letter,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _MatchLine extends StatelessWidget {
  const _MatchLine({
    required this.sport,
    required this.entry,
    required this.highlight,
  });

  final Sport sport;
  final TeamMatch entry;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = entry.match;
    final score = m.score;

    String? scoreText;
    if (entry.isPlayed && score != null) {
      final mine = MatchRules.sideScore(
        sport: sport,
        score: score,
        sideA: entry.isSideA,
      );
      final theirs = MatchRules.sideScore(
        sport: sport,
        score: score,
        sideA: !entry.isSideA,
      );
      scoreText = '$mine - $theirs';
    }

    final when = m.scheduledAt == null
        ? null
        : '${formatDate(m.scheduledAt!)}'
            '${m.venue.isEmpty ? '' : ' at ${m.venue}'}';

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlight
            ? sport.color.withValues(alpha: 0.10)
            : theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: entry.result == null
                ? Icon(
                    Icons.schedule_rounded,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  )
                : _FormChip(entry.result!),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'vs ${entry.opponentName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  [
                    m.roundLabel,
                    if (highlight) 'Next',
                    if (when != null) when,
                  ].join('  |  '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (scoreText != null)
            Text(
              scoreText,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
        ],
      ),
    );
  }
}

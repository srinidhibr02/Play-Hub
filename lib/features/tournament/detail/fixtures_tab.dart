import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:play_hub/core/navigation/app_route.dart';
import 'package:play_hub/core/utils/formatters.dart';
import 'package:play_hub/core/widgets/empty_state.dart';
import 'package:play_hub/core/widgets/entrance.dart';
import 'package:play_hub/features/tournament/detail/match_tile.dart';
import 'package:play_hub/features/tournament/score/match_score_screen.dart';
import 'package:play_hub/models/team.dart';
import 'package:play_hub/models/tournament.dart';
import 'package:play_hub/models/tournament_match.dart';
import 'package:play_hub/providers/providers.dart';

class FixturesTab extends ConsumerStatefulWidget {
  const FixturesTab({
    super.key,
    required this.tournament,
    required this.isOwner,
  });

  final Tournament tournament;
  final bool isOwner;

  @override
  ConsumerState<FixturesTab> createState() => _FixturesTabState();
}

class _FixturesTabState extends ConsumerState<FixturesTab> {
  bool _shuffle = true;
  bool _busy = false;

  Tournament get _t => widget.tournament;

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(110, 44),
              backgroundColor: destructive
                  ? Theme.of(context).colorScheme.error
                  : _t.sport.color,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _generate(List<Team> teams) async {
    final ok = await _confirm(
      title: 'Generate fixtures?',
      message:
          'Entries will be locked once the fixtures are drawn. You can reset '
          'the fixtures later if you need to make changes.',
      action: 'Generate',
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    try {
      final count = await ref
          .read(tournamentRepositoryProvider)
          .generateFixtures(tournament: _t, teams: teams, shuffle: _shuffle);
      _toast('${pluralize(count, 'match', 'matches')} created.');
    } catch (e) {
      _toast('Could not create fixtures. Check your connection and retry.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    final ok = await _confirm(
      title: 'Reset fixtures?',
      message:
          'All fixtures and any scores entered will be deleted. This cannot '
          'be undone.',
      action: 'Reset',
      destructive: true,
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(tournamentRepositoryProvider).resetFixtures(_t.id);
      _toast('Fixtures reset.');
    } catch (e) {
      _toast('Could not reset fixtures. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final matchesAsync = ref.watch(matchesProvider(_t.id));
    final teamsAsync = ref.watch(teamsProvider(_t.id));

    return matchesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => const EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Could not load fixtures',
        message: 'Check your connection and try again.',
      ),
      data: (matches) {
        // Byes are stored so the bracket stays intact but are not shown.
        final visible = matches.where((m) => !m.isBye).toList();
        if (visible.isEmpty) {
          return _buildEmpty(teamsAsync.valueOrNull ?? const <Team>[]);
        }
        return _buildList(visible);
      },
    );
  }

  Widget _buildEmpty(List<Team> teams) {
    final theme = Theme.of(context);
    final sport = _t.sport;

    if (!widget.isOwner) {
      return EmptyState(
        icon: Icons.event_note_rounded,
        color: sport.color,
        title: 'Fixtures not published yet',
        message: 'The organizer has not drawn the fixtures. Check back soon.',
      );
    }

    final enoughTeams = teams.length >= 2;
    final isKnockout = _t.format == TournamentFormat.knockout;

    return ListView(
      key: const PageStorageKey('fixtures-empty'),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: sport.color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(Icons.casino_rounded, color: sport.color),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ready to draw?',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${pluralize(teams.length, 'entry', 'entries')} added',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  isKnockout
                      ? 'A knockout bracket will be created. With an uneven '
                          'number of entries, some get a bye into the next '
                          'round.'
                      : _t.settings.legs == 2
                          ? 'A home-and-away league will be created: every '
                              'entry plays every other entry twice.'
                          : 'A league will be created: every entry plays '
                              'every other entry once.',
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _shuffle,
                  onChanged: (value) => setState(() => _shuffle = value),
                  title: const Text(
                    'Shuffle the draw',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    _shuffle
                        ? 'Entries are placed at random.'
                        : 'Entries are placed in the order they were added.',
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: sport.color),
                  onPressed: (enoughTeams && !_busy)
                      ? () => _generate(teams)
                      : null,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.bolt_rounded),
                  label: const Text('Generate fixtures'),
                ),
                if (!enoughTeams) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Add at least 2 entries in the Teams tab first.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ).entrance(),
      ],
    );
  }

  Widget _buildList(List<TournamentMatch> matches) {
    final theme = Theme.of(context);
    final accent = _t.sport.color;

    // Flat list of round headers and match tiles.
    final items = <Widget>[];
    int? currentRound;
    var index = 0;
    for (final match in matches) {
      if (match.round != currentRound) {
        currentRound = match.round;
        final inRound = matches.where((m) => m.round == match.round).length;
        items.add(
          Padding(
            padding: EdgeInsets.only(top: items.isEmpty ? 0 : 20, bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  match.roundLabel,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  pluralize(inRound, 'match', 'matches'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      }
      final canScore = widget.isOwner && match.hasBothTeams;
      items.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: MatchTile(
            match: match,
            sport: _t.sport,
            onTap: canScore
                ? () => Navigator.of(context).push(
                      appRoute(MatchScoreScreen(tournament: _t, match: match)),
                    )
                : null,
          ).entrance(index: index),
        ),
      );
      index++;
    }

    if (widget.isOwner) {
      items.add(
        Padding(
          padding: const EdgeInsets.only(top: 24),
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
              side: BorderSide(color: theme.colorScheme.error),
            ),
            onPressed: _busy ? null : _reset,
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('Reset fixtures'),
          ),
        ),
      );
    }

    return ListView.builder(
      key: const PageStorageKey('fixtures-list'),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      itemCount: items.length,
      itemBuilder: (context, i) => items[i],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:play_hub/core/utils/share.dart';
import 'package:play_hub/core/widgets/entrance.dart';
import 'package:play_hub/features/tournament/score/lineup_sheet.dart';
import 'package:play_hub/features/tournament/score/match_event_sheet.dart';
import 'package:play_hub/features/tournament/score/scorecard_sheets.dart';
import 'package:play_hub/logic/match_events.dart';
import 'package:play_hub/logic/match_rules.dart';
import 'package:play_hub/logic/scorecard.dart';
import 'package:play_hub/logic/share_text.dart';
import 'package:play_hub/models/sport.dart';
import 'package:play_hub/models/tournament.dart';
import 'package:play_hub/models/tournament_match.dart';
import 'package:play_hub/providers/providers.dart';
import 'package:play_hub/services/tournament_repository.dart';

/// Result of checking the form: the score built from the inputs and either
/// an error or a one-line summary.
class _Evaluation {
  const _Evaluation({this.score, this.winnerId, this.error, this.summary});

  final MatchScore? score;
  final String? winnerId;
  final String? error;
  final String? summary;

  bool get isValid => error == null && score != null;
}

class _GameInput {
  _GameInput({int? a, int? b})
      : a = TextEditingController(text: a?.toString() ?? ''),
        b = TextEditingController(text: b?.toString() ?? '');

  final TextEditingController a;
  final TextEditingController b;

  void dispose() {
    a.dispose();
    b.dispose();
  }
}

/// Lets the organizer enter or edit the score of one match.
class MatchScoreScreen extends ConsumerStatefulWidget {
  const MatchScoreScreen({
    super.key,
    required this.tournament,
    required this.match,
  });

  final Tournament tournament;
  final TournamentMatch match;

  @override
  ConsumerState<MatchScoreScreen> createState() => _MatchScoreScreenState();
}

class _MatchScoreScreenState extends ConsumerState<MatchScoreScreen> {
  // Football
  int _goalsA = 0;
  int _goalsB = 0;
  int _pensA = 0;
  int _pensB = 0;
  List<MatchEvent> _events = [];
  List<String> _lineupA = [];
  List<String> _lineupB = [];

  // Cricket
  bool _battedFirstA = true;
  final _runsA = TextEditingController();
  final _runsB = TextEditingController();
  final _oversA = TextEditingController();
  final _oversB = TextEditingController();
  int _wicketsA = 0;
  int _wicketsB = 0;
  String? _tieBreakId;
  List<BatterLine> _battersA = [];
  List<BatterLine> _battersB = [];
  List<BowlerLine> _bowlersA = [];
  List<BowlerLine> _bowlersB = [];

  // Badminton
  final List<_GameInput> _games = [];

  bool _saving = false;
  bool _showError = false;

  Tournament get _t => widget.tournament;
  TournamentMatch get _m => widget.match;
  Sport get _sport => _t.sport;
  bool get _knockout => _t.format == TournamentFormat.knockout;
  String get _nameA => _m.teamAName ?? 'Team A';
  String get _nameB => _m.teamBName ?? 'Team B';

  @override
  void initState() {
    super.initState();
    final s = _m.score;

    if (s != null) {
      _goalsA = s.goalsA;
      _goalsB = s.goalsB;
      _pensA = s.penaltiesA ?? 0;
      _pensB = s.penaltiesB ?? 0;
      _events = [...s.events];
      _lineupA = [...s.lineupA];
      _lineupB = [...s.lineupB];

      _battedFirstA = s.battedFirstA;
      _runsA.text = s.runsA == 0 && s.ballsA == 0 ? '' : '${s.runsA}';
      _runsB.text = s.runsB == 0 && s.ballsB == 0 ? '' : '${s.runsB}';
      _oversA.text = s.ballsA == 0 ? '' : MatchRules.oversText(s.ballsA);
      _oversB.text = s.ballsB == 0 ? '' : MatchRules.oversText(s.ballsB);
      _wicketsA = s.wicketsA;
      _wicketsB = s.wicketsB;
      if (s.runsA == s.runsB) _tieBreakId = _m.winnerId;
      _battersA = [...s.battersA];
      _battersB = [...s.battersB];
      _bowlersA = [...s.bowlersA];
      _bowlersB = [...s.bowlersB];

      for (final g in s.games) {
        _games.add(_GameInput(a: g.a, b: g.b));
      }
    }
    if (_games.isEmpty) _games.add(_GameInput());
  }

  @override
  void dispose() {
    _runsA.dispose();
    _runsB.dispose();
    _oversA.dispose();
    _oversB.dispose();
    for (final g in _games) {
      g.dispose();
    }
    super.dispose();
  }

  // ------------------------------------------------------------ evaluation

  int _intOf(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;

  _Evaluation _evaluate() {
    final teamA = _m.teamAId!;
    final teamB = _m.teamBId!;
    MatchScore score;

    switch (_sport) {
      case Sport.football:
        final usePens = _knockout && _goalsA == _goalsB;
        score = MatchScore(
          goalsA: _goalsA,
          goalsB: _goalsB,
          penaltiesA: usePens ? _pensA : null,
          penaltiesB: usePens ? _pensB : null,
          events: _events,
          lineupA: _lineupA,
          lineupB: _lineupB,
        );
      case Sport.cricket:
        final ballsA = MatchRules.parseOvers(
          _oversA.text.trim().isEmpty ? '0' : _oversA.text,
        );
        final ballsB = MatchRules.parseOvers(
          _oversB.text.trim().isEmpty ? '0' : _oversB.text,
        );
        if (ballsA == null || ballsB == null) {
          return const _Evaluation(
            error: 'Overs should look like 9.3 (an over has 6 balls, so the '
                'part after the dot goes up to 5).',
          );
        }
        score = MatchScore(
          runsA: _intOf(_runsA),
          wicketsA: _wicketsA,
          ballsA: ballsA,
          runsB: _intOf(_runsB),
          wicketsB: _wicketsB,
          ballsB: ballsB,
          battedFirstA: _battedFirstA,
          battersA: _battersA,
          battersB: _battersB,
          bowlersA: _bowlersA,
          bowlersB: _bowlersB,
        );
      case Sport.badminton:
        final games = <GameScore>[];
        for (var i = 0; i < _games.length; i++) {
          final aText = _games[i].a.text.trim();
          final bText = _games[i].b.text.trim();
          if (aText.isEmpty && bText.isEmpty) continue; // unused row
          if (aText.isEmpty || bText.isEmpty) {
            return _Evaluation(error: 'Game ${i + 1} is incomplete.');
          }
          games.add(GameScore(int.parse(aText), int.parse(bText)));
        }
        score = MatchScore(games: games);
    }

    final tied = _sport == Sport.cricket && score.runsA == score.runsB;
    final tieBreak = tied ? _tieBreakId : null;

    final error = MatchRules.validate(
          sport: _sport,
          settings: _t.settings,
          score: score,
          knockout: _knockout,
          teamAId: teamA,
          teamBId: teamB,
          tieBreakWinnerId: tieBreak,
        ) ??
        (_sport == Sport.football
            ? MatchEvents.validate(
                events: score.events,
                goalsA: score.goalsA,
                goalsB: score.goalsB,
                teamAId: teamA,
                teamBId: teamB,
              )
            : null) ??
        (_sport == Sport.football
            ? MatchEvents.validateLineups(
                lineupA: score.lineupA,
                lineupB: score.lineupB,
                events: score.events,
                teamAId: teamA,
                teamBId: teamB,
              )
            : null) ??
        (_sport == Sport.cricket
            ? Scorecard.validate(
                score: score,
                oversPerSide: _t.settings.overs,
                nameA: _nameA,
                nameB: _nameB,
              )
            : null);
    final winner = MatchRules.winnerId(
      sport: _sport,
      score: score,
      teamAId: teamA,
      teamBId: teamB,
      tieBreakWinnerId: tieBreak,
    );
    return _Evaluation(
      score: score,
      winnerId: winner,
      error: error,
      summary: error == null
          ? MatchRules.summary(
              sport: _sport,
              score: score,
              teamAName: _m.teamAName,
              teamBName: _m.teamBName,
              teamAId: teamA,
              winnerId: winner,
            )
          : null,
    );
  }

  // --------------------------------------------------------------- actions

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _errorText(Object e) =>
      e is ResultException ? e.message : 'Something went wrong. Try again.';

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final evaluation = _evaluate();
    if (!evaluation.isValid) {
      setState(() => _showError = true);
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(tournamentRepositoryProvider).saveResult(
            tournamentId: _t.id,
            matchId: _m.id,
            score: evaluation.score!,
            winnerId: evaluation.winnerId,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast(_errorText(e));
    }
  }

  Future<void> _setLive(bool live) async {
    try {
      await ref
          .read(tournamentRepositoryProvider)
          .setMatchLive(_t.id, _m.id, live: live);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      _toast(_errorText(e));
    }
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear this result?'),
        content: const Text(
          'The score will be removed and the match goes back to scheduled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(110, 44),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref
          .read(tournamentRepositoryProvider)
          .clearResult(tournamentId: _t.id, matchId: _m.id);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      _toast(_errorText(e));
    }
  }

  // ----------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final evaluation = _evaluate();
    final isCompleted = _m.status == MatchStatus.completed;
    final isLive = _m.status == MatchStatus.live;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _m.roundLabel,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          // Shares what is saved, so save the score first.
          IconButton(
            tooltip: 'Share saved result',
            icon: const Icon(Icons.share_outlined),
            onPressed: () => shareText(
              context,
              ShareText.match(tournament: _t, match: _m),
              subject: _t.name,
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'live':
                  _setLive(true);
                case 'scheduled':
                  _setLive(false);
                case 'clear':
                  _clear();
              }
            },
            itemBuilder: (context) => [
              if (!isCompleted && !isLive)
                const PopupMenuItem(value: 'live', child: Text('Mark as live')),
              if (isLive)
                const PopupMenuItem(
                  value: 'scheduled',
                  child: Text('Back to scheduled'),
                ),
              if (isCompleted)
                const PopupMenuItem(
                  value: 'clear',
                  child: Text('Clear result'),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                _Scoreboard(
                  sport: _sport,
                  nameA: _nameA,
                  nameB: _nameB,
                  score: evaluation.score ?? const MatchScore(),
                  winnerId: evaluation.winnerId,
                  teamAId: _m.teamAId!,
                ).entrance(),
                const SizedBox(height: 20),
                switch (_sport) {
                  Sport.football => _buildFootball(),
                  Sport.cricket => _buildCricket(evaluation),
                  Sport.badminton => _buildBadminton(),
                },
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: _showError && evaluation.error != null
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _Banner(
                              icon: Icons.error_outline_rounded,
                              color: theme.colorScheme.error,
                              text: evaluation.error!,
                            ),
                          )
                        : evaluation.summary != null
                            ? Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _Banner(
                                  icon: Icons.emoji_events_rounded,
                                  color: _sport.color,
                                  text: evaluation.summary!,
                                ),
                              )
                            : const SizedBox(width: double.infinity),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _sport.color,
                    ),
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Text(isCompleted ? 'Update result' : 'Save result'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------- football

  Widget _buildFootball() {
    final showPens = _knockout && _goalsA == _goalsB;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Panel(
          title: 'Goals',
          child: Row(
            children: [
              Expanded(
                child: _Counter(
                  label: _nameA,
                  value: _goalsA,
                  max: MatchRules.maxFootballGoals,
                  onChanged: (v) => setState(() => _goalsA = v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Counter(
                  label: _nameB,
                  value: _goalsB,
                  max: MatchRules.maxFootballGoals,
                  onChanged: (v) => setState(() => _goalsB = v),
                ),
              ),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: showPens
              ? Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: _Panel(
                    title: 'Penalty shoot-out',
                    subtitle: 'Knockout matches cannot end level.',
                    child: Row(
                      children: [
                        Expanded(
                          child: _Counter(
                            label: _nameA,
                            value: _pensA,
                            max: 30,
                            onChanged: (v) => setState(() => _pensA = v),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _Counter(
                            label: _nameB,
                            value: _pensB,
                            max: 30,
                            onChanged: (v) => setState(() => _pensB = v),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        const SizedBox(height: 14),
        _buildLineups(),
        const SizedBox(height: 14),
        _buildEvents(),
      ],
    );
  }

  // ----------------------------------------------------------- football events

  List<String> _squadOf(String? teamId) {
    final teams = ref.read(teamsProvider(_t.id)).valueOrNull ?? const [];
    for (final team in teams) {
      if (team.id == teamId) return team.players;
    }
    return const [];
  }

  String _teamName(String teamId) =>
      teamId == _m.teamAId ? _nameA : _nameB;

  Future<void> _editLineup(bool sideA) async {
    final result = await showLineupSheet(
      context,
      teamName: sideA ? _nameA : _nameB,
      squad: _squadOf(sideA ? _m.teamAId : _m.teamBId),
      initial: sideA ? _lineupA : _lineupB,
      accent: _sport.color,
    );
    if (result == null || !mounted) return;
    setState(() {
      if (sideA) {
        _lineupA = result;
      } else {
        _lineupB = result;
      }
    });
  }

  Widget _buildLineups() {
    final theme = Theme.of(context);

    Widget row(bool sideA) {
      final name = sideA ? _nameA : _nameB;
      final lineup = sideA ? _lineupA : _lineupB;
      return ListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          lineup.isEmpty ? 'Not set' : lineup.join(', '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: TextButton(
          onPressed: () => _editLineup(sideA),
          child: Text(lineup.isEmpty ? 'Set' : 'Edit'),
        ),
        onTap: () => _editLineup(sideA),
      );
    }

    return _Panel(
      title: 'Lineups',
      subtitle: 'Optional. With a lineup, substitutions are checked against '
          'who is on the pitch, and players get appearances.',
      child: Column(
        children: [
          row(true),
          Divider(
            height: 1,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
          row(false),
        ],
      ),
    );
  }

  Future<void> _editEvent({MatchEvent? existing, int? index}) async {
    final event = await showMatchEventSheet(
      context,
      teamAId: _m.teamAId!,
      teamBId: _m.teamBId!,
      nameA: _nameA,
      nameB: _nameB,
      squadA: _squadOf(_m.teamAId),
      squadB: _squadOf(_m.teamBId),
      accent: _sport.color,
      initial: existing,
    );
    if (event == null || !mounted) return;

    setState(() {
      if (index == null) {
        _events = [..._events, event];
      } else {
        _events = [..._events]..[index] = event;
      }
      // Keep the scoreline in step: if the events now credit more goals than
      // the score shows, raise the score to match.
      final (a, b) = MatchEvents.credited(_events, _m.teamAId!, _m.teamBId!);
      if (a > _goalsA) _goalsA = a;
      if (b > _goalsB) _goalsB = b;
    });
  }

  void _removeEvent(int index) {
    setState(() => _events = [..._events]..removeAt(index));
  }

  Widget _buildEvents() {
    final theme = Theme.of(context);
    final ordered = MatchEvents.sorted(_events);
    final (ca, cb) = MatchEvents.credited(_events, _m.teamAId!, _m.teamBId!);
    final missing = (_goalsA - ca) + (_goalsB - cb);

    IconData iconOf(MatchEventType t) => switch (t) {
          MatchEventType.goal => Icons.sports_soccer_rounded,
          MatchEventType.penaltyGoal => Icons.adjust_rounded,
          MatchEventType.ownGoal => Icons.replay_rounded,
          MatchEventType.yellowCard => Icons.style_rounded,
          MatchEventType.redCard => Icons.style_rounded,
          MatchEventType.substitution => Icons.swap_vert_rounded,
        };
    Color colorOf(MatchEventType t) => switch (t) {
          MatchEventType.yellowCard => const Color(0xFFEAB308),
          MatchEventType.redCard => const Color(0xFFDC2626),
          _ => _sport.color,
        };

    return _Panel(
      title: 'Match events',
      subtitle: 'Scorers, assists and cards. Optional, but they feed the '
          'top scorer and discipline tables.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (ordered.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'No events recorded yet.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          for (final e in ordered)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(iconOf(e.type), color: colorOf(e.type)),
              title: Text(
                e.type.isSubstitution
                    ? '${e.player} on, ${e.playerOff} off'
                    : e.player,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                [
                  '${e.type.label} · ${_teamName(e.teamId)}',
                  if (e.assist.isNotEmpty) 'assist ${e.assist}',
                ].join(' · '),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (e.minute != null)
                    Text(
                      "${e.minute}'",
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  IconButton(
                    tooltip: 'Remove',
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => _removeEvent(_events.indexOf(e)),
                  ),
                ],
              ),
              onTap: () => _editEvent(
                existing: e,
                index: _events.indexOf(e),
              ),
            ),
          if (missing > 0 && _events.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '$missing ${missing == 1 ? 'goal has' : 'goals have'} no '
                'scorer recorded.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          OutlinedButton.icon(
            onPressed: _editEvent,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add goal or card'),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- cricket

  Widget _buildCricket(_Evaluation evaluation) {
    final firstIsA = _battedFirstA;
    final tied = evaluation.score != null &&
        evaluation.score!.runsA == evaluation.score!.runsB;

    Widget innings({
      required String title,
      required String team,
      required TextEditingController runs,
      required TextEditingController overs,
      required int wickets,
      required ValueChanged<int> onWickets,
    }) {
      return _Panel(
        title: title,
        subtitle: team,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: runs,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(3),
                    ],
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(labelText: 'Runs'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: overs,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      LengthLimitingTextInputFormatter(5),
                    ],
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Overs',
                      hintText: '0 - ${_t.settings.overs}',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _Counter(
              label: 'Wickets lost',
              value: wickets,
              max: MatchRules.maxCricketWickets,
              compact: true,
              onChanged: onWickets,
            ),
          ],
        ),
      );
    }

    final firstInnings = innings(
      title: '1st innings',
      team: firstIsA ? _nameA : _nameB,
      runs: firstIsA ? _runsA : _runsB,
      overs: firstIsA ? _oversA : _oversB,
      wickets: firstIsA ? _wicketsA : _wicketsB,
      onWickets: (v) => setState(() {
        if (firstIsA) {
          _wicketsA = v;
        } else {
          _wicketsB = v;
        }
      }),
    );
    final secondInnings = innings(
      title: '2nd innings',
      team: firstIsA ? _nameB : _nameA,
      runs: firstIsA ? _runsB : _runsA,
      overs: firstIsA ? _oversB : _oversA,
      wickets: firstIsA ? _wicketsB : _wicketsA,
      onWickets: (v) => setState(() {
        if (firstIsA) {
          _wicketsB = v;
        } else {
          _wicketsA = v;
        }
      }),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Panel(
          title: 'Batted first',
          child: SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: true,
                label: Text(_nameA, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              ButtonSegment(
                value: false,
                label: Text(_nameB, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
            selected: {_battedFirstA},
            onSelectionChanged: (s) => setState(() => _battedFirstA = s.first),
          ),
        ),
        const SizedBox(height: 14),
        firstInnings,
        const SizedBox(height: 14),
        secondInnings,
        const SizedBox(height: 14),
        _buildScorecard(),
        AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: (tied && _knockout)
              ? Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: _Panel(
                    title: 'Tie-break winner',
                    subtitle: 'Scores are level. Who won the super over?',
                    child: Wrap(
                      spacing: 10,
                      children: [
                        for (final entry in [
                          (_m.teamAId!, _nameA),
                          (_m.teamBId!, _nameB),
                        ])
                          ChoiceChip(
                            label: Text(entry.$2),
                            selected: _tieBreakId == entry.$1,
                            selectedColor: _sport.color.withValues(alpha: 0.2),
                            onSelected: (_) =>
                                setState(() => _tieBreakId = entry.$1),
                          ),
                      ],
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  // ------------------------------------------------------- cricket scorecard

  List<String> _squadFor(bool sideA) {
    final id = sideA ? _m.teamAId : _m.teamBId;
    final teams = ref.read(teamsProvider(_t.id)).valueOrNull ?? const [];
    for (final team in teams) {
      if (team.id == id) return team.players;
    }
    return const [];
  }

  Future<void> _editBatter(bool sideA, {int? index}) async {
    final list = sideA ? _battersA : _battersB;
    final existing = index == null ? null : list[index];
    final taken = {
      for (var i = 0; i < list.length; i++)
        if (i != index) list[i].name.trim().toLowerCase(),
    };
    final line = await showBatterSheet(
      context,
      teamName: sideA ? _nameA : _nameB,
      squad: _squadFor(sideA),
      taken: taken,
      accent: _sport.color,
      initial: existing,
    );
    if (line == null || !mounted) return;
    setState(() {
      final next = [...list];
      if (index == null) {
        next.add(line);
      } else {
        next[index] = line;
      }
      if (sideA) {
        _battersA = next;
      } else {
        _battersB = next;
      }
    });
  }

  Future<void> _editBowler(bool sideA, {int? index}) async {
    final list = sideA ? _bowlersA : _bowlersB;
    final existing = index == null ? null : list[index];
    final taken = {
      for (var i = 0; i < list.length; i++)
        if (i != index) list[i].name.trim().toLowerCase(),
    };
    final line = await showBowlerSheet(
      context,
      teamName: sideA ? _nameA : _nameB,
      squad: _squadFor(sideA),
      taken: taken,
      accent: _sport.color,
      initial: existing,
    );
    if (line == null || !mounted) return;
    setState(() {
      final next = [...list];
      if (index == null) {
        next.add(line);
      } else {
        next[index] = line;
      }
      if (sideA) {
        _bowlersA = next;
      } else {
        _bowlersB = next;
      }
    });
  }

  void _removeBatter(bool sideA, int index) => setState(() {
        if (sideA) {
          _battersA = [..._battersA]..removeAt(index);
        } else {
          _battersB = [..._battersB]..removeAt(index);
        }
      });

  void _removeBowler(bool sideA, int index) => setState(() {
        if (sideA) {
          _bowlersA = [..._bowlersA]..removeAt(index);
        } else {
          _bowlersB = [..._bowlersB]..removeAt(index);
        }
      });

  Widget _buildScorecard() {
    final theme = Theme.of(context);
    final order = _battedFirstA ? [true, false] : [false, true];

    Widget side(bool sideA) {
      final name = sideA ? _nameA : _nameB;
      final batters = sideA ? _battersA : _battersB;
      final bowlers = sideA ? _bowlersA : _bowlersB;
      final teamRuns = _intOf(sideA ? _runsA : _runsB);
      final extras = Scorecard.extras(teamRuns, batters);

      Widget heading(String text) => Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 4),
            child: Text(
              text,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: _sport.color,
              ),
            ),
          );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            name,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          heading('Batting'),
          if (batters.isEmpty)
            Text(
              'No batters added.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          for (var i = 0; i < batters.length; i++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                batters[i].name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                batters[i].out
                    ? (batters[i].dismissal.isEmpty
                        ? 'out'
                        : batters[i].dismissal)
                    : 'not out',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${batters[i].runs}'
                    '${batters[i].balls > 0 ? ' (${batters[i].balls})' : ''}'
                    '${batters[i].fours > 0 ? '  ${batters[i].fours}x4' : ''}'
                    '${batters[i].sixes > 0 ? '  ${batters[i].sixes}x6' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  IconButton(
                    tooltip: 'Remove',
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => _removeBatter(sideA, i),
                  ),
                ],
              ),
              onTap: () => _editBatter(sideA, index: i),
            ),
          if (batters.isNotEmpty && extras > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                'Extras and unlisted runs: $extras',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          TextButton.icon(
            onPressed: () => _editBatter(sideA),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add batter'),
          ),
          heading('Bowling'),
          if (bowlers.isEmpty)
            Text(
              'No bowlers added.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          for (var i = 0; i < bowlers.length; i++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                bowlers[i].name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '${MatchRules.oversText(bowlers[i].balls)} ov'
                '${bowlers[i].maidens > 0 ? ' · ${bowlers[i].maidens} maiden' : ''}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${bowlers[i].wickets}/${bowlers[i].runs}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  IconButton(
                    tooltip: 'Remove',
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => _removeBowler(sideA, i),
                  ),
                ],
              ),
              onTap: () => _editBowler(sideA, index: i),
            ),
          TextButton.icon(
            onPressed: () => _editBowler(sideA),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add bowler'),
          ),
        ],
      );
    }

    return _Panel(
      title: 'Scorecard',
      subtitle: 'Optional. Names, runs, wickets and overs feed the run and '
          'wicket leaders. Totals above must stay consistent with them.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          side(order[0]),
          const Divider(height: 28),
          side(order[1]),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- badminton

  Widget _buildBadminton() {
    final theme = Theme.of(context);
    final maxGames = _t.settings.bestOfGames;
    final evaluation = _evaluate();
    final decided = evaluation.error == null;

    return _Panel(
      title: 'Games',
      subtitle: 'Best of $maxGames, to ${_t.settings.pointsPerGame} points',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const SizedBox(width: 64),
              Expanded(
                child: Text(
                  _nameA,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 28),
              Expanded(
                child: Text(
                  _nameB,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < _games.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 64,
                    child: Text(
                      'Game ${i + 1}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(child: _scoreField(_games[i].a)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text('-', style: TextStyle(fontSize: 20)),
                  ),
                  Expanded(child: _scoreField(_games[i].b)),
                  SizedBox(
                    width: 48,
                    child: _games.length > 1
                        ? IconButton(
                            tooltip: 'Remove game',
                            onPressed: () => setState(() {
                              _games.removeAt(i).dispose();
                            }),
                            icon: const Icon(Icons.close_rounded),
                          )
                        : null,
                  ),
                ],
              ),
            ),
          if (_games.length < maxGames && !decided)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _games.add(_GameInput())),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add game'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _scoreField(TextEditingController controller) {
    return TextField(
      controller: controller,
      textAlign: TextAlign.center,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(2),
      ],
      onChanged: (_) => setState(() {}),
      decoration: const InputDecoration(
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      ),
    );
  }
}

// ======================================================================
// Small building blocks
// ======================================================================

class _Scoreboard extends StatelessWidget {
  const _Scoreboard({
    required this.sport,
    required this.nameA,
    required this.nameB,
    required this.score,
    required this.winnerId,
    required this.teamAId,
  });

  final Sport sport;
  final String nameA;
  final String nameB;
  final MatchScore score;
  final String? winnerId;
  final String teamAId;

  @override
  Widget build(BuildContext context) {
    Widget side(String name, bool sideA) {
      final isWinner = winnerId != null && (winnerId == teamAId) == sideA;
      final value = MatchRules.sideScore(
        sport: sport,
        score: score,
        sideA: sideA,
      );
      return Expanded(
        child: Column(
          children: [
            Text(
              name,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontWeight: isWinner ? FontWeight.w900 : FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 10),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: animation,
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: Text(
                value,
                key: ValueKey('$sideA-$value'),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: sport == Sport.cricket ? 34 : 48,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            SizedBox(
              height: 22,
              child: isWinner
                  ? const Icon(
                      Icons.emoji_events_rounded,
                      color: Color(0xFFFCD34D),
                      size: 20,
                    )
                  : null,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
      decoration: BoxDecoration(
        gradient: sport.gradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: sport.color.withValues(alpha: 0.3),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          side(nameA, true),
          Padding(
            padding: const EdgeInsets.only(top: 30),
            child: Text(
              'vs',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          side(nameB, false),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title.toUpperCase(),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

/// A − value + control. The large form is used for goals; [compact] gives a
/// one-line label/stepper row.
class _Counter extends StatelessWidget {
  const _Counter({
    required this.label,
    required this.value,
    required this.onChanged,
    this.max = 99,
    this.compact = false,
  });

  final String label;
  final int value;
  final int max;
  final bool compact;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final minus = IconButton.filledTonal(
      onPressed: value > 0 ? () => onChanged(value - 1) : null,
      icon: const Icon(Icons.remove_rounded),
    );
    final plus = IconButton.filledTonal(
      onPressed: value < max ? () => onChanged(value + 1) : null,
      icon: const Icon(Icons.add_rounded),
    );
    final number = SizedBox(
      width: compact ? 48 : 56,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 160),
        transitionBuilder: (child, animation) =>
            ScaleTransition(scale: animation, child: child),
        child: Text(
          '$value',
          key: ValueKey(value),
          textAlign: TextAlign.center,
          style: (compact
                  ? theme.textTheme.titleLarge
                  : theme.textTheme.headlineMedium)
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
      ),
    );

    if (compact) {
      return Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          minus,
          number,
          plus,
        ],
      );
    }

    return Column(
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [minus, number, plus],
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

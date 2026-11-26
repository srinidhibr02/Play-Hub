import 'package:play_hub/models/tournament_match.dart';

enum FormResult {
  win('W'),
  draw('D'),
  loss('L');

  const FormResult(this.letter);
  final String letter;
}

/// One match seen from a single team's side.
class TeamMatch {
  const TeamMatch({
    required this.match,
    required this.opponentName,
    required this.isSideA,
    required this.result,
  });

  final TournamentMatch match;
  final String opponentName;

  /// True when the team is side A of the match.
  final bool isSideA;

  /// Null until the match is completed.
  final FormResult? result;

  bool get isPlayed => result != null;
}

/// A team's match history and recent form. Pure Dart.
class TeamProfile {
  const TeamProfile._();

  /// Every real (non-bye) match the team is in, in playing order.
  static List<TeamMatch> matchesFor(
    String teamId,
    List<TournamentMatch> matches,
  ) {
    final mine = matches
        .where((m) => !m.isBye && (m.teamAId == teamId || m.teamBId == teamId))
        .toList()
      ..sort((x, y) {
        final c = x.round.compareTo(y.round);
        return c != 0 ? c : x.order.compareTo(y.order);
      });

    return [
      for (final m in mine)
        TeamMatch(
          match: m,
          isSideA: m.teamAId == teamId,
          opponentName: (m.teamAId == teamId ? m.teamBName : m.teamAName) ??
              'To be decided',
          result: _result(teamId, m),
        ),
    ];
  }

  static FormResult? _result(String teamId, TournamentMatch m) {
    if (!m.isCompleted || m.score == null) return null;
    final winner = m.winnerId;
    if (winner == null) return FormResult.draw;
    return winner == teamId ? FormResult.win : FormResult.loss;
  }

  /// The most recent played results, oldest first (so the newest is last).
  static List<FormResult> form(List<TeamMatch> history, {int limit = 5}) {
    final played = [
      for (final h in history)
        if (h.result != null) h.result!,
    ];
    return played.length <= limit
        ? played
        : played.sublist(played.length - limit);
  }

  /// The first match not yet completed, or null.
  static TeamMatch? next(List<TeamMatch> history) {
    for (final h in history) {
      if (!h.isPlayed) return h;
    }
    return null;
  }
}

import 'package:play_hub/models/sport.dart';
import 'package:play_hub/models/tournament.dart';
import 'package:play_hub/models/tournament_match.dart';

/// Rules for scoring a match: validation, deciding the winner and writing a
/// one-line result. Pure Dart so it can be tested without Firebase.
class MatchRules {
  const MatchRules._();

  static const int maxCricketWickets = 10;
  static const int maxFootballGoals = 99;
  static const int maxCricketRuns = 999;

  // ------------------------------------------------------------- cricket util

  /// Formats a ball count as overs, e.g. 57 -> "9.3".
  static String oversText(int balls) => '${balls ~/ 6}.${balls % 6}';

  /// Parses "9", "9.3" or "0.5" into balls. Returns null if invalid (for
  /// example "9.6", "-1" or "abc").
  static int? parseOvers(String input) {
    final text = input.trim();
    if (text.isEmpty) return null;
    final match = RegExp(r'^(\d{1,3})(?:\.(\d))?$').firstMatch(text);
    if (match == null) return null;
    final whole = int.parse(match.group(1)!);
    final part = match.group(2) == null ? 0 : int.parse(match.group(2)!);
    if (part > 5) return null;
    return whole * 6 + part;
  }

  // --------------------------------------------------------- badminton util

  /// Highest score a single game can reach (the "golden point" cap).
  static int gameCap(int pointsPerGame) => switch (pointsPerGame) {
        21 => 30,
        15 => 21,
        11 => 15,
        _ => pointsPerGame + 9,
      };

  /// Games a side must win to take a best-of-[bestOf] match.
  static int gamesToWin(int bestOf) => bestOf ~/ 2 + 1;

  /// Whether [a]-[b] is a finished badminton game.
  static bool isValidGame(int a, int b, int pointsPerGame) {
    if (a < 0 || b < 0) return false;
    final hi = a > b ? a : b;
    final lo = a > b ? b : a;
    final cap = gameCap(pointsPerGame);

    if (hi < pointsPerGame || hi > cap) return false;
    if (hi == cap) return lo >= cap - 2; // 30-28, 30-29
    if (hi == pointsPerGame) return hi - lo >= 2; // 21-19 or better
    return hi - lo == 2; // deuce: 22-20, 23-21, ...
  }

  /// Games won by each side.
  static (int, int) gamesWon(List<GameScore> games) {
    var a = 0;
    var b = 0;
    for (final g in games) {
      if (g.a > g.b) a++;
      if (g.b > g.a) b++;
    }
    return (a, b);
  }

  // ----------------------------------------------------------------- winner

  /// Who won, or null for a draw or tie. [tieBreakWinnerId] is only used
  /// for a cricket tie (super over) in a knockout.
  static String? winnerId({
    required Sport sport,
    required MatchScore score,
    required String teamAId,
    required String teamBId,
    String? tieBreakWinnerId,
  }) {
    switch (sport) {
      case Sport.football:
        if (score.goalsA != score.goalsB) {
          return score.goalsA > score.goalsB ? teamAId : teamBId;
        }
        final pa = score.penaltiesA;
        final pb = score.penaltiesB;
        if (pa != null && pb != null && pa != pb) {
          return pa > pb ? teamAId : teamBId;
        }
        return null;
      case Sport.cricket:
        if (score.runsA != score.runsB) {
          return score.runsA > score.runsB ? teamAId : teamBId;
        }
        if (tieBreakWinnerId == teamAId || tieBreakWinnerId == teamBId) {
          return tieBreakWinnerId;
        }
        return null;
      case Sport.badminton:
        final (a, b) = gamesWon(score.games);
        if (a == b) return null;
        return a > b ? teamAId : teamBId;
    }
  }

  // ------------------------------------------------------------- validation

  /// Returns a message describing the first problem with the score, or null
  /// if it can be saved.
  static String? validate({
    required Sport sport,
    required TournamentSettings settings,
    required MatchScore score,
    required bool knockout,
    required String teamAId,
    required String teamBId,
    String? tieBreakWinnerId,
  }) {
    switch (sport) {
      case Sport.football:
        return _validateFootball(score, knockout);
      case Sport.cricket:
        return _validateCricket(
          score,
          settings,
          knockout,
          teamAId,
          teamBId,
          tieBreakWinnerId,
        );
      case Sport.badminton:
        return _validateBadminton(score, settings);
    }
  }

  static String? _validateFootball(MatchScore s, bool knockout) {
    if (s.goalsA < 0 || s.goalsB < 0) return 'Goals cannot be negative.';
    if (s.goalsA > maxFootballGoals || s.goalsB > maxFootballGoals) {
      return 'That many goals looks like a typo.';
    }
    if (knockout && s.goalsA == s.goalsB) {
      final pa = s.penaltiesA;
      final pb = s.penaltiesB;
      if (pa == null || pb == null) {
        return 'A knockout match cannot end level. Enter the penalty '
            'shoot-out score.';
      }
      if (pa < 0 || pb < 0) return 'Penalties cannot be negative.';
      if (pa == pb) return 'The penalty shoot-out needs a winner.';
    }
    return null;
  }

  static String? _validateCricket(
    MatchScore s,
    TournamentSettings settings,
    bool knockout,
    String teamAId,
    String teamBId,
    String? tieBreakWinnerId,
  ) {
    if (s.runsA < 0 || s.runsB < 0) return 'Runs cannot be negative.';
    if (s.runsA > maxCricketRuns || s.runsB > maxCricketRuns) {
      return 'That many runs looks like a typo.';
    }
    for (final wickets in [s.wicketsA, s.wicketsB]) {
      if (wickets < 0 || wickets > maxCricketWickets) {
        return 'Wickets must be between 0 and $maxCricketWickets.';
      }
    }
    final maxBalls = settings.overs * 6;
    if (s.ballsA < 0 ||
        s.ballsB < 0 ||
        s.ballsA > maxBalls ||
        s.ballsB > maxBalls) {
      return 'Overs cannot be more than ${settings.overs}.';
    }
    if (knockout && s.runsA == s.runsB) {
      if (tieBreakWinnerId != teamAId && tieBreakWinnerId != teamBId) {
        return 'The scores are tied. Pick who won the super over / '
            'tie-break.';
      }
    }
    return null;
  }

  static String? _validateBadminton(MatchScore s, TournamentSettings settings) {
    final games = s.games;
    if (games.isEmpty) return 'Enter at least one game.';
    if (games.length > settings.bestOfGames) {
      return 'A best-of-${settings.bestOfGames} match has at most '
          '${settings.bestOfGames} games.';
    }

    final need = gamesToWin(settings.bestOfGames);
    var a = 0;
    var b = 0;
    for (var i = 0; i < games.length; i++) {
      if (a >= need || b >= need) {
        return 'The match was already decided before game ${i + 1}.';
      }
      final g = games[i];
      if (!isValidGame(g.a, g.b, settings.pointsPerGame)) {
        return 'Game ${i + 1} (${g.a}-${g.b}) is not a valid finished game '
            'to ${settings.pointsPerGame}.';
      }
      if (g.a > g.b) a++;
      if (g.b > g.a) b++;
    }
    if (a < need && b < need) {
      return 'The match is not decided yet. A side needs $need games.';
    }
    return null;
  }

  // ---------------------------------------------------------------- summary

  /// One-line description of a finished match, e.g. "Falcons won 3-1".
  static String summary({
    required Sport sport,
    required MatchScore score,
    required String? teamAName,
    required String? teamBName,
    required String? teamAId,
    required String? winnerId,
  }) {
    final a = teamAName ?? 'Team A';
    final b = teamBName ?? 'Team B';
    final winnerIsA = winnerId != null && winnerId == teamAId;
    final winnerName = winnerId == null ? null : (winnerIsA ? a : b);

    switch (sport) {
      case Sport.football:
        final pa = score.penaltiesA;
        final pb = score.penaltiesB;
        final goals = '${score.goalsA}-${score.goalsB}';
        if (winnerName == null) return 'Draw $goals';
        if (score.goalsA == score.goalsB && pa != null && pb != null) {
          final winnerPens = winnerIsA ? pa : pb;
          final loserPens = winnerIsA ? pb : pa;
          return '$winnerName won $winnerPens-$loserPens on penalties '
              '($goals)';
        }
        return '$winnerName won $goals';

      case Sport.cricket:
        if (score.runsA == score.runsB) {
          return winnerName == null
              ? 'Match tied'
              : 'Match tied. $winnerName won the tie-break';
        }
        final firstBat = score.battedFirstA ? a : b;
        final firstRuns = score.battedFirstA ? score.runsA : score.runsB;
        final secondRuns = score.battedFirstA ? score.runsB : score.runsA;
        final secondWickets =
            score.battedFirstA ? score.wicketsB : score.wicketsA;
        final firstWon = firstRuns > secondRuns;
        if (firstWon) {
          return '$firstBat won by ${firstRuns - secondRuns} '
              '${firstRuns - secondRuns == 1 ? 'run' : 'runs'}';
        }
        final left = maxCricketWickets - secondWickets;
        final chaser = score.battedFirstA ? b : a;
        return '$chaser won by $left ${left == 1 ? 'wicket' : 'wickets'}';

      case Sport.badminton:
        final (ga, gb) = gamesWon(score.games);
        final detail = score.games.map((g) => '${g.a}-${g.b}').join(', ');
        if (winnerName == null) return 'No result';
        final hi = ga > gb ? ga : gb;
        final lo = ga > gb ? gb : ga;
        return '$winnerName won $hi-$lo ($detail)';
    }
  }

  /// Short per-side score for list tiles: "3", "142/5", or games won.
  static String sideScore({
    required Sport sport,
    required MatchScore score,
    required bool sideA,
  }) {
    switch (sport) {
      case Sport.football:
        return '${sideA ? score.goalsA : score.goalsB}';
      case Sport.cricket:
        final runs = sideA ? score.runsA : score.runsB;
        final wickets = sideA ? score.wicketsA : score.wicketsB;
        return '$runs/$wickets';
      case Sport.badminton:
        final (a, b) = gamesWon(score.games);
        return '${sideA ? a : b}';
    }
  }
}

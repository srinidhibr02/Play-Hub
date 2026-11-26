import 'package:play_hub/logic/match_rules.dart';
import 'package:play_hub/models/team.dart';
import 'package:play_hub/models/tournament_match.dart';

/// Checks for a cricket scorecard. Pure Dart.
class Scorecard {
  const Scorecard._();

  static const int maxBatters = 15;
  static const int maxBowlers = 11;

  /// Runs not scored off the bat (wides, byes, leg byes, no-balls).
  static int extras(int teamRuns, List<BatterLine> batters) =>
      teamRuns - batters.fold<int>(0, (sum, b) => sum + b.runs);

  /// A message for the first problem, or null. Scorecards are optional, so
  /// every list may be empty and totals may be partial.
  static String? validate({
    required MatchScore score,
    required int oversPerSide,
    String nameA = 'Side A',
    String nameB = 'Side B',
  }) {
    return _validateSide(
          label: '$nameA batting',
          batters: score.battersA,
          teamRuns: score.runsA,
          teamWickets: score.wicketsA,
          teamBalls: score.ballsA,
        ) ??
        _validateSide(
          label: '$nameB batting',
          batters: score.battersB,
          teamRuns: score.runsB,
          teamWickets: score.wicketsB,
          teamBalls: score.ballsB,
        ) ??
        // Side A's bowlers bowl at side B's innings, and the other way round.
        _validateBowlers(
          label: '$nameA bowling',
          bowlers: score.bowlersA,
          againstWickets: score.wicketsB,
          againstBalls: score.ballsB,
          againstRuns: score.runsB,
          oversPerSide: oversPerSide,
        ) ??
        _validateBowlers(
          label: '$nameB bowling',
          bowlers: score.bowlersB,
          againstWickets: score.wicketsA,
          againstBalls: score.ballsA,
          againstRuns: score.runsA,
          oversPerSide: oversPerSide,
        );
  }

  static String? _validateSide({
    required String label,
    required List<BatterLine> batters,
    required int teamRuns,
    required int teamWickets,
    required int teamBalls,
  }) {
    if (batters.length > maxBatters) {
      return '$label: at most $maxBatters batters.';
    }
    final seen = <String>{};
    var out = 0;
    var balls = 0;
    for (final b in batters) {
      final name = b.name.trim();
      if (name.isEmpty) return '$label: every batter needs a name.';
      if (!seen.add(name.toLowerCase())) {
        return '$label: $name is listed twice.';
      }
      if (b.runs < 0 || b.balls < 0 || b.fours < 0 || b.sixes < 0) {
        return '$label: $name has a negative number.';
      }
      if (b.fours * 4 + b.sixes * 6 > b.runs) {
        return '$label: $name\'s fours and sixes add up to more than '
            '${b.runs} runs.';
      }
      if (b.fours + b.sixes > b.balls) {
        return '$label: $name has more boundaries than balls faced.';
      }
      if (b.out) out++;
      balls += b.balls;
    }
    final runs = batters.fold<int>(0, (sum, b) => sum + b.runs);
    if (runs > teamRuns) {
      return '$label: batters scored $runs but the team total is $teamRuns.';
    }
    if (out > teamWickets) {
      return '$label: $out batters are out but only $teamWickets '
          '${teamWickets == 1 ? 'wicket fell' : 'wickets fell'}.';
    }
    if (teamBalls > 0 && balls > teamBalls) {
      return '$label: batters faced $balls balls but the innings lasted '
          '$teamBalls.';
    }
    return null;
  }

  static String? _validateBowlers({
    required String label,
    required List<BowlerLine> bowlers,
    required int againstWickets,
    required int againstBalls,
    required int againstRuns,
    required int oversPerSide,
  }) {
    if (bowlers.length > maxBowlers) {
      return '$label: at most $maxBowlers bowlers.';
    }
    final seen = <String>{};
    var balls = 0;
    var wickets = 0;
    var runs = 0;
    for (final b in bowlers) {
      final name = b.name.trim();
      if (name.isEmpty) return '$label: every bowler needs a name.';
      if (!seen.add(name.toLowerCase())) {
        return '$label: $name is listed twice.';
      }
      if (b.balls < 0 || b.runs < 0 || b.wickets < 0 || b.maidens < 0) {
        return '$label: $name has a negative number.';
      }
      if (b.balls > oversPerSide * 6) {
        return '$label: $name bowled more than $oversPerSide overs.';
      }
      if (b.maidens > b.balls ~/ 6) {
        return '$label: $name has more maidens than complete overs.';
      }
      if (b.wickets > MatchRules.maxCricketWickets) {
        return '$label: $name cannot take more than '
            '${MatchRules.maxCricketWickets} wickets.';
      }
      balls += b.balls;
      wickets += b.wickets;
      runs += b.runs;
    }
    if (wickets > againstWickets) {
      return '$label: bowlers took $wickets wickets but the other side lost '
          '$againstWickets.';
    }
    if (againstBalls > 0 && balls > againstBalls) {
      return '$label: bowlers bowled $balls balls but the innings lasted '
          '$againstBalls.';
    }
    if (runs > againstRuns) {
      return '$label: bowlers conceded $runs but the other side scored '
          '$againstRuns.';
    }
    return null;
  }
}

/// Season numbers for one cricketer.
class CricketPlayerStat {
  CricketPlayerStat({
    required this.name,
    required this.teamId,
    required this.teamName,
  });

  final String name;
  final String teamId;
  final String teamName;

  // Batting
  int innings = 0;
  int runs = 0;
  int ballsFaced = 0;
  int fours = 0;
  int sixes = 0;
  int dismissals = 0;
  int highest = 0;
  bool highestNotOut = false;
  int fifties = 0;
  int hundreds = 0;

  // Bowling
  int bowlingInnings = 0;
  int ballsBowled = 0;
  int runsConceded = 0;
  int wickets = 0;
  int maidens = 0;
  int bestWickets = 0;
  int bestRuns = 0;

  int get notOuts => innings - dismissals;

  /// Runs per dismissal; null until the player has been out.
  double? get average => dismissals == 0 ? null : runs / dismissals;

  double? get strikeRate => ballsFaced == 0 ? null : runs * 100 / ballsFaced;

  double? get economy =>
      ballsBowled == 0 ? null : runsConceded * 6 / ballsBowled;

  String get bestFigures =>
      bowlingInnings == 0 ? '-' : '$bestWickets/$bestRuns';

  String get highestText => '$highest${highestNotOut ? '*' : ''}';
}

class CricketStats {
  const CricketStats._();

  static List<CricketPlayerStat> compute({
    required List<TournamentMatch> matches,
    required List<Team> teams,
  }) {
    final names = {for (final t in teams) t.id: t.name};
    final stats = <String, CricketPlayerStat>{};

    CricketPlayerStat of(String teamId, String name) {
      final clean = name.trim();
      return stats.putIfAbsent(
        '$teamId|${clean.toLowerCase()}',
        () => CricketPlayerStat(
          name: clean,
          teamId: teamId,
          teamName: names[teamId] ?? '',
        ),
      );
    }

    void bat(String? teamId, List<BatterLine> lines) {
      if (teamId == null) return;
      for (final l in lines) {
        if (l.name.trim().isEmpty) continue;
        final p = of(teamId, l.name);
        p.innings++;
        p.runs += l.runs;
        p.ballsFaced += l.balls;
        p.fours += l.fours;
        p.sixes += l.sixes;
        if (l.out) p.dismissals++;
        // Highest score: a not-out score beats an equal out score.
        if (p.innings == 1 ||
            l.runs > p.highest ||
            (l.runs == p.highest && !l.out && !p.highestNotOut)) {
          p.highest = l.runs;
          p.highestNotOut = !l.out;
        }
        if (l.runs >= 100) {
          p.hundreds++;
        } else if (l.runs >= 50) {
          p.fifties++;
        }
      }
    }

    void bowl(String? teamId, List<BowlerLine> lines) {
      if (teamId == null) return;
      for (final l in lines) {
        if (l.name.trim().isEmpty || l.balls == 0 && l.wickets == 0) continue;
        final p = of(teamId, l.name);
        p.bowlingInnings++;
        p.ballsBowled += l.balls;
        p.runsConceded += l.runs;
        p.wickets += l.wickets;
        p.maidens += l.maidens;
        // Best figures: most wickets, then fewest runs.
        if (p.bowlingInnings == 1 ||
            l.wickets > p.bestWickets ||
            (l.wickets == p.bestWickets && l.runs < p.bestRuns)) {
          p.bestWickets = l.wickets;
          p.bestRuns = l.runs;
        }
      }
    }

    for (final m in matches) {
      final s = m.score;
      if (!m.isCompleted || s == null) continue;
      bat(m.teamAId, s.battersA);
      bat(m.teamBId, s.battersB);
      bowl(m.teamAId, s.bowlersA);
      bowl(m.teamBId, s.bowlersB);
    }
    return stats.values.toList();
  }

  static String _key(CricketPlayerStat p) => p.name.toLowerCase();

  /// Most runs; ties go to the higher strike rate.
  static List<CricketPlayerStat> topBatters(
    List<CricketPlayerStat> all, {
    int limit = 5,
  }) {
    final list = all.where((p) => p.runs > 0).toList()
      ..sort((x, y) {
        var c = y.runs.compareTo(x.runs);
        if (c != 0) return c;
        c = (y.strikeRate ?? 0).compareTo(x.strikeRate ?? 0);
        if (c != 0) return c;
        return _key(x).compareTo(_key(y));
      });
    return list.take(limit).toList();
  }

  /// Most wickets; ties go to the better economy.
  static List<CricketPlayerStat> topBowlers(
    List<CricketPlayerStat> all, {
    int limit = 5,
  }) {
    final list = all.where((p) => p.wickets > 0).toList()
      ..sort((x, y) {
        var c = y.wickets.compareTo(x.wickets);
        if (c != 0) return c;
        c = (x.economy ?? 99).compareTo(y.economy ?? 99);
        if (c != 0) return c;
        return _key(x).compareTo(_key(y));
      });
    return list.take(limit).toList();
  }

  static List<CricketPlayerStat> mostSixes(
    List<CricketPlayerStat> all, {
    int limit = 5,
  }) {
    final list = all.where((p) => p.sixes > 0).toList()
      ..sort((x, y) {
        final c = y.sixes.compareTo(x.sixes);
        if (c != 0) return c;
        return _key(x).compareTo(_key(y));
      });
    return list.take(limit).toList();
  }
}

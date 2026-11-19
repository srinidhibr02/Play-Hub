import 'package:play_hub/logic/match_rules.dart';
import 'package:play_hub/models/sport.dart';
import 'package:play_hub/models/team.dart';
import 'package:play_hub/models/tournament.dart';
import 'package:play_hub/models/tournament_match.dart';

/// One row of a league table. Fields for the other sports stay at zero.
class Standing {
  Standing({required this.team});

  final Team team;

  int played = 0;
  int won = 0;
  int drawn = 0;
  int lost = 0;
  int points = 0;

  // Football
  int goalsFor = 0;
  int goalsAgainst = 0;

  // Cricket (balls rather than overs, so the maths stays exact)
  int runsFor = 0;
  int ballsFaced = 0;
  int runsAgainst = 0;
  int ballsBowled = 0;

  // Badminton
  int gamesFor = 0;
  int gamesAgainst = 0;
  int pointsFor = 0;
  int pointsAgainst = 0;

  int get goalDifference => goalsFor - goalsAgainst;
  int get gameDifference => gamesFor - gamesAgainst;
  int get pointDifference => pointsFor - pointsAgainst;

  /// Net run rate: runs per over scored minus runs per over conceded.
  double get netRunRate {
    if (ballsFaced == 0 || ballsBowled == 0) return 0;
    return runsFor * 6 / ballsFaced - runsAgainst * 6 / ballsBowled;
  }
}

/// Builds a league table from completed matches. Pure Dart.
class Standings {
  const Standings._();

  /// Table ordered best first. Every team appears, even before any match.
  /// Only completed matches with both sides and a score count; live matches
  /// are left out until they are final.
  static List<Standing> compute({
    required Sport sport,
    required TournamentSettings settings,
    required List<Team> teams,
    required List<TournamentMatch> matches,
  }) {
    final rows = {for (final t in teams) t.id: Standing(team: t)};

    for (final m in matches) {
      if (!m.isCompleted || m.isBye || m.score == null) continue;
      final a = rows[m.teamAId];
      final b = rows[m.teamBId];
      if (a == null || b == null) continue;
      final s = m.score!;

      // Who won, read from the score itself (0 = draw/tie).
      int result;
      switch (sport) {
        case Sport.football:
          a.goalsFor += s.goalsA;
          a.goalsAgainst += s.goalsB;
          b.goalsFor += s.goalsB;
          b.goalsAgainst += s.goalsA;
          result = s.goalsA.compareTo(s.goalsB);
        case Sport.cricket:
          // A side bowled out is charged the full quota of overs.
          final quota = settings.overs * 6;
          final facedA = s.wicketsA >= MatchRules.maxCricketWickets
              ? quota
              : s.ballsA;
          final facedB = s.wicketsB >= MatchRules.maxCricketWickets
              ? quota
              : s.ballsB;
          a.runsFor += s.runsA;
          a.ballsFaced += facedA;
          a.runsAgainst += s.runsB;
          a.ballsBowled += facedB;
          b.runsFor += s.runsB;
          b.ballsFaced += facedB;
          b.runsAgainst += s.runsA;
          b.ballsBowled += facedA;
          result = s.runsA.compareTo(s.runsB);
        case Sport.badminton:
          final (ga, gb) = MatchRules.gamesWon(s.games);
          a.gamesFor += ga;
          a.gamesAgainst += gb;
          b.gamesFor += gb;
          b.gamesAgainst += ga;
          for (final g in s.games) {
            a.pointsFor += g.a;
            a.pointsAgainst += g.b;
            b.pointsFor += g.b;
            b.pointsAgainst += g.a;
          }
          result = ga.compareTo(gb);
      }

      a.played++;
      b.played++;
      if (result > 0) {
        a.won++;
        b.lost++;
        a.points += settings.winPoints;
        b.points += settings.lossPoints;
      } else if (result < 0) {
        b.won++;
        a.lost++;
        b.points += settings.winPoints;
        a.points += settings.lossPoints;
      } else {
        a.drawn++;
        b.drawn++;
        a.points += settings.drawPoints;
        b.points += settings.drawPoints;
      }
    }

    final table = rows.values.toList();
    table.sort((x, y) => _compare(sport, x, y));
    return table;
  }

  static int _compare(Sport sport, Standing x, Standing y) {
    var c = y.points.compareTo(x.points);
    if (c != 0) return c;

    switch (sport) {
      case Sport.football:
        c = y.goalDifference.compareTo(x.goalDifference);
        if (c != 0) return c;
        c = y.goalsFor.compareTo(x.goalsFor);
      case Sport.cricket:
        c = y.netRunRate.compareTo(x.netRunRate);
      case Sport.badminton:
        c = y.gameDifference.compareTo(x.gameDifference);
        if (c != 0) return c;
        c = y.pointDifference.compareTo(x.pointDifference);
    }
    if (c != 0) return c;

    c = y.won.compareTo(x.won);
    if (c != 0) return c;
    // Stable and predictable when everything is level: original entry order.
    return x.team.seed.compareTo(y.team.seed);
  }
}

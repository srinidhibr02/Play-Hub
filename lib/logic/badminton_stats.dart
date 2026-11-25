import 'package:play_hub/logic/match_rules.dart';
import 'package:play_hub/models/team.dart';
import 'package:play_hub/models/tournament_match.dart';

/// One badminton player's record across the tournament.
class PlayerRecord {
  PlayerRecord({required this.name, required this.teamName});

  final String name;
  final String teamName;

  int played = 0;
  int won = 0;
  int lost = 0;
  int gamesFor = 0;
  int gamesAgainst = 0;
  int pointsFor = 0;
  int pointsAgainst = 0;

  int get pointDifference => pointsFor - pointsAgainst;

  /// Share of matches won, 0 to 1. Zero before any match.
  double get winRate => played == 0 ? 0 : won / played;
}

/// Per-player records for badminton. Pure Dart.
///
/// An entry is a player (singles) or a pair (doubles). A team that lists one
/// or two players credits each of them; a team with no players listed, or a
/// longer list, is treated as a single competitor named after the team.
class BadmintonStats {
  const BadmintonStats._();

  static List<String> competitors(Team team) {
    final names = team.players
        .map((n) => n.trim())
        .where((n) => n.isNotEmpty)
        .toList();
    return (names.isEmpty || names.length > 2) ? [team.name] : names;
  }

  static List<PlayerRecord> compute({
    required List<TournamentMatch> matches,
    required List<Team> teams,
  }) {
    final byTeam = {for (final t in teams) t.id: t};
    final records = <String, PlayerRecord>{};

    List<PlayerRecord> recordsFor(Team team) {
      return [
        for (final name in competitors(team))
          records.putIfAbsent(
            '${team.id}|${name.toLowerCase()}',
            () => PlayerRecord(name: name, teamName: team.name),
          ),
      ];
    }

    for (final m in matches) {
      if (!m.isCompleted || m.isBye || m.score == null) continue;
      final teamA = byTeam[m.teamAId];
      final teamB = byTeam[m.teamBId];
      if (teamA == null || teamB == null) continue;

      final games = m.score!.games;
      final (ga, gb) = MatchRules.gamesWon(games);
      if (ga == gb) continue; // no result to credit
      var pa = 0;
      var pb = 0;
      for (final g in games) {
        pa += g.a;
        pb += g.b;
      }

      void credit(List<PlayerRecord> side, bool won, int gf, int gAg, int pf, int pAg) {
        for (final r in side) {
          r.played++;
          if (won) {
            r.won++;
          } else {
            r.lost++;
          }
          r.gamesFor += gf;
          r.gamesAgainst += gAg;
          r.pointsFor += pf;
          r.pointsAgainst += pAg;
        }
      }

      credit(recordsFor(teamA), ga > gb, ga, gb, pa, pb);
      credit(recordsFor(teamB), gb > ga, gb, ga, pb, pa);
    }
    return records.values.toList();
  }

  /// Most wins; then best win rate, then point difference.
  static List<PlayerRecord> mostWins(List<PlayerRecord> all, {int limit = 5}) {
    final list = all.where((p) => p.won > 0).toList()
      ..sort((x, y) {
        var c = y.won.compareTo(x.won);
        if (c != 0) return c;
        c = y.winRate.compareTo(x.winRate);
        if (c != 0) return c;
        c = y.pointDifference.compareTo(x.pointDifference);
        if (c != 0) return c;
        return x.name.toLowerCase().compareTo(y.name.toLowerCase());
      });
    return list.take(limit).toList();
  }

  /// Best point difference among players who have played.
  static List<PlayerRecord> bestPointDifference(
    List<PlayerRecord> all, {
    int limit = 5,
  }) {
    final list = all.where((p) => p.played > 0 && p.pointDifference > 0).toList()
      ..sort((x, y) {
        var c = y.pointDifference.compareTo(x.pointDifference);
        if (c != 0) return c;
        c = y.won.compareTo(x.won);
        if (c != 0) return c;
        return x.name.toLowerCase().compareTo(y.name.toLowerCase());
      });
    return list.take(limit).toList();
  }
}

import 'package:play_hub/models/team.dart';
import 'package:play_hub/models/tournament_match.dart';

/// Season numbers for one player. Football only for now.
class PlayerStat {
  PlayerStat({required this.name, required this.teamId, required this.teamName});

  final String name;
  final String teamId;
  final String teamName;

  int goals = 0;
  int penaltyGoals = 0; // included in [goals]
  int assists = 0;
  int ownGoals = 0;
  int yellowCards = 0;
  int redCards = 0;
  int starts = 0;
  int appearances = 0; // starts plus coming on as a substitute

  int get goalContributions => goals + assists;
  int get cardPoints => yellowCards + redCards * 3;
}

/// Adds up match events into per-player numbers. Pure Dart.
class PlayerStats {
  const PlayerStats._();

  /// Every player who appears in at least one event. Names are matched
  /// ignoring case and surrounding spaces, within a team.
  static List<PlayerStat> compute({
    required List<TournamentMatch> matches,
    required List<Team> teams,
  }) {
    final teamNames = {for (final t in teams) t.id: t.name};
    final stats = <String, PlayerStat>{};

    PlayerStat of(String teamId, String name) {
      final clean = name.trim();
      final key = '$teamId|${clean.toLowerCase()}';
      return stats.putIfAbsent(
        key,
        () => PlayerStat(
          name: clean,
          teamId: teamId,
          teamName: teamNames[teamId] ?? '',
        ),
      );
    }

    for (final m in matches) {
      if (!m.isCompleted || m.score == null) continue;

      // Appearances: starters, plus anyone who came on.
      final played = <String>{};
      void appear(String? teamId, String name, {required bool start}) {
        if (teamId == null || name.trim().isEmpty) return;
        final key = '$teamId|${name.trim().toLowerCase()}';
        if (!played.add(key)) return;
        final p = of(teamId, name);
        p.appearances++;
        if (start) p.starts++;
      }

      for (final n in m.score!.lineupA) {
        appear(m.teamAId, n, start: true);
      }
      for (final n in m.score!.lineupB) {
        appear(m.teamBId, n, start: true);
      }
      for (final e in m.score!.events) {
        if (e.type.isSubstitution) appear(e.teamId, e.player, start: false);
      }

      for (final e in m.score!.events) {
        if (e.player.trim().isEmpty) continue;
        final p = of(e.teamId, e.player);
        switch (e.type) {
          case MatchEventType.goal:
            p.goals++;
            if (e.assist.trim().isNotEmpty) of(e.teamId, e.assist).assists++;
          case MatchEventType.penaltyGoal:
            p.goals++;
            p.penaltyGoals++;
          case MatchEventType.ownGoal:
            p.ownGoals++;
          case MatchEventType.yellowCard:
            p.yellowCards++;
          case MatchEventType.redCard:
            p.redCards++;
          case MatchEventType.substitution:
            break;
        }
      }
    }
    return stats.values.toList();
  }

  static List<PlayerStat> topScorers(List<PlayerStat> all, {int limit = 5}) {
    final list = all.where((p) => p.goals > 0).toList()
      ..sort((x, y) {
        var c = y.goals.compareTo(x.goals);
        if (c != 0) return c;
        // Fewer penalties means more goals from open play.
        c = x.penaltyGoals.compareTo(y.penaltyGoals);
        if (c != 0) return c;
        c = y.assists.compareTo(x.assists);
        if (c != 0) return c;
        return x.name.toLowerCase().compareTo(y.name.toLowerCase());
      });
    return list.take(limit).toList();
  }

  static List<PlayerStat> topAssists(List<PlayerStat> all, {int limit = 5}) {
    final list = all.where((p) => p.assists > 0).toList()
      ..sort((x, y) {
        var c = y.assists.compareTo(x.assists);
        if (c != 0) return c;
        c = y.goals.compareTo(x.goals);
        if (c != 0) return c;
        return x.name.toLowerCase().compareTo(y.name.toLowerCase());
      });
    return list.take(limit).toList();
  }

  /// Most booked first (a red counts as three yellows).
  static List<PlayerStat> discipline(List<PlayerStat> all, {int limit = 5}) {
    final list = all.where((p) => p.cardPoints > 0).toList()
      ..sort((x, y) {
        final c = y.cardPoints.compareTo(x.cardPoints);
        if (c != 0) return c;
        return x.name.toLowerCase().compareTo(y.name.toLowerCase());
      });
    return list.take(limit).toList();
  }
}

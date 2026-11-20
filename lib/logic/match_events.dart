import 'package:play_hub/models/tournament_match.dart';

/// Rules for football match events (goals and cards). Pure Dart.
class MatchEvents {
  const MatchEvents._();

  /// Goals each side is credited with by the events: their own goals and
  /// penalties, plus own goals scored by the other side's players.
  static (int, int) credited(
    List<MatchEvent> events,
    String teamAId,
    String teamBId,
  ) {
    var a = 0;
    var b = 0;
    for (final e in events) {
      if (!e.type.isGoal) continue;
      final forA = e.type == MatchEventType.ownGoal
          ? e.teamId == teamBId
          : e.teamId == teamAId;
      final forB = e.type == MatchEventType.ownGoal
          ? e.teamId == teamAId
          : e.teamId == teamBId;
      if (forA) a++;
      if (forB) b++;
    }
    return (a, b);
  }

  /// A message for the first problem, or null.
  ///
  /// Recording scorers is optional, so fewer goal events than goals is fine;
  /// more is not. Cards are limited to what can happen in a real match.
  static String? validate({
    required List<MatchEvent> events,
    required int goalsA,
    required int goalsB,
    required String teamAId,
    required String teamBId,
  }) {
    for (final e in events) {
      if (e.teamId != teamAId && e.teamId != teamBId) {
        return 'An event belongs to a team that is not in this match.';
      }
      if (e.player.trim().isEmpty) {
        return 'Every event needs a player name.';
      }
      if (e.type.isSubstitution) {
        final off = e.playerOff.trim();
        if (off.isEmpty) return 'A substitution needs the player going off.';
        if (off.toLowerCase() == e.player.trim().toLowerCase()) {
          return 'A player cannot replace themselves.';
        }
      }
      final m = e.minute;
      if (m != null && (m < 1 || m > 150)) {
        return 'Minutes should be between 1 and 150.';
      }
    }

    final (a, b) = credited(events, teamAId, teamBId);
    if (a > goalsA || b > goalsB) {
      return 'More goals are recorded for a team than its score. Raise the '
          'score or remove a goal.';
    }

    // At most two yellows and one red-ending per player: a second yellow
    // is allowed (it leads to a red), a third is not.
    final yellows = <String, int>{};
    final reds = <String, int>{};
    for (final e in events) {
      final key = '${e.teamId}|${e.player.trim().toLowerCase()}';
      if (e.type == MatchEventType.yellowCard) {
        yellows[key] = (yellows[key] ?? 0) + 1;
        if (yellows[key]! > 2) {
          return '${e.player.trim()} cannot have more than two yellow cards.';
        }
      }
      if (e.type == MatchEventType.redCard) {
        reds[key] = (reds[key] ?? 0) + 1;
        if (reds[key]! > 1) {
          return '${e.player.trim()} cannot be sent off twice.';
        }
      }
    }
    return null;
  }

  /// Checks lineups and substitutions against each other.
  ///
  /// Lineups are optional: with none recorded for a side, its substitutions
  /// are not checked against who is on the pitch. With a lineup, the player
  /// going off must be on the pitch, the player coming on must not be, and a
  /// player who has gone off cannot return.
  static String? validateLineups({
    required List<String> lineupA,
    required List<String> lineupB,
    required List<MatchEvent> events,
    required String teamAId,
    required String teamBId,
    int maxPlayers = 11,
  }) {
    String key(String n) => n.trim().toLowerCase();

    String? side(String label, List<String> lineup, String teamId) {
      if (lineup.length > maxPlayers) {
        return '$label: a lineup has at most $maxPlayers players.';
      }
      final onPitch = <String>{};
      for (final n in lineup) {
        if (!onPitch.add(key(n))) return '$label: ${n.trim()} is listed twice.';
      }
      if (lineup.isEmpty) return null;

      final wentOff = <String>{};
      final subs = sorted(events)
          .where((e) => e.type.isSubstitution && e.teamId == teamId);
      for (final e in subs) {
        final on = key(e.player);
        final off = key(e.playerOff);
        if (!onPitch.contains(off)) {
          return '$label: ${e.playerOff.trim()} is not on the pitch to be '
              'substituted.';
        }
        if (onPitch.contains(on)) {
          return '$label: ${e.player.trim()} is already on the pitch.';
        }
        if (wentOff.contains(on)) {
          return '$label: ${e.player.trim()} was substituted off and cannot '
              'return.';
        }
        onPitch.remove(off);
        wentOff.add(off);
        onPitch.add(on);
      }
      return null;
    }

    return side('Lineup A', lineupA, teamAId) ??
        side('Lineup B', lineupB, teamBId);
  }

  /// Events in match order: by minute, unknown minutes last.
  static List<MatchEvent> sorted(List<MatchEvent> events) {
    final list = [...events];
    list.sort((x, y) => (x.minute ?? 999).compareTo(y.minute ?? 999));
    return list;
  }
}

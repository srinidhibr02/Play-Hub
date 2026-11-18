import 'dart:math';

import 'package:play_hub/models/team.dart';
import 'package:play_hub/models/tournament.dart';
import 'package:play_hub/models/tournament_match.dart';

/// Builds fixture lists. Pure Dart: no Firebase, so it is easy to unit test.
class FixtureGenerator {
  const FixtureGenerator._();

  /// Generates fixtures for [format].
  ///
  /// [teams] must be in seed order. Pass [random] to shuffle the draw first;
  /// leave it null to keep the given order (seeded).
  static List<TournamentMatch> generate({
    required TournamentFormat format,
    required List<Team> teams,
    required String Function() newId,
    int legs = 1,
    Random? random,
  }) {
    if (teams.length < 2) {
      throw ArgumentError('At least 2 teams are needed to create fixtures.');
    }
    final entries = List<Team>.of(teams);
    if (random != null) entries.shuffle(random);

    switch (format) {
      case TournamentFormat.roundRobin:
        return roundRobin(teams: entries, newId: newId, legs: legs);
      case TournamentFormat.knockout:
        return knockout(teams: entries, newId: newId);
    }
  }

  /// Single or double round robin using the circle method.
  ///
  /// With an odd number of teams one team rests each round (a "bye"); no match
  /// is created for it.
  static List<TournamentMatch> roundRobin({
    required List<Team> teams,
    required String Function() newId,
    int legs = 1,
  }) {
    final slots = <Team?>[...teams];
    if (slots.length.isOdd) slots.add(null);

    final n = slots.length;
    final roundsPerLeg = n - 1;
    final matches = <TournamentMatch>[];
    var order = 0;

    for (var leg = 0; leg < legs; leg++) {
      final rotation = List<Team?>.of(slots);
      for (var r = 0; r < roundsPerLeg; r++) {
        final roundNo = leg * roundsPerLeg + r + 1;
        for (var i = 0; i < n ~/ 2; i++) {
          var a = rotation[i];
          var b = rotation[n - 1 - i];
          if (a == null || b == null) continue; // bye

          // Alternate sides so nobody is always "Team A".
          final swap = (leg.isOdd) != (i == 0 && r.isOdd);
          if (swap) {
            final tmp = a;
            a = b;
            b = tmp;
          }

          matches.add(
            TournamentMatch(
              id: newId(),
              round: roundNo,
              roundLabel: 'Round $roundNo',
              order: order++,
              teamAId: a.id,
              teamBId: b.id,
              teamAName: a.name,
              teamBName: b.name,
            ),
          );
        }
        // Keep the first slot fixed, rotate the rest.
        final last = rotation.removeLast();
        rotation.insert(1, last);
      }
    }
    return matches;
  }

  /// Single elimination bracket.
  ///
  /// The bracket is padded to the next power of two. Top seeds receive
  /// first-round byes and are moved into round two automatically. Every match
  /// knows where its winner goes via `nextMatchId` and `nextSlot`.
  static List<TournamentMatch> knockout({
    required List<Team> teams,
    required String Function() newId,
  }) {
    final n = teams.length;
    var size = 2;
    while (size < n) {
      size *= 2;
    }
    var totalRounds = 0;
    for (var s = size; s > 1; s ~/= 2) {
      totalRounds++;
    }

    // Pre-assign ids so matches can point at the one their winner feeds.
    final ids = <List<String>>[
      for (var r = 1; r <= totalRounds; r++)
        [for (var i = 0; i < size ~/ (1 << r); i++) newId()],
    ];

    final nodes = <List<_Node>>[
      for (var r = 0; r < totalRounds; r++)
        [for (var i = 0; i < ids[r].length; i++) _Node()],
    ];

    // Round 1 from seeded positions.
    final positions = seedPositions(size);
    for (var i = 0; i < nodes[0].length; i++) {
      final seedA = positions[2 * i];
      final seedB = positions[2 * i + 1];
      nodes[0][i]
        ..a = seedA <= n ? teams[seedA - 1] : null
        ..b = seedB <= n ? teams[seedB - 1] : null;
    }

    // Resolve byes and push those winners into round 2.
    for (var i = 0; i < nodes[0].length; i++) {
      final node = nodes[0][i];
      final hasA = node.a != null;
      final hasB = node.b != null;
      if (hasA != hasB) {
        node
          ..isBye = true
          ..winner = node.a ?? node.b;
        if (totalRounds > 1) {
          final parent = nodes[1][i ~/ 2];
          if (i.isEven) {
            parent.a = node.winner;
          } else {
            parent.b = node.winner;
          }
        }
      }
    }

    final matches = <TournamentMatch>[];
    var order = 0;
    for (var r = 0; r < totalRounds; r++) {
      final label = _roundLabel(r + 1, totalRounds);
      for (var i = 0; i < nodes[r].length; i++) {
        final node = nodes[r][i];
        final hasNext = r + 1 < totalRounds;
        matches.add(
          TournamentMatch(
            id: ids[r][i],
            round: r + 1,
            roundLabel: label,
            order: order++,
            teamAId: node.a?.id,
            teamBId: node.b?.id,
            teamAName: node.a?.name,
            teamBName: node.b?.name,
            status: node.isBye ? MatchStatus.completed : MatchStatus.scheduled,
            winnerId: node.winner?.id,
            nextMatchId: hasNext ? ids[r + 1][i ~/ 2] : null,
            nextSlot: hasNext ? (i.isEven ? 'A' : 'B') : null,
            isBye: node.isBye,
          ),
        );
      }
    }
    return matches;
  }

  /// Standard bracket seeding order for a power-of-two [size].
  ///
  /// For 8 this gives `[1, 8, 4, 5, 2, 7, 3, 6]`, so adjacent pairs are the
  /// first-round matches and seeds 1 and 2 can only meet in the final.
  static List<int> seedPositions(int size) {
    var order = <int>[1];
    while (order.length < size) {
      final next = order.length * 2;
      order = [
        for (final s in order) ...[s, next + 1 - s],
      ];
    }
    return order;
  }

  static String _roundLabel(int round, int totalRounds) {
    final fromEnd = totalRounds - round;
    switch (fromEnd) {
      case 0:
        return 'Final';
      case 1:
        return 'Semi-final';
      case 2:
        return 'Quarter-final';
      default:
        return 'Round $round';
    }
  }
}

class _Node {
  Team? a;
  Team? b;
  Team? winner;
  bool isBye = false;
}

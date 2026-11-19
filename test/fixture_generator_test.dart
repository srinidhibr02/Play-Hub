import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:play_hub/logic/fixture_generator.dart';
import 'package:play_hub/models/team.dart';
import 'package:play_hub/models/tournament.dart';
import 'package:play_hub/models/tournament_match.dart';

List<Team> makeTeams(int n) => [
      for (var i = 1; i <= n; i++)
        Team(
          id: 't$i',
          name: 'Team $i',
          shortName: 'T$i',
          colorValue: 0xFF000000,
          seed: i - 1,
        ),
    ];

String Function() idCounter() {
  var c = 0;
  return () => 'm${c++}';
}

String pairKey(TournamentMatch m) {
  final ids = [m.teamAId!, m.teamBId!]..sort();
  return ids.join('-');
}

void main() {
  group('round robin', () {
    test('even team count: every pair meets exactly once', () {
      final matches = FixtureGenerator.roundRobin(
        teams: makeTeams(6),
        newId: idCounter(),
      );

      expect(matches.length, 15);
      expect(matches.map((m) => m.round).toSet().length, 5);

      final pairs = matches.map(pairKey).toList();
      expect(pairs.toSet().length, 15);
    });

    test('no team plays twice in the same round', () {
      for (final n in [4, 5, 6, 7, 8]) {
        final matches = FixtureGenerator.roundRobin(
          teams: makeTeams(n),
          newId: idCounter(),
        );
        final byRound = <int, List<TournamentMatch>>{};
        for (final m in matches) {
          byRound.putIfAbsent(m.round, () => []).add(m);
        }
        for (final roundMatches in byRound.values) {
          final ids = roundMatches
              .expand((m) => [m.teamAId!, m.teamBId!])
              .toList();
          expect(ids.toSet().length, ids.length, reason: 'n=$n');
        }
      }
    });

    test('odd team count: bye rounds produce no match', () {
      final matches = FixtureGenerator.roundRobin(
        teams: makeTeams(5),
        newId: idCounter(),
      );

      expect(matches.length, 10);
      expect(matches.map(pairKey).toSet().length, 10);

      // Each team plays 4 matches in a 5 team league.
      final played = <String, int>{};
      for (final m in matches) {
        played[m.teamAId!] = (played[m.teamAId!] ?? 0) + 1;
        played[m.teamBId!] = (played[m.teamBId!] ?? 0) + 1;
      }
      expect(played.values.every((c) => c == 4), isTrue);
    });

    test('double round robin: every pair meets twice', () {
      final matches = FixtureGenerator.roundRobin(
        teams: makeTeams(4),
        newId: idCounter(),
        legs: 2,
      );

      expect(matches.length, 12);
      expect(matches.map((m) => m.round).toSet().length, 6);

      final counts = <String, int>{};
      for (final m in matches) {
        counts[pairKey(m)] = (counts[pairKey(m)] ?? 0) + 1;
      }
      expect(counts.length, 6);
      expect(counts.values.every((c) => c == 2), isTrue);
    });

    test('order is sequential and ids are unique', () {
      final matches = FixtureGenerator.roundRobin(
        teams: makeTeams(6),
        newId: idCounter(),
      );
      expect(matches.map((m) => m.order).toList(),
          List.generate(matches.length, (i) => i));
      expect(matches.map((m) => m.id).toSet().length, matches.length);
    });
  });

  group('seed positions', () {
    test('standard bracket order', () {
      expect(FixtureGenerator.seedPositions(2), [1, 2]);
      expect(FixtureGenerator.seedPositions(4), [1, 4, 2, 3]);
      expect(FixtureGenerator.seedPositions(8), [1, 8, 4, 5, 2, 7, 3, 6]);
    });
  });

  group('knockout', () {
    test('8 teams: 4 + 2 + 1 matches with correct labels', () {
      final matches = FixtureGenerator.knockout(
        teams: makeTeams(8),
        newId: idCounter(),
      );

      expect(matches.length, 7);
      expect(matches.where((m) => m.round == 1).length, 4);
      expect(matches.where((m) => m.round == 2).length, 2);
      expect(matches.where((m) => m.round == 3).length, 1);
      expect(matches.any((m) => m.isBye), isFalse);

      expect(matches.where((m) => m.round == 1).first.roundLabel,
          'Quarter-final');
      expect(matches.where((m) => m.round == 2).first.roundLabel, 'Semi-final');
      expect(matches.last.roundLabel, 'Final');
    });

    test('winners are wired to the next round', () {
      final matches = FixtureGenerator.knockout(
        teams: makeTeams(8),
        newId: idCounter(),
      );
      final byId = {for (final m in matches) m.id: m};

      final round1 = matches.where((m) => m.round == 1).toList();
      for (var i = 0; i < round1.length; i++) {
        final next = byId[round1[i].nextMatchId]!;
        expect(next.round, 2);
        expect(round1[i].nextSlot, i.isEven ? 'A' : 'B');
      }
      expect(matches.last.nextMatchId, isNull);
      expect(matches.last.nextSlot, isNull);

      // Both feeders of a match point at it.
      final feeders = <String, int>{};
      for (final m in matches) {
        if (m.nextMatchId != null) {
          feeders[m.nextMatchId!] = (feeders[m.nextMatchId!] ?? 0) + 1;
        }
      }
      expect(feeders.values.every((c) => c == 2), isTrue);
    });

    test('top seeds meet last: seeds 1 and 2 are on opposite halves', () {
      final matches = FixtureGenerator.knockout(
        teams: makeTeams(8),
        newId: idCounter(),
      );
      final round1 = matches.where((m) => m.round == 1).toList();

      // Match 0 holds seed 1, match 2 holds seed 2.
      expect(round1[0].teamAId, 't1');
      expect(round1[2].teamAId, 't2');
      // The first round matches feeding different semi-finals.
      expect(round1[0].nextMatchId, isNot(round1[2].nextMatchId));
    });

    test('5 teams: top 3 seeds get byes and advance automatically', () {
      final matches = FixtureGenerator.knockout(
        teams: makeTeams(5),
        newId: idCounter(),
      );

      expect(matches.length, 7); // bracket of 8
      final byes = matches.where((m) => m.isBye).toList();
      expect(byes.length, 3);
      expect(byes.every((m) => m.status == MatchStatus.completed), isTrue);
      expect(byes.every((m) => m.winnerId != null), isTrue);
      expect(byes.map((m) => m.winnerId).toSet(), {'t1', 't2', 't3'});

      // Round 2: first semi has seed 1 waiting for the 4 v 5 winner; second
      // semi is already seed 2 v seed 3.
      final semis = matches.where((m) => m.round == 2).toList();
      expect(semis[0].teamAId, 't1');
      expect(semis[0].teamBId, isNull);
      expect(semis[1].teamAId, 't2');
      expect(semis[1].teamBId, 't3');

      // Only one real first-round match remains: seed 4 v seed 5.
      final playable = matches.where((m) => m.round == 1 && !m.isBye).toList();
      expect(playable.length, 1);
      expect({playable.first.teamAId, playable.first.teamBId}, {'t4', 't5'});
    });

    test('3 teams: bracket of 4 with one bye', () {
      final matches = FixtureGenerator.knockout(
        teams: makeTeams(3),
        newId: idCounter(),
      );
      expect(matches.length, 3);
      expect(matches.where((m) => m.isBye).length, 1);
      expect(matches.where((m) => m.isBye).first.winnerId, 't1');
      expect(matches.last.roundLabel, 'Final');
    });

    test('2 teams: a single final', () {
      final matches = FixtureGenerator.knockout(
        teams: makeTeams(2),
        newId: idCounter(),
      );
      expect(matches.length, 1);
      expect(matches.single.roundLabel, 'Final');
      expect(matches.single.nextMatchId, isNull);
      expect(matches.single.hasBothTeams, isTrue);
    });
  });

  group('generate', () {
    test('rejects fewer than two teams', () {
      expect(
        () => FixtureGenerator.generate(
          format: TournamentFormat.knockout,
          teams: makeTeams(1),
          newId: idCounter(),
        ),
        throwsArgumentError,
      );
    });

    test('shuffling keeps every team in the draw', () {
      final matches = FixtureGenerator.generate(
        format: TournamentFormat.knockout,
        teams: makeTeams(8),
        newId: idCounter(),
        random: Random(42),
      );
      final ids = matches
          .where((m) => m.round == 1)
          .expand((m) => [m.teamAId, m.teamBId])
          .toSet();
      expect(ids.length, 8);
    });
  });

  group('Team.autoShortName', () {
    test('uses initials for multi-word names', () {
      expect(Team.autoShortName('Royal Strikers'), 'RS');
      expect(Team.autoShortName('Royal Strikers United'), 'RSU');
    });

    test('uses first letters for single-word names', () {
      expect(Team.autoShortName('Falcons'), 'FAL');
      expect(Team.autoShortName('FC'), 'FC');
    });

    test('handles empty input', () {
      expect(Team.autoShortName('   '), '?');
    });
  });
}

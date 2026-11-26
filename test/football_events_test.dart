import 'package:flutter_test/flutter_test.dart';
import 'package:play_hub/logic/match_events.dart';
import 'package:play_hub/logic/player_stats.dart';
import 'package:play_hub/models/team.dart';
import 'package:play_hub/models/tournament_match.dart';

const a = 'A';
const b = 'B';

MatchEvent ev(
  MatchEventType type,
  String team,
  String player, {
  String assist = '',
  int? minute,
}) =>
    MatchEvent(
      type: type,
      teamId: team,
      player: player,
      assist: assist,
      minute: minute,
    );

String? check(List<MatchEvent> events, {int ga = 5, int gb = 5}) =>
    MatchEvents.validate(
      events: events,
      goalsA: ga,
      goalsB: gb,
      teamAId: a,
      teamBId: b,
    );

TournamentMatch match(List<MatchEvent> events, {bool done = true}) =>
    TournamentMatch(
      id: 'm',
      round: 1,
      roundLabel: 'Round 1',
      order: 1,
      teamAId: a,
      teamBId: b,
      status: done ? MatchStatus.completed : MatchStatus.live,
      score: MatchScore(events: events),
    );

final teams = [
  const Team(id: a, name: 'Reds', shortName: 'RED', colorValue: 0),
  const Team(id: b, name: 'Blues', shortName: 'BLU', colorValue: 0),
];

void main() {
  group('credited goals', () {
    test('goals and penalties count for the scorer team', () {
      final (x, y) = MatchEvents.credited([
        ev(MatchEventType.goal, a, 'Ravi'),
        ev(MatchEventType.penaltyGoal, a, 'Ravi'),
        ev(MatchEventType.goal, b, 'Sam'),
      ], a, b);
      expect((x, y), (2, 1));
    });

    test('an own goal counts for the other team', () {
      final (x, y) = MatchEvents.credited([
        ev(MatchEventType.ownGoal, a, 'Ravi'),
      ], a, b);
      expect((x, y), (0, 1));
    });

    test('cards are not goals', () {
      final (x, y) = MatchEvents.credited([
        ev(MatchEventType.yellowCard, a, 'Ravi'),
      ], a, b);
      expect((x, y), (0, 0));
    });
  });

  group('validate', () {
    test('fewer goal events than goals is fine', () {
      expect(check([ev(MatchEventType.goal, a, 'Ravi')], ga: 3), isNull);
    });

    test('more goal events than the score is rejected', () {
      expect(
        check([
          ev(MatchEventType.goal, a, 'Ravi'),
          ev(MatchEventType.goal, a, 'Ravi'),
        ], ga: 1),
        isNotNull,
      );
    });

    test('an own goal is checked against the other side\'s score', () {
      expect(check([ev(MatchEventType.ownGoal, a, 'Ravi')], gb: 0), isNotNull);
      expect(check([ev(MatchEventType.ownGoal, a, 'Ravi')], gb: 1), isNull);
    });

    test('unknown team, blank player and silly minutes are rejected', () {
      expect(check([ev(MatchEventType.goal, 'Z', 'X')]), isNotNull);
      expect(check([ev(MatchEventType.goal, a, '  ')]), isNotNull);
      expect(check([ev(MatchEventType.goal, a, 'X', minute: 0)]), isNotNull);
      expect(check([ev(MatchEventType.goal, a, 'X', minute: 200)]), isNotNull);
    });

    test('three yellows or two reds for one player is rejected', () {
      final y = ev(MatchEventType.yellowCard, a, 'Ravi');
      expect(check([y, y]), isNull);
      expect(check([y, y, y]), isNotNull);
      final r = ev(MatchEventType.redCard, a, 'ravi ');
      expect(check([r]), isNull);
      expect(check([r, r]), isNotNull);
    });
  });

  test('sorted puts unknown minutes last', () {
    final s = MatchEvents.sorted([
      ev(MatchEventType.goal, a, 'Late', minute: 80),
      ev(MatchEventType.goal, a, 'Unknown'),
      ev(MatchEventType.goal, a, 'Early', minute: 5),
    ]);
    expect(s.map((e) => e.player), ['Early', 'Late', 'Unknown']);
  });

  group('player stats', () {
    final matches = [
      match([
        ev(MatchEventType.goal, a, 'Ravi', assist: 'Kiran'),
        ev(MatchEventType.penaltyGoal, a, 'Ravi'),
        ev(MatchEventType.goal, b, 'Sam'),
        ev(MatchEventType.yellowCard, b, 'Sam'),
        ev(MatchEventType.redCard, a, 'Kiran'),
        ev(MatchEventType.ownGoal, b, 'Tom'),
      ]),
      match([
        ev(MatchEventType.goal, a, ' ravi ', assist: 'kiran'),
      ]),
      // Not completed: ignored.
      match([ev(MatchEventType.goal, b, 'Sam')], done: false),
    ];
    final all = PlayerStats.compute(matches: matches, teams: teams);

    PlayerStat find(String name) =>
        all.firstWhere((p) => p.name.toLowerCase() == name.toLowerCase());

    test('names match ignoring case and spaces', () {
      expect(find('Ravi').goals, 3);
      expect(find('Ravi').penaltyGoals, 1);
      expect(find('Kiran').assists, 2);
      expect(find('Ravi').teamName, 'Reds');
    });

    test('unfinished matches and own goals do not count as goals', () {
      expect(find('Sam').goals, 1);
      expect(find('Tom').goals, 0);
      expect(find('Tom').ownGoals, 1);
    });

    test('leaderboards', () {
      expect(PlayerStats.topScorers(all).map((p) => p.name).first, 'Ravi');
      expect(PlayerStats.topAssists(all).first.name, 'Kiran');
      // Red (3) outranks one yellow (1).
      expect(PlayerStats.discipline(all).first.name, 'Kiran');
      expect(PlayerStats.topScorers(all, limit: 1), hasLength(1));
    });
  });
}

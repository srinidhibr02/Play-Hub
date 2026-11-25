import 'package:flutter_test/flutter_test.dart';
import 'package:play_hub/logic/match_events.dart';
import 'package:play_hub/logic/player_stats.dart';
import 'package:play_hub/models/team.dart';
import 'package:play_hub/models/tournament_match.dart';

const a = 'A';
const b = 'B';

MatchEvent sub(String team, String on, String off, {int? minute}) =>
    MatchEvent(
      type: MatchEventType.substitution,
      teamId: team,
      player: on,
      playerOff: off,
      minute: minute,
    );

String? lineups(
  List<String> la,
  List<MatchEvent> events, {
  List<String> lb = const [],
  int max = 11,
}) =>
    MatchEvents.validateLineups(
      lineupA: la,
      lineupB: lb,
      events: events,
      teamAId: a,
      teamBId: b,
      maxPlayers: max,
    );

void main() {
  group('substitution events', () {
    test('need a player going off, different from the one coming on', () {
      expect(
        MatchEvents.validate(
          events: [sub(a, 'Ravi', '')],
          goalsA: 0,
          goalsB: 0,
          teamAId: a,
          teamBId: b,
        ),
        isNotNull,
      );
      expect(
        MatchEvents.validate(
          events: [sub(a, 'Ravi', ' ravi')],
          goalsA: 0,
          goalsB: 0,
          teamAId: a,
          teamBId: b,
        ),
        isNotNull,
      );
      expect(
        MatchEvents.validate(
          events: [sub(a, 'Ravi', 'Kiran')],
          goalsA: 0,
          goalsB: 0,
          teamAId: a,
          teamBId: b,
        ),
        isNull,
      );
    });

    test('are not goals or cards', () {
      final (x, y) = MatchEvents.credited([sub(a, 'Ravi', 'Kiran')], a, b);
      expect((x, y), (0, 0));
      expect(MatchEventType.substitution.isGoal, isFalse);
      expect(MatchEventType.substitution.isCard, isFalse);
    });
  });

  group('lineup validation', () {
    test('no lineup means substitutions are not checked', () {
      expect(lineups([], [sub(a, 'X', 'Y')]), isNull);
    });

    test('a valid substitution passes', () {
      expect(lineups(['Kiran', 'Sam'], [sub(a, 'Ravi', 'Kiran')]), isNull);
    });

    test('the player going off must be on the pitch', () {
      expect(
        lineups(['Kiran'], [sub(a, 'Ravi', 'Tom')]),
        contains('not on the pitch'),
      );
    });

    test('the player coming on must not already be playing', () {
      expect(
        lineups(['Kiran', 'Sam'], [sub(a, 'sam', 'Kiran')]),
        contains('already on the pitch'),
      );
    });

    test('a substituted player cannot return', () {
      expect(
        lineups(
          ['Kiran', 'Sam'],
          [
            sub(a, 'Ravi', 'Kiran', minute: 30),
            sub(a, 'Kiran', 'Sam', minute: 60),
          ],
        ),
        contains('cannot return'),
      );
    });

    test('a player who came on can later go off', () {
      expect(
        lineups(
          ['Kiran', 'Sam'],
          [
            sub(a, 'Ravi', 'Kiran', minute: 30),
            sub(a, 'Tom', 'Ravi', minute: 70),
          ],
        ),
        isNull,
      );
    });

    test('substitutions are applied in match order, not entry order', () {
      expect(
        lineups(
          ['Kiran'],
          [
            // Entered first but happens second.
            sub(a, 'Tom', 'Ravi', minute: 70),
            sub(a, 'Ravi', 'Kiran', minute: 30),
          ],
        ),
        isNull,
      );
    });

    test('too many or duplicate starters are rejected', () {
      expect(lineups(['A', 'B', 'C'], [], max: 2), contains('at most 2'));
      expect(lineups(['Ravi', ' ravi'], []), contains('twice'));
    });

    test('each side is checked against its own lineup', () {
      expect(
        lineups(['Kiran'], [sub(b, 'Ravi', 'Kiran')], lb: ['Sam']),
        contains('Lineup B'),
      );
    });
  });

  test('appearances: starters and substitutes count once per match', () {
    final teams = [
      const Team(id: a, name: 'Reds', shortName: 'RED', colorValue: 0),
      const Team(id: b, name: 'Blues', shortName: 'BLU', colorValue: 0),
    ];
    TournamentMatch match(MatchScore s, {bool done = true}) => TournamentMatch(
          id: 'm',
          round: 1,
          roundLabel: 'R1',
          order: 1,
          teamAId: a,
          teamBId: b,
          status: done ? MatchStatus.completed : MatchStatus.live,
          score: s,
        );

    final all = PlayerStats.compute(teams: teams, matches: [
      match(MatchScore(
        lineupA: const ['Kiran', 'Sam'],
        lineupB: const ['Tom'],
        events: [sub(a, 'Ravi', 'Kiran')],
      )),
      match(MatchScore(
        lineupA: const ['kiran'],
        events: [sub(a, 'Ravi', 'kiran'), sub(a, 'Ravi', 'x')],
      )),
      match(MatchScore(lineupA: const ['Kiran']), done: false),
    ]);
    PlayerStat find(String n) =>
        all.firstWhere((p) => p.name.toLowerCase() == n.toLowerCase());

    expect(find('Kiran').starts, 2);
    expect(find('Kiran').appearances, 2);
    expect(find('Ravi').starts, 0);
    expect(find('Ravi').appearances, 2);
    expect(find('Tom').teamName, 'Blues');
  });
}

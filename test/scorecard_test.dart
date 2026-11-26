import 'package:flutter_test/flutter_test.dart';
import 'package:play_hub/logic/scorecard.dart';
import 'package:play_hub/models/team.dart';
import 'package:play_hub/models/tournament_match.dart';

BatterLine bat(String name, int runs,
        {int balls = 0, int f = 0, int s = 0, bool out = true}) =>
    BatterLine(
      name: name,
      runs: runs,
      balls: balls,
      fours: f,
      sixes: s,
      out: out,
    );

BowlerLine bowl(String name, int balls, int runs, int wkts, {int m = 0}) =>
    BowlerLine(name: name, balls: balls, runs: runs, wickets: wkts, maidens: m);

String? check(MatchScore s, {int overs = 10}) =>
    Scorecard.validate(score: s, oversPerSide: overs);

void main() {
  group('validate', () {
    test('an empty scorecard is fine', () {
      expect(check(const MatchScore(runsA: 80, ballsA: 60)), isNull);
    });

    test('a consistent scorecard passes', () {
      final s = MatchScore(
        runsA: 80,
        wicketsA: 3,
        ballsA: 60,
        runsB: 60,
        wicketsB: 5,
        ballsB: 60,
        battersA: [
          bat('Ravi', 45, balls: 30, f: 4, s: 3),
          bat('Kiran', 30, balls: 25, out: false),
        ],
        bowlersB: [bowl('Sam', 24, 30, 2), bowl('Tom', 24, 40, 1)],
        bowlersA: [bowl('Ravi', 24, 20, 3, m: 1)],
      );
      expect(check(s), isNull);
      expect(Scorecard.extras(80, s.battersA), 5);
    });

    test('batters cannot out-score the team', () {
      final s = MatchScore(
        runsA: 50,
        wicketsA: 2,
        battersA: [bat('Ravi', 40), bat('Kiran', 20)],
      );
      expect(check(s), contains('team total'));
    });

    test('too many batters out for the wickets lost', () {
      final s = MatchScore(
        runsA: 50,
        wicketsA: 1,
        battersA: [bat('Ravi', 10), bat('Kiran', 10)],
      );
      expect(check(s), contains('out'));
    });

    test('boundaries cannot exceed runs or balls', () {
      expect(
        check(MatchScore(runsA: 50, battersA: [bat('A', 10, balls: 9, f: 3)])),
        contains('fours and sixes'),
      );
      expect(
        check(MatchScore(runsA: 50, battersA: [bat('A', 30, balls: 2, f: 3)])),
        contains('boundaries'),
      );
    });

    test('duplicate and blank names are rejected', () {
      expect(
        check(MatchScore(runsA: 50, battersA: [bat('Ravi', 1), bat(' ravi', 1)])),
        contains('twice'),
      );
      expect(
        check(MatchScore(runsA: 50, battersA: [bat(' ', 1)])),
        contains('name'),
      );
    });

    test('bowlers cannot take more wickets or bowl more than the innings', () {
      expect(
        check(MatchScore(
          runsA: 50,
          wicketsA: 2,
          ballsA: 60,
          bowlersB: [bowl('Sam', 24, 20, 3)],
        )),
        contains('wickets'),
      );
      expect(
        check(MatchScore(
          runsA: 50,
          ballsA: 30,
          bowlersB: [bowl('Sam', 24, 20, 0), bowl('Tom', 12, 10, 0)],
        )),
        contains('balls'),
      );
    });

    test('a bowler cannot exceed the over limit or concede too many', () {
      expect(
        check(MatchScore(runsA: 50, bowlersB: [bowl('Sam', 30, 20, 0)]),
            overs: 4),
        contains('more than 4 overs'),
      );
      expect(
        check(MatchScore(runsA: 20, bowlersB: [bowl('Sam', 12, 25, 0)])),
        contains('conceded'),
      );
    });

    test('maidens need complete overs', () {
      expect(
        check(MatchScore(runsA: 50, bowlersB: [bowl('Sam', 8, 5, 0, m: 2)])),
        contains('maidens'),
      );
    });
  });

  group('cricket leaders', () {
    final teams = [
      const Team(id: 'A', name: 'Reds', shortName: 'RED', colorValue: 0),
      const Team(id: 'B', name: 'Blues', shortName: 'BLU', colorValue: 0),
    ];
    TournamentMatch match(MatchScore s, {bool done = true}) => TournamentMatch(
          id: 'm',
          round: 1,
          roundLabel: 'R1',
          order: 1,
          teamAId: 'A',
          teamBId: 'B',
          status: done ? MatchStatus.completed : MatchStatus.live,
          score: s,
        );

    final all = CricketStats.compute(teams: teams, matches: [
      match(MatchScore(
        runsA: 120,
        wicketsA: 3,
        battersA: [
          bat('Ravi', 62, balls: 40, f: 5, s: 4, out: false),
          bat('Kiran', 20, balls: 20),
        ],
        bowlersB: [bowl('Sam', 24, 30, 2)],
        bowlersA: [bowl('Kiran', 24, 18, 3)],
      )),
      match(MatchScore(
        runsA: 90,
        wicketsA: 4,
        battersA: [bat('Ravi', 62, balls: 50, f: 6, s: 1)],
        bowlersA: [bowl('Kiran', 18, 25, 1)],
      )),
      // Not completed: ignored.
      match(
        MatchScore(runsA: 200, battersA: [bat('Ravi', 100)]),
        done: false,
      ),
    ]);

    CricketPlayerStat find(String n) => all.firstWhere((p) => p.name == n);

    test('batting totals, average and strike rate', () {
      final r = find('Ravi');
      expect(r.innings, 2);
      expect(r.runs, 124);
      expect(r.dismissals, 1);
      expect(r.notOuts, 1);
      expect(r.average, 124);
      expect(r.strikeRate, closeTo(124 * 100 / 90, 0.001));
      expect(r.fifties, 2);
      expect(r.sixes, 5);
    });

    test('highest score prefers not out when equal', () {
      expect(find('Ravi').highestText, '62*');
    });

    test('bowling totals and best figures', () {
      final k = find('Kiran');
      expect(k.wickets, 4);
      expect(k.ballsBowled, 42);
      expect(k.bestFigures, '3/18');
      expect(k.economy, closeTo(43 * 6 / 42, 0.001));
    });

    test('leaderboards', () {
      expect(CricketStats.topBatters(all).first.name, 'Ravi');
      expect(CricketStats.topBowlers(all).first.name, 'Kiran');
      expect(CricketStats.mostSixes(all).first.name, 'Ravi');
      expect(CricketStats.topBowlers(all, limit: 1), hasLength(1));
    });
  });
}

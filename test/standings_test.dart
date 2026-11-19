import 'package:flutter_test/flutter_test.dart';
import 'package:play_hub/logic/standings.dart';
import 'package:play_hub/models/sport.dart';
import 'package:play_hub/models/team.dart';
import 'package:play_hub/models/tournament.dart';
import 'package:play_hub/models/tournament_match.dart';

Team team(String id, int seed) => Team(
      id: id,
      name: 'Team $id',
      shortName: id,
      colorValue: 0xFF000000,
      seed: seed,
    );

final teams = [team('A', 0), team('B', 1), team('C', 2)];

int _n = 0;
TournamentMatch match(
  String a,
  String b,
  MatchScore score, {
  MatchStatus status = MatchStatus.completed,
}) {
  _n++;
  return TournamentMatch(
    id: 'm$_n',
    round: 1,
    roundLabel: 'Round 1',
    order: _n,
    teamAId: a,
    teamBId: b,
    teamAName: 'Team $a',
    teamBName: 'Team $b',
    status: status,
    score: score,
  );
}

List<Standing> table(Sport sport, List<TournamentMatch> matches) =>
    Standings.compute(
      sport: sport,
      settings: TournamentSettings.defaultsFor(sport),
      teams: teams,
      matches: matches,
    );

void main() {
  group('football', () {
    test('everyone is listed before any match, in entry order', () {
      final t = table(Sport.football, const []);
      expect(t.map((r) => r.team.id), ['A', 'B', 'C']);
      expect(t.every((r) => r.played == 0 && r.points == 0), isTrue);
    });

    test('3 points for a win, 1 for a draw', () {
      final t = table(Sport.football, [
        match('A', 'B', const MatchScore(goalsA: 2, goalsB: 0)),
        match('B', 'C', const MatchScore(goalsA: 1, goalsB: 1)),
      ]);
      final byId = {for (final r in t) r.team.id: r};
      expect(byId['A']!.points, 3);
      expect(byId['B']!.points, 1);
      expect(byId['C']!.points, 1);
      expect(byId['A']!.goalDifference, 2);
      expect(byId['B']!.goalsAgainst, 3);
      expect(t.first.team.id, 'A');
    });

    test('goal difference separates teams level on points', () {
      final t = table(Sport.football, [
        match('A', 'C', const MatchScore(goalsA: 1, goalsB: 0)),
        match('B', 'C', const MatchScore(goalsA: 4, goalsB: 0)),
      ]);
      expect(t.map((r) => r.team.id).toList(), ['B', 'A', 'C']);
    });

    test('live and scheduled matches are ignored', () {
      final t = table(Sport.football, [
        match('A', 'B', const MatchScore(goalsA: 5, goalsB: 0),
            status: MatchStatus.live),
        match('A', 'C', const MatchScore(goalsA: 5, goalsB: 0),
            status: MatchStatus.scheduled),
      ]);
      expect(t.every((r) => r.played == 0), isTrue);
    });
  });

  group('cricket', () {
    test('net run rate uses balls faced', () {
      // A: 60 in 6 overs. B: 50 in 6 overs. A wins.
      final t = table(Sport.cricket, [
        match(
          'A',
          'B',
          const MatchScore(runsA: 60, ballsA: 36, runsB: 50, ballsB: 36),
        ),
      ]);
      final a = t.firstWhere((r) => r.team.id == 'A');
      final b = t.firstWhere((r) => r.team.id == 'B');
      expect(a.points, 2);
      expect(a.netRunRate, closeTo(10 - 8.3333, 0.001));
      expect(b.netRunRate, closeTo(-(10 - 8.3333), 0.001));
    });

    test('a side bowled out is charged the full quota of overs', () {
      // Default is 10 overs = 60 balls. B all out in 4 overs for 30.
      final t = table(Sport.cricket, [
        match(
          'A',
          'B',
          const MatchScore(
            runsA: 90,
            ballsA: 60,
            runsB: 30,
            wicketsB: 10,
            ballsB: 24,
          ),
        ),
      ]);
      final b = t.firstWhere((r) => r.team.id == 'B');
      // B scored 30 off 10 overs (3.0), conceded 90 off 10 overs (9.0).
      expect(b.netRunRate, closeTo(-6.0, 0.001));
    });

    test('a tie gives each side the draw points', () {
      final t = table(Sport.cricket, [
        match(
          'A',
          'B',
          const MatchScore(runsA: 50, ballsA: 60, runsB: 50, ballsB: 60),
        ),
      ]);
      final a = t.firstWhere((r) => r.team.id == 'A');
      expect(a.drawn, 1);
      expect(a.points, 1);
    });
  });

  group('badminton', () {
    test('counts games and points, no draw points', () {
      final t = table(Sport.badminton, [
        match(
          'A',
          'B',
          const MatchScore(
            games: [GameScore(21, 15), GameScore(18, 21), GameScore(21, 19)],
          ),
        ),
      ]);
      final a = t.firstWhere((r) => r.team.id == 'A');
      final b = t.firstWhere((r) => r.team.id == 'B');
      expect(a.points, 2);
      expect(b.points, 0);
      expect(a.gamesFor, 2);
      expect(a.gamesAgainst, 1);
      expect(a.pointsFor, 60);
      expect(a.pointsAgainst, 55);
      expect(b.pointDifference, -5);
      expect(t.first.team.id, 'A');
    });
  });

  test('a match involving an unknown team is skipped', () {
    final t = table(Sport.football, [
      match('A', 'Z', const MatchScore(goalsA: 1, goalsB: 0)),
    ]);
    expect(t.every((r) => r.played == 0), isTrue);
  });
}

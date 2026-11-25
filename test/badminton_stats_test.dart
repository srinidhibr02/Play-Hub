import 'package:flutter_test/flutter_test.dart';
import 'package:play_hub/logic/badminton_stats.dart';
import 'package:play_hub/models/team.dart';
import 'package:play_hub/models/tournament_match.dart';

Team team(String id, String name, [List<String> players = const []]) => Team(
      id: id,
      name: name,
      shortName: id,
      colorValue: 0,
      players: players,
    );

int _n = 0;
TournamentMatch match(
  String a,
  String b,
  List<GameScore> games, {
  bool done = true,
}) {
  _n++;
  return TournamentMatch(
    id: 'm$_n',
    round: 1,
    roundLabel: 'R1',
    order: _n,
    teamAId: a,
    teamBId: b,
    status: done ? MatchStatus.completed : MatchStatus.live,
    score: MatchScore(games: games),
  );
}

void main() {
  final teams = [
    team('A', 'Ravi'),
    team('B', 'Kiran / Sam', ['Kiran', 'Sam']),
    team('C', 'Squad C', ['P1', 'P2', 'P3']),
  ];

  test('competitors: pairs credit both players, otherwise the team name', () {
    expect(BadmintonStats.competitors(teams[0]), ['Ravi']);
    expect(BadmintonStats.competitors(teams[1]), ['Kiran', 'Sam']);
    expect(BadmintonStats.competitors(teams[2]), ['Squad C']);
  });

  final all = BadmintonStats.compute(teams: teams, matches: [
    match('A', 'B', const [GameScore(21, 15), GameScore(21, 18)]),
    match('B', 'C', const [GameScore(21, 10), GameScore(15, 21), GameScore(21, 19)]),
    // Not completed: ignored.
    match('A', 'C', const [GameScore(21, 0), GameScore(21, 0)], done: false),
  ]);
  PlayerRecord find(String n) => all.firstWhere((p) => p.name == n);

  test('records for singles and doubles', () {
    final ravi = find('Ravi');
    expect(ravi.played, 1);
    expect(ravi.won, 1);
    expect(ravi.gamesFor, 2);
    expect(ravi.pointsFor, 42);
    expect(ravi.pointsAgainst, 33);

    // Both members of the pair get the same results: lost to Ravi, beat C.
    for (final n in ['Kiran', 'Sam']) {
      final r = find(n);
      expect(r.played, 2);
      expect(r.won, 1);
      expect(r.lost, 1);
    }
    expect(find('Squad C').lost, 1);
  });

  test('leaderboards', () {
    final wins = BadmintonStats.mostWins(all);
    expect(wins.first.won, 1);
    expect(wins.every((p) => p.won > 0), isTrue);
    // Ravi has the best win rate (1/1) among the one-win players.
    expect(wins.first.name, 'Ravi');
    expect(BadmintonStats.mostWins(all, limit: 1), hasLength(1));
    expect(
      BadmintonStats.bestPointDifference(all).every((p) => p.pointDifference > 0),
      isTrue,
    );
  });

  test('a drawn or unplayed match credits nobody', () {
    final r = BadmintonStats.compute(teams: teams, matches: [
      match('A', 'B', const []),
    ]);
    expect(r, isEmpty);
  });
}

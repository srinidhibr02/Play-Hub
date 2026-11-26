import 'package:flutter_test/flutter_test.dart';
import 'package:play_hub/logic/tournament_stats.dart';
import 'package:play_hub/models/sport.dart';
import 'package:play_hub/models/tournament_match.dart';

int _n = 0;
TournamentMatch m(
  MatchScore score, {
  MatchStatus status = MatchStatus.completed,
  bool bye = false,
}) {
  _n++;
  return TournamentMatch(
    id: 'm$_n',
    round: 1,
    roundLabel: 'Round 1',
    order: _n,
    teamAId: 'A$_n',
    teamBId: 'B$_n',
    teamAName: 'A$_n',
    teamBName: 'B$_n',
    status: status,
    score: score,
    isBye: bye,
  );
}

StatLine line(List<StatLine> l, String label) =>
    l.firstWhere((x) => x.label == label);

void main() {
  test('nothing played gives no stats', () {
    expect(TournamentStats.compute(sport: Sport.football, matches: const []),
        isEmpty);
    expect(
      TournamentStats.compute(sport: Sport.football, matches: [
        m(const MatchScore(goalsA: 3), status: MatchStatus.live),
      ]),
      isEmpty,
    );
  });

  test('football totals, average, biggest win and highest scoring', () {
    final s = TournamentStats.compute(sport: Sport.football, matches: [
      m(const MatchScore(goalsA: 5, goalsB: 0)),
      m(const MatchScore(goalsA: 2, goalsB: 3)),
      m(const MatchScore(goalsA: 1, goalsB: 1)),
    ]);
    expect(line(s, 'Total goals').value, '12');
    expect(line(s, 'Goals per match').value, '4.0');
    expect(line(s, 'Biggest win').value, 'by 5');
    expect(line(s, 'Highest scoring match').value, '5 goals');
  });

  test('football with only draws has no biggest win', () {
    final s = TournamentStats.compute(sport: Sport.football, matches: [
      m(const MatchScore(goalsA: 1, goalsB: 1)),
    ]);
    expect(s.any((x) => x.label == 'Biggest win'), isFalse);
  });

  test('cricket totals and highest total', () {
    final s = TournamentStats.compute(sport: Sport.cricket, matches: [
      m(const MatchScore(runsA: 100, wicketsA: 4, runsB: 90, wicketsB: 10)),
      m(const MatchScore(runsA: 80, wicketsA: 7, runsB: 120, wicketsB: 3)),
    ]);
    expect(line(s, 'Total runs').value, '390');
    expect(line(s, 'Runs per match').value, '195.0');
    expect(line(s, 'Highest total').value, '120/3');
    expect(line(s, 'Highest total').detail, 'B$_n');
  });

  test('badminton games, points and three-game matches', () {
    final s = TournamentStats.compute(sport: Sport.badminton, matches: [
      m(const MatchScore(
          games: [GameScore(21, 15), GameScore(18, 21), GameScore(21, 19)])),
      m(const MatchScore(games: [GameScore(21, 10), GameScore(21, 12)])),
    ]);
    expect(line(s, 'Games played').value, '5');
    expect(line(s, 'Points scored').value, '${21 + 15 + 18 + 21 + 21 + 19 + 21 + 10 + 21 + 12}');
    expect(line(s, 'Three-game thrillers').value, '1');
  });
}

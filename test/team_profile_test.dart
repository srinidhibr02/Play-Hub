import 'package:flutter_test/flutter_test.dart';
import 'package:play_hub/logic/team_profile.dart';
import 'package:play_hub/models/tournament_match.dart';

TournamentMatch m(
  int order, {
  String a = 'A',
  String b = 'B',
  String? winner,
  bool done = true,
  bool bye = false,
  int round = 1,
}) =>
    TournamentMatch(
      id: 'm$order',
      round: round,
      roundLabel: 'R$round',
      order: order,
      teamAId: a,
      teamBId: b,
      teamAName: 'Team $a',
      teamBName: 'Team $b',
      status: done ? MatchStatus.completed : MatchStatus.scheduled,
      score: done ? const MatchScore() : null,
      winnerId: winner,
      isBye: bye,
    );

void main() {
  test('results are seen from the team side', () {
    final h = TeamProfile.matchesFor('A', [
      m(1, winner: 'A'),
      m(2, a: 'C', b: 'A', winner: 'C'),
      m(3, a: 'A', b: 'D'),
    ]);
    expect(h.map((e) => e.result), [
      FormResult.win,
      FormResult.loss,
      FormResult.draw,
    ]);
    expect(h[1].opponentName, 'Team C');
    expect(h[1].isSideA, isFalse);
  });

  test('other teams, byes and ordering are handled', () {
    final h = TeamProfile.matchesFor('A', [
      m(2, round: 2, winner: 'A'),
      m(1, round: 1, winner: 'A'),
      m(3, a: 'X', b: 'Y', winner: 'X'),
      m(4, bye: true),
    ]);
    expect(h.map((e) => e.match.id), ['m1', 'm2']);
  });

  test('unplayed matches have no result and the next is the first of them',
      () {
    final h = TeamProfile.matchesFor('A', [
      m(1, winner: 'A'),
      m(2, done: false),
      m(3, done: false),
    ]);
    expect(h[1].result, isNull);
    expect(TeamProfile.next(h)!.match.id, 'm2');
    expect(TeamProfile.form(h), [FormResult.win]);
  });

  test('form keeps the latest five, oldest first', () {
    final h = TeamProfile.matchesFor('A', [
      for (var i = 1; i <= 7; i++) m(i, winner: i.isEven ? 'B' : 'A'),
    ]);
    final form = TeamProfile.form(h);
    expect(form.length, 5);
    expect(form.last, FormResult.win); // match 7
    expect(form.first, FormResult.win); // match 3
    expect(TeamProfile.next(h), isNull);
  });

  test('a team with no matches has empty history', () {
    expect(TeamProfile.matchesFor('Z', [m(1)]), isEmpty);
    expect(TeamProfile.form(const []), isEmpty);
  });
}

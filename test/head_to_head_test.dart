import 'package:flutter_test/flutter_test.dart';
import 'package:play_hub/logic/head_to_head.dart';
import 'package:play_hub/models/tournament_match.dart';

TournamentMatch m(
  String id,
  String a,
  String b, {
  String? winner,
  bool done = true,
  bool bye = false,
  int round = 1,
}) =>
    TournamentMatch(
      id: id,
      round: round,
      roundLabel: 'R$round',
      order: 1,
      teamAId: a,
      teamBId: b,
      status: done ? MatchStatus.completed : MatchStatus.scheduled,
      score: done ? const MatchScore() : null,
      winnerId: winner,
      isBye: bye,
    );

void main() {
  test('finds finished meetings in either order, excluding itself', () {
    final current = m('cur', 'A', 'B', done: false, round: 3);
    final all = [
      current,
      m('x', 'B', 'A', winner: 'B', round: 2),
      m('y', 'A', 'B', winner: 'A', round: 1),
      m('z', 'A', 'C', winner: 'A'),
      m('p', 'A', 'B', done: false, round: 4),
    ];
    final meetings = HeadToHead.otherMeetings(current, all);
    expect(meetings.map((e) => e.id), ['y', 'x']);
  });

  test('no meetings when a side is undecided or there is no rematch', () {
    final tbd = TournamentMatch(
      id: 't',
      round: 2,
      roundLabel: 'Final',
      order: 1,
      teamAId: 'A',
    );
    expect(HeadToHead.otherMeetings(tbd, [m('y', 'A', 'B')]), isEmpty);
    expect(
      HeadToHead.otherMeetings(m('cur', 'A', 'B'), [m('z', 'A', 'C')]),
      isEmpty,
    );
  });

  test('record counts wins and draws from team A perspective', () {
    final r = HeadToHead.record('A', [
      m('1', 'A', 'B', winner: 'A'),
      m('2', 'B', 'A', winner: 'B'),
      m('3', 'A', 'B', winner: 'A'),
      m('4', 'A', 'B'),
    ]);
    expect((r.winsA, r.winsB, r.draws, r.played), (2, 1, 1, 4));
  });
}

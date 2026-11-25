import 'package:flutter_test/flutter_test.dart';
import 'package:play_hub/logic/share_text.dart';
import 'package:play_hub/logic/standings.dart';
import 'package:play_hub/models/sport.dart';
import 'package:play_hub/models/team.dart';
import 'package:play_hub/models/tournament.dart';
import 'package:play_hub/models/tournament_match.dart';

Tournament tournament(Sport sport) => Tournament(
      id: 't',
      ownerId: 'o',
      ownerName: 'Owner',
      name: 'Sunday Cup',
      sport: sport,
      startDate: DateTime(2030, 1, 1),
      settings: TournamentSettings.defaultsFor(sport),
    );

TournamentMatch match(
  MatchScore? score, {
  MatchStatus status = MatchStatus.completed,
  String? winner = 'A',
  DateTime? at,
  String venue = '',
}) =>
    TournamentMatch(
      id: 'm',
      round: 1,
      roundLabel: 'Round 1',
      order: 1,
      teamAId: 'A',
      teamBId: 'B',
      teamAName: 'Falcons',
      teamBName: 'Tigers',
      status: status,
      score: score,
      winnerId: winner,
      scheduledAt: at,
      venue: venue,
    );

void main() {
  group('match', () {
    test('football result with scorers, penalties and own goals', () {
      final text = ShareText.match(
        tournament: tournament(Sport.football),
        match: match(
          const MatchScore(
            goalsA: 3,
            goalsB: 1,
            events: [
              MatchEvent(
                type: MatchEventType.goal,
                teamId: 'A',
                player: 'Ravi',
                minute: 12,
              ),
              MatchEvent(
                type: MatchEventType.penaltyGoal,
                teamId: 'A',
                player: 'Kiran',
                minute: 40,
              ),
              // Tigers' defender scores for Falcons.
              MatchEvent(
                type: MatchEventType.ownGoal,
                teamId: 'B',
                player: 'Tom',
                minute: 55,
              ),
              MatchEvent(
                type: MatchEventType.goal,
                teamId: 'B',
                player: 'Sam',
                minute: 70,
              ),
              MatchEvent(
                type: MatchEventType.yellowCard,
                teamId: 'B',
                player: 'Sam',
              ),
            ],
          ),
        ),
      );
      expect(text, contains('Sunday Cup | Round 1'));
      expect(text, contains('Falcons 3 - 1 Tigers'));
      expect(text, contains('Falcons won 3-1'));
      expect(text, contains("Falcons: Ravi 12', Kiran 40' (pen), Tom 55' (og)"));
      expect(text, contains("Tigers: Sam 70'"));
      expect(text, isNot(contains('yellow')));
    });

    test('live matches are marked live and have no result line', () {
      final text = ShareText.match(
        tournament: tournament(Sport.football),
        match: match(
          const MatchScore(goalsA: 1, goalsB: 0),
          status: MatchStatus.live,
          winner: null,
        ),
      );
      expect(text, contains('Falcons 1 - 0 Tigers (live)'));
      expect(text, isNot(contains('won')));
    });

    test('cricket shows both innings and the margin', () {
      final text = ShareText.match(
        tournament: tournament(Sport.cricket),
        match: match(
          const MatchScore(
            runsA: 80,
            wicketsA: 3,
            ballsA: 36,
            runsB: 60,
            wicketsB: 10,
            ballsB: 30,
          ),
        ),
      );
      expect(text, contains('Falcons 80/3 (6.0 ov)'));
      expect(text, contains('Tigers 60/10 (5.0 ov)'));
      expect(text, contains('won by 20 runs'));
    });

    test('badminton shows games and each game score', () {
      final text = ShareText.match(
        tournament: tournament(Sport.badminton),
        match: match(
          const MatchScore(
            games: [GameScore(21, 15), GameScore(18, 21), GameScore(21, 19)],
          ),
        ),
      );
      expect(text, contains('Falcons 2 - 1 Tigers'));
      expect(text, contains('21-15, 18-21, 21-19'));
    });

    test('an unplayed match shows the schedule', () {
      final text = ShareText.match(
        tournament: tournament(Sport.football),
        match: match(
          null,
          status: MatchStatus.scheduled,
          winner: null,
          at: DateTime(2030, 3, 5, 17, 30),
          venue: 'City Ground',
        ),
      );
      expect(text, contains('Falcons vs Tigers'));
      expect(text, contains('5 Mar 2030 at 5:30 PM'));
      expect(text, contains('Venue: City Ground'));
    });
  });

  test('table lists teams in order with points', () {
    final teams = [
      const Team(id: 'A', name: 'Falcons', shortName: 'FAL', colorValue: 0),
      const Team(id: 'B', name: 'Tigers', shortName: 'TIG', colorValue: 0),
    ];
    final t = tournament(Sport.football);
    final rows = Standings.compute(
      sport: t.sport,
      settings: t.settings,
      teams: teams,
      matches: [match(const MatchScore(goalsA: 2, goalsB: 0))],
    );
    final text = ShareText.table(tournament: t, rows: rows);
    final lines = text.split('\n');
    expect(lines.first, 'Sunday Cup | Table');
    expect(text, contains('1. Falcons: 3 pts (P1 W1 D0 L0 GD+2)'));
    expect(text, contains('2. Tigers: 0 pts (P1 W0 D0 L1 GD-2)'));
  });
}

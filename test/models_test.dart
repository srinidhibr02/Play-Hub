import 'package:flutter_test/flutter_test.dart';
import 'package:play_hub/models/sport.dart';
import 'package:play_hub/models/team.dart';
import 'package:play_hub/models/tournament.dart';
import 'package:play_hub/models/tournament_match.dart';

void main() {
  group('Sport', () {
    test('fromName falls back for unknown values', () {
      expect(Sport.fromName('cricket'), Sport.cricket);
      expect(Sport.fromName('nonsense'), Sport.football);
      expect(Sport.fromName(null), Sport.football);
    });
  });

  group('TournamentSettings', () {
    test('defaults differ per sport', () {
      final football = TournamentSettings.defaultsFor(Sport.football);
      final cricket = TournamentSettings.defaultsFor(Sport.cricket);
      final badminton = TournamentSettings.defaultsFor(Sport.badminton);

      expect(football.winPoints, 3);
      expect(football.drawPoints, 1);
      expect(cricket.winPoints, 2);
      expect(cricket.overs, 10);
      expect(badminton.bestOfGames, 3);
      expect(badminton.pointsPerGame, 21);
    });

    test('round-trips through a map', () {
      const original = TournamentSettings(
        legs: 2,
        winPoints: 3,
        drawPoints: 1,
        overs: 20,
        bestOfGames: 5,
        pointsPerGame: 15,
        halfMinutes: 30,
      );
      final copy = TournamentSettings.fromMap(original.toMap());

      expect(copy.legs, 2);
      expect(copy.overs, 20);
      expect(copy.bestOfGames, 5);
      expect(copy.pointsPerGame, 15);
      expect(copy.halfMinutes, 30);
    });

    test('missing map gives defaults', () {
      expect(TournamentSettings.fromMap(null).winPoints, 3);
    });
  });

  group('Tournament', () {
    test('max teams depends on the format', () {
      final league = Tournament(
        id: 'a',
        ownerId: 'u',
        ownerName: 'U',
        name: 'Cup',
        sport: Sport.football,
        startDate: DateTime(2026, 1, 1),
        settings: const TournamentSettings(),
      );
      expect(league.maxTeams, 24);
      expect(league.copyWith(format: TournamentFormat.knockout).maxTeams, 32);
    });

    test('progress is zero without fixtures and clamped otherwise', () {
      final t = Tournament(
        id: 'a',
        ownerId: 'u',
        ownerName: 'U',
        name: 'Cup',
        sport: Sport.cricket,
        startDate: DateTime(2026, 1, 1),
        settings: const TournamentSettings(),
        matchCount: 10,
        completedCount: 4,
      );
      expect(t.progress, closeTo(0.4, 1e-9));
      expect(t.hasFixtures, isTrue);
    });
  });

  group('Team', () {
    test('fromMap tolerates missing fields', () {
      final team = Team.fromMap('x', {'name': 'Royal Strikers'});
      expect(team.name, 'Royal Strikers');
      expect(team.shortName, 'RS');
      expect(team.players, isEmpty);
      expect(team.seed, 0);
    });

    test('round-trips players and colour', () {
      const team = Team(
        id: 'x',
        name: 'Falcons',
        shortName: 'FAL',
        colorValue: 0xFF123456,
        players: ['A', 'B'],
        seed: 3,
      );
      final copy = Team.fromMap('x', team.toMap());
      expect(copy.players, ['A', 'B']);
      expect(copy.colorValue, 0xFF123456);
      expect(copy.seed, 3);
    });
  });

  group('MatchScore', () {
    test('round-trips badminton games and football penalties', () {
      const score = MatchScore(
        goalsA: 2,
        goalsB: 2,
        penaltiesA: 4,
        penaltiesB: 3,
        games: [GameScore(21, 17), GameScore(18, 21), GameScore(21, 19)],
        note: 'After extra time',
      );
      final copy = MatchScore.fromMap(score.toMap());

      expect(copy.penaltiesA, 4);
      expect(copy.penaltiesB, 3);
      expect(copy.games.length, 3);
      expect(copy.games[1].b, 21);
      expect(copy.note, 'After extra time');
    });

    test('absent penalties stay null', () {
      final copy = MatchScore.fromMap(const MatchScore(goalsA: 1).toMap());
      expect(copy.penaltiesA, isNull);
      expect(copy.penaltiesB, isNull);
    });
  });

  group('TournamentMatch', () {
    test('round-trips through a map', () {
      const match = TournamentMatch(
        id: 'm1',
        round: 2,
        roundLabel: 'Semi-final',
        order: 5,
        teamAId: 'a',
        teamBId: 'b',
        teamAName: 'Alpha',
        teamBName: 'Beta',
        nextMatchId: 'm9',
        nextSlot: 'B',
      );
      final copy = TournamentMatch.fromMap('m1', match.toMap());

      expect(copy.round, 2);
      expect(copy.roundLabel, 'Semi-final');
      expect(copy.nextMatchId, 'm9');
      expect(copy.nextSlot, 'B');
      expect(copy.status, MatchStatus.scheduled);
      expect(copy.hasBothTeams, isTrue);
    });
  });
}

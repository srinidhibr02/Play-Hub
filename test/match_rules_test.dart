import 'package:flutter_test/flutter_test.dart';
import 'package:play_hub/logic/match_rules.dart';
import 'package:play_hub/models/sport.dart';
import 'package:play_hub/models/tournament.dart';
import 'package:play_hub/models/tournament_match.dart';

const a = 'A';
const b = 'B';

String? check(
  Sport sport,
  MatchScore score, {
  TournamentSettings? settings,
  bool knockout = false,
  String? tieBreak,
}) {
  return MatchRules.validate(
    sport: sport,
    settings: settings ?? TournamentSettings.defaultsFor(sport),
    score: score,
    knockout: knockout,
    teamAId: a,
    teamBId: b,
    tieBreakWinnerId: tieBreak,
  );
}

String? winner(Sport sport, MatchScore score, {String? tieBreak}) {
  return MatchRules.winnerId(
    sport: sport,
    score: score,
    teamAId: a,
    teamBId: b,
    tieBreakWinnerId: tieBreak,
  );
}

String summary(Sport sport, MatchScore score, String? winnerId) {
  return MatchRules.summary(
    sport: sport,
    score: score,
    teamAName: 'Falcons',
    teamBName: 'Tigers',
    teamAId: a,
    winnerId: winnerId,
  );
}

void main() {
  group('overs', () {
    test('formats balls as overs', () {
      expect(MatchRules.oversText(0), '0.0');
      expect(MatchRules.oversText(57), '9.3');
      expect(MatchRules.oversText(60), '10.0');
    });

    test('parses valid input', () {
      expect(MatchRules.parseOvers('10'), 60);
      expect(MatchRules.parseOvers('9.3'), 57);
      expect(MatchRules.parseOvers(' 0.5 '), 5);
    });

    test('rejects invalid input', () {
      expect(MatchRules.parseOvers(''), isNull);
      expect(MatchRules.parseOvers('9.6'), isNull);
      expect(MatchRules.parseOvers('-1'), isNull);
      expect(MatchRules.parseOvers('abc'), isNull);
      expect(MatchRules.parseOvers('9.33'), isNull);
    });
  });

  group('football', () {
    test('winner by goals, draw has no winner', () {
      expect(winner(Sport.football, const MatchScore(goalsA: 2, goalsB: 1)), a);
      expect(winner(Sport.football, const MatchScore(goalsA: 0, goalsB: 3)), b);
      expect(winner(Sport.football, const MatchScore(goalsA: 1, goalsB: 1)),
          isNull);
    });

    test('penalties decide a level knockout', () {
      const score = MatchScore(
        goalsA: 1,
        goalsB: 1,
        penaltiesA: 3,
        penaltiesB: 4,
      );
      expect(winner(Sport.football, score), b);
      expect(check(Sport.football, score, knockout: true), isNull);
    });

    test('a level knockout needs a shoot-out', () {
      const level = MatchScore(goalsA: 2, goalsB: 2);
      expect(check(Sport.football, level, knockout: true), isNotNull);
      expect(check(Sport.football, level), isNull); // league draw is fine

      const tiedPens = MatchScore(
        goalsA: 2,
        goalsB: 2,
        penaltiesA: 4,
        penaltiesB: 4,
      );
      expect(check(Sport.football, tiedPens, knockout: true), isNotNull);
    });

    test('rejects negative and silly values', () {
      expect(check(Sport.football, const MatchScore(goalsA: -1)), isNotNull);
      expect(check(Sport.football, const MatchScore(goalsA: 150)), isNotNull);
    });

    test('summaries', () {
      expect(
        summary(Sport.football, const MatchScore(goalsA: 3, goalsB: 1), a),
        'Falcons won 3-1',
      );
      expect(
        summary(Sport.football, const MatchScore(goalsA: 1, goalsB: 1), null),
        'Draw 1-1',
      );
      expect(
        summary(
          Sport.football,
          const MatchScore(
            goalsA: 1,
            goalsB: 1,
            penaltiesA: 2,
            penaltiesB: 4,
          ),
          b,
        ),
        'Tigers won 4-2 on penalties (1-1)',
      );
    });
  });

  group('cricket', () {
    test('winner by runs, tie has no winner without tie-break', () {
      expect(winner(Sport.cricket, const MatchScore(runsA: 120, runsB: 100)), a);
      expect(winner(Sport.cricket, const MatchScore(runsA: 90, runsB: 91)), b);
      expect(winner(Sport.cricket, const MatchScore(runsA: 100, runsB: 100)),
          isNull);
      expect(
        winner(Sport.cricket, const MatchScore(runsA: 100, runsB: 100),
            tieBreak: b),
        b,
      );
    });

    test('knockout tie needs a tie-break winner', () {
      const tied = MatchScore(runsA: 100, runsB: 100);
      expect(check(Sport.cricket, tied, knockout: true), isNotNull);
      expect(check(Sport.cricket, tied, knockout: true, tieBreak: a), isNull);
      expect(check(Sport.cricket, tied), isNull); // league tie is fine
    });

    test('wickets and overs are bounded', () {
      expect(check(Sport.cricket, const MatchScore(wicketsA: 11)), isNotNull);
      expect(check(Sport.cricket, const MatchScore(wicketsB: -1)), isNotNull);
      // Default is 10 overs = 60 balls.
      expect(check(Sport.cricket, const MatchScore(ballsA: 61)), isNotNull);
      expect(check(Sport.cricket, const MatchScore(ballsA: 60, runsA: 5)),
          isNull);
    });

    test('summary when the side batting first wins', () {
      const score = MatchScore(runsA: 120, wicketsA: 6, runsB: 100, wicketsB: 9);
      expect(summary(Sport.cricket, score, a), 'Falcons won by 20 runs');
    });

    test('summary when the chasing side wins', () {
      const score = MatchScore(runsA: 100, wicketsA: 8, runsB: 101, wicketsB: 3);
      expect(summary(Sport.cricket, score, b), 'Tigers won by 7 wickets');
    });

    test('summary respects who batted first', () {
      // B batted first and posted 150; A chased 151 for the loss of 9.
      const score = MatchScore(
        runsA: 151,
        wicketsA: 9,
        runsB: 150,
        wicketsB: 4,
        battedFirstA: false,
      );
      expect(summary(Sport.cricket, score, a), 'Falcons won by 1 wicket');
    });

    test('summary for singular run and for ties', () {
      const one = MatchScore(runsA: 101, runsB: 100);
      expect(summary(Sport.cricket, one, a), 'Falcons won by 1 run');

      const tied = MatchScore(runsA: 80, runsB: 80);
      expect(summary(Sport.cricket, tied, null), 'Match tied');
      expect(summary(Sport.cricket, tied, b),
          'Match tied. Tigers won the tie-break');
    });
  });

  group('badminton', () {
    test('valid and invalid single games (to 21)', () {
      expect(MatchRules.isValidGame(21, 15, 21), isTrue);
      expect(MatchRules.isValidGame(21, 19, 21), isTrue);
      expect(MatchRules.isValidGame(21, 20, 21), isFalse); // not 2 clear
      expect(MatchRules.isValidGame(22, 20, 21), isTrue); // deuce
      expect(MatchRules.isValidGame(23, 20, 21), isFalse); // should have ended
      expect(MatchRules.isValidGame(30, 29, 21), isTrue); // golden point
      expect(MatchRules.isValidGame(30, 28, 21), isTrue);
      expect(MatchRules.isValidGame(31, 29, 21), isFalse); // over the cap
      expect(MatchRules.isValidGame(20, 18, 21), isFalse); // not finished
      expect(MatchRules.isValidGame(-1, 21, 21), isFalse);
    });

    test('other game lengths', () {
      expect(MatchRules.isValidGame(15, 10, 15), isTrue);
      expect(MatchRules.isValidGame(21, 20, 15), isTrue); // golden point
      expect(MatchRules.isValidGame(21, 19, 15), isTrue); // cap 21 for 15
      expect(MatchRules.isValidGame(21, 18, 15), isFalse); // ended at 20-18
      expect(MatchRules.isValidGame(11, 9, 11), isTrue);
      expect(MatchRules.isValidGame(15, 14, 11), isTrue); // cap 15 for 11
    });

    test('best of 3: straight games and a decider', () {
      const straight = MatchScore(games: [GameScore(21, 10), GameScore(21, 15)]);
      expect(check(Sport.badminton, straight), isNull);
      expect(winner(Sport.badminton, straight), a);

      const decider = MatchScore(
        games: [GameScore(21, 17), GameScore(18, 21), GameScore(19, 21)],
      );
      expect(check(Sport.badminton, decider), isNull);
      expect(winner(Sport.badminton, decider), b);
    });

    test('rejects undecided and over-long matches', () {
      expect(check(Sport.badminton, const MatchScore()), isNotNull);

      const undecided = MatchScore(games: [GameScore(21, 10)]);
      expect(check(Sport.badminton, undecided), isNotNull);

      // A third game after the match was already decided 2-0.
      const extra = MatchScore(
        games: [GameScore(21, 10), GameScore(21, 15), GameScore(21, 5)],
      );
      expect(check(Sport.badminton, extra), isNotNull);

      const tooMany = MatchScore(
        games: [
          GameScore(21, 10),
          GameScore(10, 21),
          GameScore(21, 10),
          GameScore(10, 21),
        ],
      );
      expect(check(Sport.badminton, tooMany), isNotNull);
    });

    test('best of 1 and best of 5', () {
      final single = TournamentSettings.defaultsFor(Sport.badminton)
          .copyWith(bestOfGames: 1);
      expect(
        check(Sport.badminton, const MatchScore(games: [GameScore(21, 5)]),
            settings: single),
        isNull,
      );

      final five = TournamentSettings.defaultsFor(Sport.badminton)
          .copyWith(bestOfGames: 5);
      const twoNil = MatchScore(games: [GameScore(21, 5), GameScore(21, 5)]);
      expect(check(Sport.badminton, twoNil, settings: five), isNotNull);
      const threeNil = MatchScore(
        games: [GameScore(21, 5), GameScore(21, 5), GameScore(21, 5)],
      );
      expect(check(Sport.badminton, threeNil, settings: five), isNull);
    });

    test('invalid game is reported by number', () {
      const bad = MatchScore(games: [GameScore(21, 10), GameScore(21, 20)]);
      expect(check(Sport.badminton, bad), contains('Game 2'));
    });

    test('summary lists the games', () {
      const score = MatchScore(
        games: [GameScore(21, 17), GameScore(18, 21), GameScore(21, 19)],
      );
      expect(
        summary(Sport.badminton, score, a),
        'Falcons won 2-1 (21-17, 18-21, 21-19)',
      );
    });
  });

  group('sideScore', () {
    test('formats each sport', () {
      expect(
        MatchRules.sideScore(
          sport: Sport.football,
          score: const MatchScore(goalsA: 3, goalsB: 1),
          sideA: true,
        ),
        '3',
      );
      expect(
        MatchRules.sideScore(
          sport: Sport.cricket,
          score: const MatchScore(runsA: 142, wicketsA: 5),
          sideA: true,
        ),
        '142/5',
      );
      expect(
        MatchRules.sideScore(
          sport: Sport.badminton,
          score: const MatchScore(
            games: [GameScore(21, 17), GameScore(18, 21), GameScore(21, 19)],
          ),
          sideA: false,
        ),
        '1',
      );
    });
  });
}

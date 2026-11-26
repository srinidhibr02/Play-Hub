import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:play_hub/models/sport.dart';
import 'package:play_hub/models/team.dart';
import 'package:play_hub/models/tournament.dart';
import 'package:play_hub/models/tournament_match.dart';
import 'package:play_hub/services/pdf_export.dart';

Tournament tournament(Sport sport, TournamentFormat format, {String? name}) =>
    Tournament(
      id: 't',
      ownerId: 'o',
      ownerName: 'Owner',
      name: name ?? 'Sunday Cup',
      sport: sport,
      format: format,
      startDate: DateTime(2030, 1, 1),
      settings: TournamentSettings.defaultsFor(sport),
    );

final teams = [
  const Team(id: 'A', name: 'Falcons', shortName: 'FAL', colorValue: 0),
  const Team(id: 'B', name: 'Tigers', shortName: 'TIG', colorValue: 0),
];

TournamentMatch match({bool bye = false, MatchScore? score}) =>
    TournamentMatch(
      id: 'm${bye ? 'b' : ''}',
      round: 1,
      roundLabel: 'Round 1',
      order: 1,
      teamAId: 'A',
      teamBId: 'B',
      teamAName: 'Falcons',
      teamBName: 'Tigers',
      status: score == null ? MatchStatus.scheduled : MatchStatus.completed,
      score: score,
      winnerId: score == null ? null : 'A',
      isBye: bye,
    );

bool isPdf(List<int> bytes) =>
    latin1.decode(bytes.take(5).toList()) == '%PDF-';

void main() {
  for (final sport in Sport.values) {
    test('builds a PDF for a ${sport.name} league with results', () async {
      final bytes = await PdfExport.build(
        tournament: tournament(sport, TournamentFormat.roundRobin),
        teams: teams,
        matches: [
          match(
            score: switch (sport) {
              Sport.football => const MatchScore(goalsA: 2, goalsB: 1),
              Sport.cricket => const MatchScore(
                  runsA: 80,
                  wicketsA: 3,
                  ballsA: 60,
                  runsB: 60,
                  wicketsB: 5,
                  ballsB: 60,
                ),
              Sport.badminton => const MatchScore(
                  games: [GameScore(21, 15), GameScore(21, 18)],
                ),
            },
          ),
        ],
      );
      expect(isPdf(bytes), isTrue);
      expect(bytes.length, greaterThan(1000));
    });
  }

  test('builds for a knockout with a bye and no scores yet', () async {
    final bytes = await PdfExport.build(
      tournament: tournament(Sport.football, TournamentFormat.knockout),
      teams: teams,
      matches: [match(), match(bye: true)],
    );
    expect(isPdf(bytes), isTrue);
  });

  test('builds with no teams or matches at all', () async {
    final bytes = await PdfExport.build(
      tournament: tournament(Sport.cricket, TournamentFormat.roundRobin),
      teams: const [],
      matches: const [],
    );
    expect(isPdf(bytes), isTrue);
  });

  test('names with unsupported characters do not break the export', () async {
    final bytes = await PdfExport.build(
      tournament: tournament(
        Sport.football,
        TournamentFormat.roundRobin,
        name: 'ಕ್ರೀಡಾ Cup ₹',
      ),
      teams: teams,
      matches: [match(score: const MatchScore(goalsA: 1, goalsB: 0))],
    );
    expect(isPdf(bytes), isTrue);
  });
}

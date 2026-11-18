import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:play_hub/models/parse_utils.dart';

enum MatchStatus {
  scheduled,
  live,
  completed;

  String get label => switch (this) {
        MatchStatus.scheduled => 'Scheduled',
        MatchStatus.live => 'Live',
        MatchStatus.completed => 'Final',
      };

  static MatchStatus fromName(Object? name) =>
      parseEnum(MatchStatus.values, name, MatchStatus.scheduled);
}

/// One badminton game, e.g. 21-17.
class GameScore {
  const GameScore(this.a, this.b);

  final int a;
  final int b;

  Map<String, dynamic> toMap() => {'a': a, 'b': b};

  factory GameScore.fromMap(Map<String, dynamic> map) =>
      GameScore(parseInt(map['a']), parseInt(map['b']));
}

/// The score of a match. One shape covers all three sports; only the fields
/// for the match's sport are used.
///
///  * Football:  [goalsA]/[goalsB] and optional shoot-out [penaltiesA]/[penaltiesB]
///  * Cricket:   runs, wickets lost and balls faced for each side
///  * Badminton: a list of [games]
class MatchScore {
  const MatchScore({
    this.goalsA = 0,
    this.goalsB = 0,
    this.penaltiesA,
    this.penaltiesB,
    this.runsA = 0,
    this.wicketsA = 0,
    this.ballsA = 0,
    this.runsB = 0,
    this.wicketsB = 0,
    this.ballsB = 0,
    this.games = const [],
    this.note = '',
  });

  final int goalsA;
  final int goalsB;
  final int? penaltiesA;
  final int? penaltiesB;

  final int runsA;
  final int wicketsA;
  final int ballsA;
  final int runsB;
  final int wicketsB;
  final int ballsB;

  final List<GameScore> games;

  /// Free text such as "Won by 5 wickets" or "Walkover".
  final String note;

  Map<String, dynamic> toMap() => {
        'goalsA': goalsA,
        'goalsB': goalsB,
        'penaltiesA': penaltiesA,
        'penaltiesB': penaltiesB,
        'runsA': runsA,
        'wicketsA': wicketsA,
        'ballsA': ballsA,
        'runsB': runsB,
        'wicketsB': wicketsB,
        'ballsB': ballsB,
        'games': games.map((g) => g.toMap()).toList(),
        'note': note,
      };

  factory MatchScore.fromMap(Map<String, dynamic> map) {
    final gamesRaw = map['games'];
    return MatchScore(
      goalsA: parseInt(map['goalsA']),
      goalsB: parseInt(map['goalsB']),
      penaltiesA: map['penaltiesA'] is num ? parseInt(map['penaltiesA']) : null,
      penaltiesB: map['penaltiesB'] is num ? parseInt(map['penaltiesB']) : null,
      runsA: parseInt(map['runsA']),
      wicketsA: parseInt(map['wicketsA']),
      ballsA: parseInt(map['ballsA']),
      runsB: parseInt(map['runsB']),
      wicketsB: parseInt(map['wicketsB']),
      ballsB: parseInt(map['ballsB']),
      games: gamesRaw is List
          ? gamesRaw
              .whereType<Map<String, dynamic>>()
              .map(GameScore.fromMap)
              .toList()
          : const [],
      note: parseString(map['note']),
    );
  }
}

/// A single fixture. Named `TournamentMatch` to avoid clashing with
/// `dart:core`'s `Match`.
class TournamentMatch {
  const TournamentMatch({
    required this.id,
    required this.round,
    required this.roundLabel,
    required this.order,
    this.teamAId,
    this.teamBId,
    this.teamAName,
    this.teamBName,
    this.status = MatchStatus.scheduled,
    this.scheduledAt,
    this.venue = '',
    this.score,
    this.winnerId,
    this.nextMatchId,
    this.nextSlot,
    this.isBye = false,
  });

  final String id;

  /// 1-based round number.
  final int round;
  final String roundLabel;

  /// Global sort order across the whole fixture list.
  final int order;

  final String? teamAId;
  final String? teamBId;

  /// Team names are copied onto the match so the fixture list can be drawn
  /// without extra reads.
  final String? teamAName;
  final String? teamBName;

  final MatchStatus status;
  final DateTime? scheduledAt;
  final String venue;
  final MatchScore? score;

  /// Null while undecided, or after a drawn match.
  final String? winnerId;

  /// Knockout only: the match the winner moves into, and which side ('A' or
  /// 'B') of that match they take.
  final String? nextMatchId;
  final String? nextSlot;

  /// A first-round knockout slot where one side had no opponent.
  final bool isBye;

  bool get hasBothTeams => teamAId != null && teamBId != null;

  bool get isCompleted => status == MatchStatus.completed;

  TournamentMatch copyWith({
    String? teamAId,
    String? teamBId,
    String? teamAName,
    String? teamBName,
    MatchStatus? status,
    DateTime? scheduledAt,
    String? venue,
    MatchScore? score,
    String? winnerId,
  }) {
    return TournamentMatch(
      id: id,
      round: round,
      roundLabel: roundLabel,
      order: order,
      teamAId: teamAId ?? this.teamAId,
      teamBId: teamBId ?? this.teamBId,
      teamAName: teamAName ?? this.teamAName,
      teamBName: teamBName ?? this.teamBName,
      status: status ?? this.status,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      venue: venue ?? this.venue,
      score: score ?? this.score,
      winnerId: winnerId ?? this.winnerId,
      nextMatchId: nextMatchId,
      nextSlot: nextSlot,
      isBye: isBye,
    );
  }

  Map<String, dynamic> toMap() => {
        'round': round,
        'roundLabel': roundLabel,
        'order': order,
        'teamAId': teamAId,
        'teamBId': teamBId,
        'teamAName': teamAName,
        'teamBName': teamBName,
        'status': status.name,
        'scheduledAt':
            scheduledAt == null ? null : Timestamp.fromDate(scheduledAt!),
        'venue': venue,
        'score': score?.toMap(),
        'winnerId': winnerId,
        'nextMatchId': nextMatchId,
        'nextSlot': nextSlot,
        'isBye': isBye,
      };

  factory TournamentMatch.fromMap(String id, Map<String, dynamic> map) {
    final scoreRaw = map['score'];
    return TournamentMatch(
      id: id,
      round: parseInt(map['round'], 1),
      roundLabel: parseString(map['roundLabel'], 'Round 1'),
      order: parseInt(map['order']),
      teamAId: map['teamAId'] as String?,
      teamBId: map['teamBId'] as String?,
      teamAName: map['teamAName'] as String?,
      teamBName: map['teamBName'] as String?,
      status: MatchStatus.fromName(map['status']),
      scheduledAt: parseDate(map['scheduledAt']),
      venue: parseString(map['venue']),
      score: scoreRaw is Map<String, dynamic>
          ? MatchScore.fromMap(scoreRaw)
          : null,
      winnerId: map['winnerId'] as String?,
      nextMatchId: map['nextMatchId'] as String?,
      nextSlot: map['nextSlot'] as String?,
      isBye: parseBool(map['isBye']),
    );
  }
}

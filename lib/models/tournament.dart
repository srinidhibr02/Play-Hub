import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:play_hub/models/parse_utils.dart';
import 'package:play_hub/models/sport.dart';

enum TournamentFormat {
  roundRobin,
  knockout;

  String get label => switch (this) {
        TournamentFormat.roundRobin => 'League',
        TournamentFormat.knockout => 'Knockout',
      };

  String get description => switch (this) {
        TournamentFormat.roundRobin =>
          'Everyone plays everyone. Best record on the table wins.',
        TournamentFormat.knockout =>
          'Lose and you are out. Winners advance until the final.',
      };

  static TournamentFormat fromName(Object? name) =>
      parseEnum(TournamentFormat.values, name, TournamentFormat.roundRobin);
}

enum TournamentStatus {
  upcoming,
  live,
  completed;

  String get label => switch (this) {
        TournamentStatus.upcoming => 'Upcoming',
        TournamentStatus.live => 'Live',
        TournamentStatus.completed => 'Completed',
      };

  static TournamentStatus fromName(Object? name) =>
      parseEnum(TournamentStatus.values, name, TournamentStatus.upcoming);
}

/// Rules for a tournament. Fields that do not apply to the sport are simply
/// ignored (for example [overs] for football).
class TournamentSettings {
  const TournamentSettings({
    this.legs = 1,
    this.winPoints = 3,
    this.drawPoints = 1,
    this.lossPoints = 0,
    this.overs = 10,
    this.bestOfGames = 3,
    this.pointsPerGame = 21,
    this.halfMinutes = 20,
  });

  /// League only: 1 = single round robin, 2 = home and away.
  final int legs;

  final int winPoints;
  final int drawPoints;
  final int lossPoints;

  /// Cricket: overs per innings.
  final int overs;

  /// Badminton: best-of N games per match.
  final int bestOfGames;

  /// Badminton: points needed to win a game.
  final int pointsPerGame;

  /// Football: minutes per half.
  final int halfMinutes;

  factory TournamentSettings.defaultsFor(Sport sport) {
    switch (sport) {
      case Sport.football:
        return const TournamentSettings(
          winPoints: 3,
          drawPoints: 1,
          halfMinutes: 20,
        );
      case Sport.cricket:
        return const TournamentSettings(
          winPoints: 2,
          drawPoints: 1,
          overs: 10,
        );
      case Sport.badminton:
        return const TournamentSettings(
          winPoints: 2,
          drawPoints: 0,
          bestOfGames: 3,
          pointsPerGame: 21,
        );
    }
  }

  TournamentSettings copyWith({
    int? legs,
    int? winPoints,
    int? drawPoints,
    int? lossPoints,
    int? overs,
    int? bestOfGames,
    int? pointsPerGame,
    int? halfMinutes,
  }) {
    return TournamentSettings(
      legs: legs ?? this.legs,
      winPoints: winPoints ?? this.winPoints,
      drawPoints: drawPoints ?? this.drawPoints,
      lossPoints: lossPoints ?? this.lossPoints,
      overs: overs ?? this.overs,
      bestOfGames: bestOfGames ?? this.bestOfGames,
      pointsPerGame: pointsPerGame ?? this.pointsPerGame,
      halfMinutes: halfMinutes ?? this.halfMinutes,
    );
  }

  Map<String, dynamic> toMap() => {
        'legs': legs,
        'winPoints': winPoints,
        'drawPoints': drawPoints,
        'lossPoints': lossPoints,
        'overs': overs,
        'bestOfGames': bestOfGames,
        'pointsPerGame': pointsPerGame,
        'halfMinutes': halfMinutes,
      };

  factory TournamentSettings.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const TournamentSettings();
    const d = TournamentSettings();
    return TournamentSettings(
      legs: parseInt(map['legs'], d.legs),
      winPoints: parseInt(map['winPoints'], d.winPoints),
      drawPoints: parseInt(map['drawPoints'], d.drawPoints),
      lossPoints: parseInt(map['lossPoints'], d.lossPoints),
      overs: parseInt(map['overs'], d.overs),
      bestOfGames: parseInt(map['bestOfGames'], d.bestOfGames),
      pointsPerGame: parseInt(map['pointsPerGame'], d.pointsPerGame),
      halfMinutes: parseInt(map['halfMinutes'], d.halfMinutes),
    );
  }
}

class Tournament {
  const Tournament({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    required this.name,
    required this.sport,
    required this.startDate,
    required this.settings,
    this.format = TournamentFormat.roundRobin,
    this.status = TournamentStatus.upcoming,
    this.venue = '',
    this.description = '',
    this.teamCount = 0,
    this.matchCount = 0,
    this.completedCount = 0,
    this.isPublic = true,
    this.createdAt,
  });

  final String id;
  final String ownerId;
  final String ownerName;
  final String name;
  final Sport sport;
  final TournamentFormat format;
  final TournamentStatus status;
  final String venue;
  final String description;
  final DateTime startDate;
  final TournamentSettings settings;

  /// Denormalised counters, kept in sync by the repository.
  final int teamCount;
  final int matchCount;
  final int completedCount;

  /// Public tournaments can be followed by anyone in the Discover tab.
  final bool isPublic;
  final DateTime? createdAt;

  bool get hasFixtures => matchCount > 0;

  /// Upper limit keeps a fixture list inside Firestore batch limits.
  int get maxTeams => format == TournamentFormat.roundRobin ? 24 : 32;

  double get progress =>
      matchCount == 0 ? 0 : (completedCount / matchCount).clamp(0.0, 1.0);

  Tournament copyWith({
    String? name,
    TournamentFormat? format,
    TournamentStatus? status,
    String? venue,
    String? description,
    DateTime? startDate,
    TournamentSettings? settings,
    bool? isPublic,
  }) {
    return Tournament(
      id: id,
      ownerId: ownerId,
      ownerName: ownerName,
      name: name ?? this.name,
      sport: sport,
      startDate: startDate ?? this.startDate,
      settings: settings ?? this.settings,
      format: format ?? this.format,
      status: status ?? this.status,
      venue: venue ?? this.venue,
      description: description ?? this.description,
      teamCount: teamCount,
      matchCount: matchCount,
      completedCount: completedCount,
      isPublic: isPublic ?? this.isPublic,
      createdAt: createdAt,
    );
  }

  /// Serialised form. `createdAt` is added by the repository using a server
  /// timestamp, so it is intentionally not part of this map.
  Map<String, dynamic> toMap() => {
        'ownerId': ownerId,
        'ownerName': ownerName,
        'name': name,
        'sport': sport.name,
        'format': format.name,
        'status': status.name,
        'venue': venue,
        'description': description,
        'startDate': Timestamp.fromDate(startDate),
        'settings': settings.toMap(),
        'teamCount': teamCount,
        'matchCount': matchCount,
        'completedCount': completedCount,
        'isPublic': isPublic,
      };

  factory Tournament.fromMap(String id, Map<String, dynamic> map) {
    final settingsRaw = map['settings'];
    return Tournament(
      id: id,
      ownerId: parseString(map['ownerId']),
      ownerName: parseString(map['ownerName']),
      name: parseString(map['name'], 'Untitled tournament'),
      sport: Sport.fromName(map['sport']),
      format: TournamentFormat.fromName(map['format']),
      status: TournamentStatus.fromName(map['status']),
      venue: parseString(map['venue']),
      description: parseString(map['description']),
      startDate: parseDate(map['startDate']) ?? DateTime.now(),
      settings: TournamentSettings.fromMap(
        settingsRaw is Map<String, dynamic> ? settingsRaw : null,
      ),
      teamCount: parseInt(map['teamCount']),
      matchCount: parseInt(map['matchCount']),
      completedCount: parseInt(map['completedCount']),
      isPublic: parseBool(map['isPublic'], true),
      createdAt: parseDate(map['createdAt']),
    );
  }
}

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

/// How a tournament is run.
///
///  * [friendly]: a quick local game. Created instantly, the organizer adds
///    the teams directly. No registration and no fees.
///  * [hosted]: an organised event. Invites go out, teams register (with an
///    optional entry fee) and the organizer approves them before fixtures
///    are drawn.
enum TournamentKind {
  friendly,
  hosted;

  String get label => switch (this) {
        TournamentKind.friendly => 'Friendly',
        TournamentKind.hosted => 'Hosted',
      };

  String get title => switch (this) {
        TournamentKind.friendly => 'Friendly tournament',
        TournamentKind.hosted => 'Hosted tournament',
      };

  String get tagline => switch (this) {
        TournamentKind.friendly => 'Set up in a minute, play today',
        TournamentKind.hosted => 'Invites, registration and entry fees',
      };

  List<String> get highlights => switch (this) {
        TournamentKind.friendly => const [
            'Created instantly',
            'You add the teams yourself',
            'No sign-ups, no fees',
          ],
        TournamentKind.hosted => const [
            'Share an invite code with teams',
            'Teams register, you approve',
            'Optional entry fee, tracked per team',
          ],
      };

  static TournamentKind fromName(Object? name) =>
      parseEnum(TournamentKind.values, name, TournamentKind.friendly);
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
    this.kind = TournamentKind.friendly,
    this.format = TournamentFormat.roundRobin,
    this.status = TournamentStatus.upcoming,
    this.venue = '',
    this.description = '',
    this.teamCount = 0,
    this.matchCount = 0,
    this.completedCount = 0,
    this.isPublic = true,
    this.createdAt,
    this.inviteCode = '',
    this.capacity = 0,
    this.registrationOpen = false,
    this.registrationDeadline,
    this.entryFee = 0,
    this.upiId = '',
    this.payeeName = '',
    this.acceptCash = false,
    this.contactPhone = '',
  });

  final String id;
  final String ownerId;
  final String ownerName;
  final String name;
  final Sport sport;
  final TournamentKind kind;
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

  /// Listed in the Discover tab. An unlisted tournament can still be opened
  /// by anyone who has its invite code.
  final bool isPublic;
  final DateTime? createdAt;

  /// Short code (for example "K7M2QX") that people use to find the
  /// tournament. Empty on tournaments created before invite codes existed.
  final String inviteCode;

  // ---- Hosted tournaments only ----

  /// Maximum teams the organizer will accept. 0 means "format maximum".
  final int capacity;
  final bool registrationOpen;

  /// Last day on which teams can register (inclusive).
  final DateTime? registrationDeadline;

  /// Entry fee per team in rupees. 0 means free.
  final int entryFee;

  /// Where teams pay the fee. The app only tells people where to pay and
  /// lets the organizer record that it arrived; it never moves money.
  final String upiId;
  final String payeeName;
  final bool acceptCash;
  final String contactPhone;

  bool get isHosted => kind == TournamentKind.hosted;
  bool get hasFixtures => matchCount > 0;
  bool get hasEntryFee => entryFee > 0;

  /// Upper limit keeps a fixture list inside Firestore batch limits.
  int get formatMaxTeams => format == TournamentFormat.roundRobin ? 24 : 32;

  /// How many teams can take part: the organizer's [capacity] (hosted),
  /// never above what the format supports.
  int get maxTeams {
    if (isHosted && capacity > 0) {
      return capacity < formatMaxTeams ? capacity : formatMaxTeams;
    }
    return formatMaxTeams;
  }

  bool get isFull => teamCount >= maxTeams;

  double get progress =>
      matchCount == 0 ? 0 : (completedCount / matchCount).clamp(0.0, 1.0);

  bool deadlinePassed(DateTime now) {
    final d = registrationDeadline;
    if (d == null) return false;
    // The deadline day itself is still open.
    final endOfDay = DateTime(d.year, d.month, d.day, 23, 59, 59);
    return now.isAfter(endOfDay);
  }

  /// Why teams cannot register right now, or null if they can.
  String? registrationBlockedReason(DateTime now) {
    if (!isHosted) return 'This tournament does not take registrations.';
    if (hasFixtures) return 'Fixtures are drawn, so registration is closed.';
    if (!registrationOpen) return 'Registration is closed.';
    if (deadlinePassed(now)) return 'The registration deadline has passed.';
    if (isFull) return 'This tournament is full.';
    return null;
  }

  bool canRegister(DateTime now) => registrationBlockedReason(now) == null;

  Tournament copyWith({
    String? name,
    TournamentFormat? format,
    TournamentStatus? status,
    String? venue,
    String? description,
    DateTime? startDate,
    TournamentSettings? settings,
    bool? isPublic,
    bool? registrationOpen,
  }) {
    return Tournament(
      id: id,
      ownerId: ownerId,
      ownerName: ownerName,
      name: name ?? this.name,
      sport: sport,
      startDate: startDate ?? this.startDate,
      settings: settings ?? this.settings,
      kind: kind,
      format: format ?? this.format,
      status: status ?? this.status,
      venue: venue ?? this.venue,
      description: description ?? this.description,
      teamCount: teamCount,
      matchCount: matchCount,
      completedCount: completedCount,
      isPublic: isPublic ?? this.isPublic,
      createdAt: createdAt,
      inviteCode: inviteCode,
      capacity: capacity,
      registrationOpen: registrationOpen ?? this.registrationOpen,
      registrationDeadline: registrationDeadline,
      entryFee: entryFee,
      upiId: upiId,
      payeeName: payeeName,
      acceptCash: acceptCash,
      contactPhone: contactPhone,
    );
  }

  /// Serialised form. `createdAt` is added by the repository using a server
  /// timestamp, so it is intentionally not part of this map.
  Map<String, dynamic> toMap() => {
        'ownerId': ownerId,
        'ownerName': ownerName,
        'name': name,
        'sport': sport.name,
        'kind': kind.name,
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
        'inviteCode': inviteCode,
        'capacity': capacity,
        'registrationOpen': registrationOpen,
        'registrationDeadline': registrationDeadline == null
            ? null
            : Timestamp.fromDate(registrationDeadline!),
        'entryFee': entryFee,
        'upiId': upiId,
        'payeeName': payeeName,
        'acceptCash': acceptCash,
        'contactPhone': contactPhone,
      };

  factory Tournament.fromMap(String id, Map<String, dynamic> map) {
    final settingsRaw = map['settings'];
    return Tournament(
      id: id,
      ownerId: parseString(map['ownerId']),
      ownerName: parseString(map['ownerName']),
      name: parseString(map['name'], 'Untitled tournament'),
      sport: Sport.fromName(map['sport']),
      kind: TournamentKind.fromName(map['kind']),
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
      inviteCode: parseString(map['inviteCode']),
      capacity: parseInt(map['capacity']),
      registrationOpen: parseBool(map['registrationOpen']),
      registrationDeadline: parseDate(map['registrationDeadline']),
      entryFee: parseInt(map['entryFee']),
      upiId: parseString(map['upiId']),
      payeeName: parseString(map['payeeName']),
      acceptCash: parseBool(map['acceptCash']),
      contactPhone: parseString(map['contactPhone']),
    );
  }
}

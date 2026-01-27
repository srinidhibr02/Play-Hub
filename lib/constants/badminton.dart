// Models
import 'package:cloud_firestore/cloud_firestore.dart';

class Team {
  final String id;
  final String name;
  final List<String> players;

  Team({required this.id, required this.name, required this.players});

  // 🔥 NEW: toMap() - Convert Team to Map for Firestore
  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'players': players};
  }

  // 🔥 NEW: fromMap() - Create Team from Firestore Map
  factory Team.fromMap(Map<String, dynamic> map) {
    return Team(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      players: List<String>.from(map['players'] ?? []),
    );
  }
}

// Extended Match class with parent team tracking
class Match {
  final String id;
  final Team team1;
  final Team team2;
  final DateTime date;
  final String time;
  String status;
  int score1;
  int score2;
  String? winner;
  List<Map<String, int>>? setResults; // 🔥 NEW FIELD FOR SET RESULTS
  final String? parentTeam1Id;
  final String? parentTeam2Id;
  final int? round;
  final String? roundName;
  final String? stage;
  final int? rematchNumber;
  final bool? isBye; // ✅ NEW FIELD FOR KNOCKOUT

  Match({
    required this.id,
    required this.team1,
    required this.team2,
    required this.date,
    required this.time,
    required this.status,
    required this.score1,
    required this.score2,
    this.setResults,
    this.winner,
    this.parentTeam1Id,
    this.parentTeam2Id,
    this.round,
    this.roundName,
    this.stage,
    this.rematchNumber,
    this.isBye = false, // ✅ DEFAULT FALSE
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'team1': {'id': team1.id, 'name': team1.name, 'players': team1.players},
      'team2': {'id': team2.id, 'name': team2.name, 'players': team2.players},
      'date': date.toIso8601String(),
      'time': time,
      'status': status,
      'score1': score1,
      'score2': score2,
      'setResults': setResults ?? [], // ✅ FIXED: Properly serialize setResults
      'winner': winner,
      'parentTeam1Id': parentTeam1Id,
      'parentTeam2Id': parentTeam2Id,
      'round': round,
      'roundName': roundName,
      'stage': stage,
      'rematchNumber': rematchNumber,
      'isBye': isBye ?? false,
    };
  }

  factory Match.fromJson(Map<String, dynamic> json) {
    try {
      // Safely extract team1 data
      final team1Data = json['team1'] as Map<String, dynamic>?;
      if (team1Data == null) {
        throw Exception('team1 data is missing');
      }

      final team1 = Team(
        id: team1Data['id'] as String? ?? '',
        name: team1Data['name'] as String? ?? '',
        players: List<String>.from(team1Data['players'] as List? ?? []),
      );

      // Safely extract team2 data
      final team2Data = json['team2'] as Map<String, dynamic>?;
      if (team2Data == null) {
        throw Exception('team2 data is missing');
      }

      final team2 = Team(
        id: team2Data['id'] as String? ?? '',
        name: team2Data['name'] as String? ?? '',
        players: List<String>.from(team2Data['players'] as List? ?? []),
      );

      // Parse date safely
      final dateStr = json['date'] as String?;
      late DateTime parsedDate;
      if (dateStr != null && dateStr.isNotEmpty) {
        parsedDate = DateTime.parse(dateStr);
      } else {
        parsedDate = DateTime.now();
      }

      // ✅ FIXED: Parse setResults from JSON
      List<Map<String, int>>? parsedSetResults;
      final setResultsData = json['setResults'] as List?;
      if (setResultsData != null && setResultsData.isNotEmpty) {
        parsedSetResults = (setResultsData).map((item) {
          if (item is Map<String, dynamic>) {
            return {
              'team1': (item['team1'] as num?)?.toInt() ?? 0,
              'team2': (item['team2'] as num?)?.toInt() ?? 0,
            };
          }
          return {'team1': 0, 'team2': 0};
        }).toList();
      }

      return Match(
        id: json['id'] as String? ?? '',
        team1: team1,
        team2: team2,
        date: parsedDate,
        time: json['time'] as String? ?? '',
        status: json['status'] as String? ?? 'Scheduled',
        score1: (json['score1'] as num?)?.toInt() ?? 0,
        score2: (json['score2'] as num?)?.toInt() ?? 0,
        setResults: parsedSetResults, // ✅ FIXED: Assign parsed setResults
        winner: json['winner'] as String?,
        parentTeam1Id: json['parentTeam1Id'] as String?,
        parentTeam2Id: json['parentTeam2Id'] as String?,
        round: (json['round'] as num?)?.toInt(),
        roundName: json['roundName'] as String?,
        stage: json['stage'] as String?,
        rematchNumber: (json['rematchNumber'] as num?)?.toInt(),
        isBye: json['isBye'] as bool? ?? false,
      );
    } catch (e) {
      rethrow;
    }
  }

  factory Match.fromMap(Map<String, dynamic> map) {
    try {
      // ✅ Safe team1 extraction
      final team1Data = map['team1'] as Map<String, dynamic>?;
      final team1 = Team(
        id: team1Data?['id'] as String? ?? '',
        name: team1Data?['name'] as String? ?? '',
        players: List<String>.from(team1Data?['players'] as List? ?? []),
      );

      // ✅ Safe team2 extraction
      final team2Data = map['team2'] as Map<String, dynamic>?;
      final team2 = Team(
        id: team2Data?['id'] as String? ?? '',
        name: team2Data?['name'] as String? ?? '',
        players: List<String>.from(team2Data?['players'] as List? ?? []),
      );

      // ✅ Safe date parsing
      final scheduledDate = map['scheduledDate'] as Timestamp?;
      final date = scheduledDate?.toDate() ?? DateTime.now();

      // ✅ FIXED: Parse setResults from Firestore
      List<Map<String, int>>? parsedSetResults;
      final setResultsData = map['setResults'] as List?;
      if (setResultsData != null && setResultsData.isNotEmpty) {
        parsedSetResults = (setResultsData).map((item) {
          if (item is Map<String, dynamic>) {
            return {
              'team1': (item['team1'] as num?)?.toInt() ?? 0,
              'team2': (item['team2'] as num?)?.toInt() ?? 0,
            };
          }
          return {'team1': 0, 'team2': 0};
        }).toList();
      }

      return Match(
        id: map['id'] as String? ?? '',
        team1: team1,
        team2: team2,
        date: date,
        time: map['time'] as String? ?? '',
        status: map['status'] as String? ?? 'Scheduled',
        score1: (map['score1'] as num?)?.toInt() ?? 0,
        score2: (map['score2'] as num?)?.toInt() ?? 0,
        setResults: parsedSetResults, // ✅ FIXED: Assign parsed setResults
        winner: map['winner'] as String?,
        parentTeam1Id: map['parentTeam1Id'] as String?,
        parentTeam2Id: map['parentTeam2Id'] as String?,
        round: (map['round'] as num?)?.toInt(),
        roundName: map['roundName'] as String?,
        stage: map['stage'] as String?,
        rematchNumber: (map['rematchNumber'] as num?)?.toInt(),
        isBye: map['isBye'] as bool? ?? false,
      );
    } catch (e) {
      // Return default match to prevent crash
      return Match(
        id: '',
        team1: Team(id: '', name: 'Error', players: []),
        team2: Team(id: '', name: 'Error', players: []),
        date: DateTime.now(),
        time: '',
        status: 'Error',
        score1: 0,
        score2: 0,
        isBye: false,
      );
    }
  }

  Match copyWith({
    String? status,
    int? score1,
    int? score2,
    String? winner,
    List<Map<String, int>>? setResults, // ✅ FIXED: Added setResults parameter
    bool? isBye,
  }) {
    return Match(
      id: id,
      team1: team1,
      team2: team2,
      date: date,
      time: time,
      status: status ?? this.status,
      score1: score1 ?? this.score1,
      score2: score2 ?? this.score2,
      setResults:
          setResults ??
          this.setResults, // ✅ FIXED: Preserve or update setResults
      winner: winner ?? this.winner,
      parentTeam1Id: parentTeam1Id,
      parentTeam2Id: parentTeam2Id,
      round: round,
      roundName: roundName,
      stage: stage,
      rematchNumber: rematchNumber,
      isBye: isBye ?? this.isBye,
    );
  }

  static Match empty() {
    return Match(
      id: '',
      team1: Team(id: 'TBD', name: 'TBD', players: []),
      team2: Team(id: 'TBD', name: 'TBD', players: []),
      date: DateTime.now(),
      time: '',
      status: 'Pending',
      score1: 0,
      score2: 0,
      winner: null,
      parentTeam1Id: null,
      parentTeam2Id: null,
      round: null,
      roundName: null,
      stage: null,
      rematchNumber: null,
      setResults: [], // ✅ Initialize empty setResults
      isBye: false,
    );
  }
}

class TeamStats {
  final String teamId;
  final String teamName;
  final List<String> players;
  int matchesPlayed;
  int won;
  int lost;
  int points;
  int netResult;

  TeamStats({
    required this.teamId,
    required this.teamName,
    required this.players,
    required this.matchesPlayed,
    required this.won,
    required this.lost,
    required this.points,
    required this.netResult,
  });
}

// ==================== HELPER CLASSES ====================
class TeamPairing {
  final Team team1;
  final Team team2;

  TeamPairing(this.team1, this.team2);
}

class TeamWithDoublesPairs {
  final Team team;
  final List<DoublesPair> doublesPairs;

  TeamWithDoublesPairs(this.team, this.doublesPairs);
}

class DoublesMatch {
  final Team team1;
  final Team team2;
  final DoublesPair pair1;
  final DoublesPair pair2;

  DoublesMatch(this.team1, this.team2, this.pair1, this.pair2);
}

class DoublesPair {
  final String player1;
  final String player2;

  DoublesPair(this.player1, this.player2);
}

class PlayerStats {
  final String playerName;
  final String teamId;
  final String teamName;
  int matchesPlayed;
  int wins;
  int losses;
  int totalPoints; // Points scored in matches they played
  int totalPointsAgainst; // Points conceded in matches they played
  int netResult;

  PlayerStats({
    required this.playerName,
    required this.teamId,
    required this.teamName,
    this.matchesPlayed = 0,
    this.wins = 0,
    this.losses = 0,
    this.totalPoints = 0,
    this.totalPointsAgainst = 0,
    this.netResult = 0,
  });

  double get winRate => matchesPlayed > 0 ? (wins / matchesPlayed) * 100 : 0.0;
  double get avgPointsScored =>
      matchesPlayed > 0 ? totalPoints / matchesPlayed : 0.0;
  double get avgPointsConceded =>
      matchesPlayed > 0 ? totalPointsAgainst / matchesPlayed : 0.0;
}

// Models
class Team {
  final String id;
  final String name;
  final List<String> players;

  Team({required this.id, required this.name, required this.players});
}

class MatchPair {
  final Team team1;
  final Team team2;

  MatchPair(this.team1, this.team2);
}

class DoublesPair {
  final String player1;
  final String player2;

  DoublesPair(this.player1, this.player2);
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
  final String? parentTeam1Id;
  final String? parentTeam2Id;
  final int? round; // ✅ ADD THIS
  final String? roundName; // ✅ ADD THIS

  Match({
    required this.id,
    required this.team1,
    required this.team2,
    required this.date,
    required this.time,
    required this.status,
    required this.score1,
    required this.score2,
    this.winner,
    this.parentTeam1Id,
    this.parentTeam2Id,
    this.round, // ✅ ADD THIS
    this.roundName, // ✅ ADD THIS
  });

  // Update your toMap() method to include new fields:
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
      'winner': winner,
      'parentTeam1Id': parentTeam1Id,
      'parentTeam2Id': parentTeam2Id,
      'round': round, // ✅ ADD THIS
      'roundName': roundName, // ✅ ADD THIS
    };
  }

  // Update your fromMap() method:
  factory Match.fromMap(Map<String, dynamic> map) {
    return Match(
      id: map['id'],
      team1: Team(
        id: map['team1']['id'],
        name: map['team1']['name'],
        players: List<String>.from(map['team1']['players']),
      ),
      team2: Team(
        id: map['team2']['id'],
        name: map['team2']['name'],
        players: List<String>.from(map['team2']['players']),
      ),
      date: DateTime.parse(map['date']),
      time: map['time'],
      status: map['status'],
      score1: map['score1'],
      score2: map['score2'],
      winner: map['winner'],
      parentTeam1Id: map['parentTeam1Id'],
      parentTeam2Id: map['parentTeam2Id'],
      round: map['round'], // ✅ ADD THIS
      roundName: map['roundName'], // ✅ ADD THIS
    );
  }

  // Update copyWith method:
  Match copyWith({String? status, int? score1, int? score2, String? winner}) {
    return Match(
      id: id,
      team1: team1,
      team2: team2,
      date: date,
      time: time,
      status: status ?? this.status,
      score1: score1 ?? this.score1,
      score2: score2 ?? this.score2,
      winner: winner ?? this.winner,
      parentTeam1Id: parentTeam1Id,
      parentTeam2Id: parentTeam2Id,
      round: round, // ✅ ADD THIS
      roundName: roundName, // ✅ ADD THIS
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

  TeamStats({
    required this.teamId,
    required this.teamName,
    required this.players,
    required this.matchesPlayed,
    required this.won,
    required this.lost,
    required this.points,
  });
}

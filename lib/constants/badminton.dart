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
  });

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

import 'package:flutter/material.dart';
import 'package:play_hub/constants/badminton.dart';

// Model for player statistics
class PlayerStats {
  final String playerName;
  final String teamId;
  final String teamName;
  int matchesPlayed;
  int wins;
  int losses;
  int totalPoints; // Points scored in matches they played
  int totalPointsAgainst; // Points conceded in matches they played

  PlayerStats({
    required this.playerName,
    required this.teamId,
    required this.teamName,
    this.matchesPlayed = 0,
    this.wins = 0,
    this.losses = 0,
    this.totalPoints = 0,
    this.totalPointsAgainst = 0,
  });

  double get winRate => matchesPlayed > 0 ? (wins / matchesPlayed) * 100 : 0.0;
  double get avgPointsScored =>
      matchesPlayed > 0 ? totalPoints / matchesPlayed : 0.0;
  double get avgPointsConceded =>
      matchesPlayed > 0 ? totalPointsAgainst / matchesPlayed : 0.0;
}

// Widget to display player statistics
class PlayerStatsWidget extends StatelessWidget {
  final List<Match> completedMatches;
  final List<Team> teams;

  const PlayerStatsWidget({
    super.key,
    required this.completedMatches,
    required this.teams,
  });

  Map<String, PlayerStats> _calculatePlayerStats() {
    final playerStatsMap = <String, PlayerStats>{};

    // Initialize all players
    for (final team in teams) {
      for (final player in team.players) {
        playerStatsMap[player] = PlayerStats(
          playerName: player,
          teamId: team.id,
          teamName: team.name,
        );
      }
    }

    // Process completed matches
    for (final match in completedMatches) {
      if (match.status != 'Completed' || match.winner == null) continue;

      // Get players from both teams
      final team1Players = match.team1.players;
      final team2Players = match.team2.players;

      // Determine which parent team won
      final team1Won = match.winner == match.team1.id;

      // Update stats for team 1 players
      for (final player in team1Players) {
        if (playerStatsMap.containsKey(player)) {
          playerStatsMap[player]!.matchesPlayed++;
          playerStatsMap[player]!.totalPoints += match.score1;
          playerStatsMap[player]!.totalPointsAgainst += match.score2;

          if (team1Won) {
            playerStatsMap[player]!.wins++;
          } else {
            playerStatsMap[player]!.losses++;
          }
        }
      }

      // Update stats for team 2 players
      for (final player in team2Players) {
        if (playerStatsMap.containsKey(player)) {
          playerStatsMap[player]!.matchesPlayed++;
          playerStatsMap[player]!.totalPoints += match.score2;
          playerStatsMap[player]!.totalPointsAgainst += match.score1;

          if (!team1Won) {
            playerStatsMap[player]!.wins++;
          } else {
            playerStatsMap[player]!.losses++;
          }
        }
      }
    }

    return playerStatsMap;
  }

  @override
  Widget build(BuildContext context) {
    final playerStats = _calculatePlayerStats();

    // Group players by team
    final teamGroups = <String, List<PlayerStats>>{};
    for (final stats in playerStats.values) {
      teamGroups.putIfAbsent(stats.teamId, () => []).add(stats);
    }

    // Sort players within each team by win rate
    teamGroups.forEach((teamId, players) {
      players.sort((a, b) => b.winRate.compareTo(a.winRate));
    });

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange.shade600, Colors.orange.shade700],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.analytics, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Individual Player Statistics',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Stats by team
          ...teamGroups.entries.map((entry) {
            final teamId = entry.key;
            final players = entry.value;
            final team = teams.firstWhere((t) => t.id == teamId);

            return _buildTeamSection(team, players);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildTeamSection(Team team, List<PlayerStats> players) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Team header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.groups,
                    color: Colors.orange.shade700,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  team.name,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade900,
                  ),
                ),
                const Spacer(),
                Text(
                  '${players.length} players',
                  style: TextStyle(fontSize: 14, color: Colors.orange.shade700),
                ),
              ],
            ),
          ),

          // Column headers
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Player',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Played',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Won',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Lost',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Win %',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Player rows
          ...players.map((stats) => _buildPlayerRow(stats)).toList(),
        ],
      ),
    );
  }

  Widget _buildPlayerRow(PlayerStats stats) {
    final winRateColor = stats.winRate >= 60
        ? Colors.green
        : stats.winRate >= 40
        ? Colors.orange
        : Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          // Player name
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      stats.playerName[0].toUpperCase(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    stats.playerName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Matches played
          Expanded(
            flex: 1,
            child: Text(
              '${stats.matchesPlayed}',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
          ),

          // Wins
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${stats.wins}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
            ),
          ),

          // Losses
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${stats.losses}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
            ),
          ),

          // Win rate
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${stats.winRate.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: winRateColor,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  stats.winRate >= 50 ? Icons.trending_up : Icons.trending_down,
                  size: 16,
                  color: winRateColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Expanded version with detailed stats
class DetailedPlayerStatsWidget extends StatelessWidget {
  final List<Match> completedMatches;
  final List<Team> teams;

  const DetailedPlayerStatsWidget({
    super.key,
    required this.completedMatches,
    required this.teams,
  });

  Map<String, PlayerStats> _calculatePlayerStats() {
    final playerStatsMap = <String, PlayerStats>{};

    for (final team in teams) {
      for (final player in team.players) {
        playerStatsMap[player] = PlayerStats(
          playerName: player,
          teamId: team.id,
          teamName: team.name,
        );
      }
    }

    for (final match in completedMatches) {
      if (match.status != 'Completed' || match.winner == null) continue;

      final team1Players = match.team1.players;
      final team2Players = match.team2.players;
      final team1Won = match.winner == match.team1.id;

      for (final player in team1Players) {
        if (playerStatsMap.containsKey(player)) {
          playerStatsMap[player]!.matchesPlayed++;
          playerStatsMap[player]!.totalPoints += match.score1;
          playerStatsMap[player]!.totalPointsAgainst += match.score2;
          if (team1Won) {
            playerStatsMap[player]!.wins++;
          } else {
            playerStatsMap[player]!.losses++;
          }
        }
      }

      for (final player in team2Players) {
        if (playerStatsMap.containsKey(player)) {
          playerStatsMap[player]!.matchesPlayed++;
          playerStatsMap[player]!.totalPoints += match.score2;
          playerStatsMap[player]!.totalPointsAgainst += match.score1;
          if (!team1Won) {
            playerStatsMap[player]!.wins++;
          } else {
            playerStatsMap[player]!.losses++;
          }
        }
      }
    }

    return playerStatsMap;
  }

  @override
  Widget build(BuildContext context) {
    final playerStats = _calculatePlayerStats();
    final allPlayers = playerStats.values.toList()
      ..sort((a, b) => b.winRate.compareTo(a.winRate));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange.shade600, Colors.orange.shade700],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.emoji_events, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Player Leaderboard',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Player list with detailed stats
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: allPlayers.length,
            itemBuilder: (context, index) {
              final stats = allPlayers[index];
              return _buildDetailedPlayerCard(stats, index + 1);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedPlayerCard(PlayerStats stats, int rank) {
    final rankColor = rank == 1
        ? Colors.amber
        : rank == 2
        ? Colors.grey.shade400
        : rank == 3
        ? Colors.brown.shade300
        : Colors.grey.shade300;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: rank <= 3 ? rankColor : Colors.grey.shade300,
          width: rank <= 3 ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Rank badge
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: rankColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '#$rank',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: rank <= 3 ? Colors.white : Colors.grey.shade700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Player info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stats.playerName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    Text(
                      stats.teamName,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              // Win rate
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${stats.winRate.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade700,
                    ),
                  ),
                  Text(
                    'Win Rate',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Stats row
          Row(
            children: [
              _buildStatChip('Played', '${stats.matchesPlayed}', Colors.blue),
              const SizedBox(width: 8),
              _buildStatChip('Won', '${stats.wins}', Colors.green),
              const SizedBox(width: 8),
              _buildStatChip('Lost', '${stats.losses}', Colors.red),
              const SizedBox(width: 8),
              _buildStatChip(
                'Avg Score',
                stats.avgPointsScored.toStringAsFixed(1),
                Colors.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

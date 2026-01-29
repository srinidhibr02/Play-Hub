import 'package:flutter/material.dart';
import 'package:play_hub/constants/badminton.dart';

class PlayerStats {
  final String playerName;
  final String teamId;
  final String teamName;
  int matchesPlayed;
  int wins;
  int losses;
  int totalPoints;
  int totalPointsAgainst;

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

  Color get performanceColor {
    if (winRate >= 70) return Colors.amber.shade400;
    if (winRate >= 60) return Colors.green.shade400;
    if (winRate >= 50) return Colors.blue.shade400;
    if (winRate >= 40) return Colors.orange.shade400;
    return Colors.red.shade400;
  }
}

class FinalPlayerStatsWidget extends StatefulWidget {
  final Future<List<Match>> completedMatches;
  final Future<List<Team>> teams;

  const FinalPlayerStatsWidget({
    super.key,
    required this.completedMatches,
    required this.teams,
  });

  @override
  State<FinalPlayerStatsWidget> createState() => _FinalPlayerStatsWidgetState();
}

class _FinalPlayerStatsWidgetState extends State<FinalPlayerStatsWidget>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  List<PlayerStats> sortedPlayers = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnim = Tween(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _loadData();
  }

  Future<void> _loadData() async {
    final statsMap = await _calculatePlayerStats();
    final players = statsMap.values.toList();

    players.sort((a, b) => b.winRate.compareTo(a.winRate));

    if (mounted) {
      setState(() => sortedPlayers = players);
      _controller.forward();
    }
  }

  Future<Map<String, PlayerStats>> _calculatePlayerStats() async {
    final statsMap = <String, PlayerStats>{};
    final teamsList = await widget.teams;

    for (final team in teamsList) {
      for (final player in team.players) {
        statsMap[player] = PlayerStats(
          playerName: player,
          teamId: team.id,
          teamName: team.name,
        );
      }
    }

    final matchesList = await widget.completedMatches;
    for (final match in matchesList) {
      if (match.status != 'Completed' || match.winner == null) continue;

      final team1Won = match.winner == match.team1.id;

      for (final player in match.team1.players) {
        if (statsMap.containsKey(player)) {
          final stats = statsMap[player]!;
          stats.matchesPlayed++;
          stats.totalPoints += match.score1;
          stats.totalPointsAgainst += match.score2;
          if (team1Won) {
            stats.wins++;
          } else {
            stats.losses++;
          }
        }
      }

      for (final player in match.team2.players) {
        if (statsMap.containsKey(player)) {
          final stats = statsMap[player]!;
          stats.matchesPlayed++;
          stats.totalPoints += match.score2;
          stats.totalPointsAgainst += match.score1;
          if (!team1Won) {
            stats.wins++;
          } else {
            stats.losses++;
          }
        }
      }
    }
    return statsMap;
  }

  @override
  Widget build(BuildContext context) {
    if (sortedPlayers.isEmpty) {
      return Container(
        height: 650,
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((255 * 0.05).toInt()),
              blurRadius: 20,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.orange),
              SizedBox(height: 16),
              Text(
                'Loading stats...',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        height: 650,
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((255 * 0.06).toInt()),
              blurRadius: 25,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              margin: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange.shade600, Colors.deepOrange.shade500],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withAlpha((255 * 0.3).toInt()),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.leaderboard, color: Colors.white, size: 28),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Player Statistics',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '${sortedPlayers.length} players • ${sortedPlayers.fold<int>(0, (sum, p) => sum + p.matchesPlayed)} matches',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withAlpha((255 * 0.9).toInt()),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Table Header
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: const Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: Text(
                      'Rank',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Center(
                      child: Text(
                        'Player',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Text(
                        'Played',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Won',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Lost',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Text(
                        'Win %',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Table Rows
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: sortedPlayers.length,
                separatorBuilder: (context, index) =>
                    Container(height: 1, color: Colors.grey.shade200),
                itemBuilder: (context, index) {
                  final stats = sortedPlayers[index];
                  return Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 12,
                    ),
                    child: Row(
                      children: [
                        // Rank
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: stats.performanceColor.withAlpha(
                              (255 * 0.1).toInt(),
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Player Name
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                stats.playerName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade900,
                                ),
                              ),
                              Text(
                                stats.teamName,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Played
                        Expanded(
                          child: Center(
                            child: Text(
                              '${stats.matchesPlayed}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),

                        // Won
                        Expanded(
                          child: Center(
                            child: Text(
                              '${stats.wins}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ),
                        ),

                        // Lost
                        Expanded(
                          child: Center(
                            child: Text(
                              '${stats.losses}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ),
                        ),

                        // Win %
                        Expanded(
                          flex: 2,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: stats.performanceColor.withAlpha(
                                  (255 * 0.1).toInt(),
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${stats.winRate.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: stats.performanceColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

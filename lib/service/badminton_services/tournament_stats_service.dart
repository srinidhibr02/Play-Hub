import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:play_hub/constants/badminton.dart';

class TournamentStatsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference _getUserTournamentsCollection(String userEmail) {
    return _firestore.collection('sharedTournaments');
  }

  /// Fetch all completed matches for a tournament
  Future<List<Match>> getCompletedMatches(
    String userEmail,
    String tournamentId,
  ) async {
    try {
      debugPrint('📥 Fetching completed matches for tournament: $tournamentId');

      // Fetch all matches first, then filter in code
      final matchesSnapshot = await _getUserTournamentsCollection(
        userEmail,
      ).doc(tournamentId).collection('matches').get();

      debugPrint('📥 Total documents fetched: ${matchesSnapshot.docs.length}');

      final matches = <Match>[];
      for (final doc in matchesSnapshot.docs) {
        try {
          final data = doc.data();
          debugPrint('📄 Processing match ${doc.id}');
          debugPrint('   Status field: ${data['status']}');

          // Check various possible status field names
          final status = data['status'] ?? data['Status'] ?? '';

          if (status.toString().toLowerCase() == 'completed') {
            final match = Match.fromMap(data);
            matches.add(match);
            debugPrint('   ✅ Added completed match');
          } else {
            debugPrint('   ⏭️  Skipped (status: $status)');
          }
        } catch (e, stackTrace) {
          debugPrint('⚠️ Error processing match ${doc.id}: $e');
          debugPrint('   Stack: $stackTrace');
          debugPrint('   Data keys: ${doc.data().keys.toList()}');
        }
      }

      debugPrint('✅ Fetched ${matches.length} completed matches');
      return matches;
    } catch (e, stackTrace) {
      debugPrint('❌ Error fetching completed matches: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Stream of completed matches (real-time updates)
  Stream<List<Match>> getCompletedMatchesStream(
    String userEmail,
    String tournamentId,
  ) {
    return _getUserTournamentsCollection(
      userEmail,
    ).doc(tournamentId).collection('matches').snapshots().map((snapshot) {
      debugPrint('🔄 Real-time update: ${snapshot.docs.length} total matches');

      final completedMatches = <Match>[];
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          final status = data['status'] ?? data['Status'] ?? '';

          if (status.toString().toLowerCase() == 'completed') {
            completedMatches.add(Match.fromMap(data));
          }
        } catch (e) {
          debugPrint('⚠️ Skipping match ${doc.id}: $e');
        }
      }

      debugPrint('🔄 Filtered to ${completedMatches.length} completed matches');
      return completedMatches;
    });
  }

  /// Fetch all matches (any status) for a tournament
  Future<List<Match>> getAllMatches(
    String userEmail,
    String tournamentId,
  ) async {
    try {
      debugPrint('📥 Fetching all matches for tournament: $tournamentId');

      final matchesSnapshot = await _getUserTournamentsCollection(
        userEmail,
      ).doc(tournamentId).collection('matches').get();

      final matches = <Match>[];
      for (final doc in matchesSnapshot.docs) {
        try {
          final match = Match.fromMap(doc.data());
          matches.add(match);
        } catch (e) {
          debugPrint('⚠️ Error parsing match ${doc.id}: $e');
        }
      }

      debugPrint('✅ Fetched ${matches.length} total matches');
      return matches;
    } catch (e, stackTrace) {
      debugPrint('❌ Error fetching matches: $e');
      debugPrint('Stack: $stackTrace');
      rethrow;
    }
  }

  /// Stream of all matches (real-time updates)
  Stream<List<Match>> getAllMatchesStream(
    String userEmail,
    String tournamentId,
  ) {
    return _getUserTournamentsCollection(
      userEmail,
    ).doc(tournamentId).collection('matches').snapshots().map((snapshot) {
      final matches = <Match>[];
      for (final doc in snapshot.docs) {
        try {
          matches.add(Match.fromMap(doc.data()));
        } catch (e) {
          debugPrint('⚠️ Error parsing match ${doc.id}: $e');
        }
      }
      return matches;
    });
  }

  /// Fetch all teams for a tournament
  Future<List<Team>> getTeams(String userEmail, String tournamentId) async {
    try {
      debugPrint('📥 Fetching teams for tournament: $tournamentId');

      final teamsSnapshot = await _getUserTournamentsCollection(
        userEmail,
      ).doc(tournamentId).collection('teams').get();

      final teams = teamsSnapshot.docs.map((doc) {
        final data = doc.data();
        return Team.fromMap(data);
      }).toList();

      debugPrint('✅ Fetched ${teams.length} teams');
      return teams;
    } catch (e) {
      debugPrint('❌ Error fetching teams: $e');
      rethrow;
    }
  }

  /// Stream of teams (real-time updates)
  Stream<List<Team>> getTeamsStream(String userEmail, String tournamentId) {
    return _getUserTournamentsCollection(
      userEmail,
    ).doc(tournamentId).collection('teams').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Team.fromMap(doc.data())).toList();
    });
  }

  /// Calculate player statistics from completed matches
  Map<String, PlayerStats> calculatePlayerStats(
    List<Match> completedMatches,
    List<Team> teams,
  ) {
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

    debugPrint('📊 Calculating stats for ${playerStatsMap.length} players');

    // Process completed matches
    for (final match in completedMatches) {
      try {
        final status = match.status?.toLowerCase() ?? '';
        if (status != 'completed' ||
            match.winner == null ||
            match.winner!.isEmpty) {
          debugPrint(
            '⏭️ Skipping match ${match.id}: status=$status, winner=${match.winner}',
          );
          continue;
        }

        final team1Players = match.team1.players;
        final team2Players = match.team2.players;

        if (team1Players.isEmpty || team2Players.isEmpty) {
          debugPrint('⚠️ Skipping match ${match.id}: Empty player lists');
          continue;
        }

        final team1Won = match.winner == match.team1.id;
        final score1 = match.score1 ?? 0;
        final score2 = match.score2 ?? 0;

        // 🔥 Calculate point difference for this match
        final pointDifference = team1Won
            ? (score1 - score2)
            : (score2 - score1);

        // Update stats for team 1 players
        for (final player in team1Players) {
          if (playerStatsMap.containsKey(player)) {
            playerStatsMap[player]!.matchesPlayed++;
            playerStatsMap[player]!.totalPoints += score1;
            playerStatsMap[player]!.totalPointsAgainst += score2;

            if (team1Won) {
              playerStatsMap[player]!.wins++;
              playerStatsMap[player]!.netResult +=
                  pointDifference; // 🔥 +4 for A vs B
            } else {
              playerStatsMap[player]!.losses++;
              playerStatsMap[player]!.netResult -=
                  pointDifference; // 🔥 -9 for A vs C
            }
          }
        }

        // Update stats for team 2 players
        for (final player in team2Players) {
          if (playerStatsMap.containsKey(player)) {
            playerStatsMap[player]!.matchesPlayed++;
            playerStatsMap[player]!.totalPoints += score2;
            playerStatsMap[player]!.totalPointsAgainst += score1;

            if (!team1Won) {
              playerStatsMap[player]!.wins++;
              playerStatsMap[player]!.netResult +=
                  pointDifference; // 🔥 Winner gets +diff
            } else {
              playerStatsMap[player]!.losses++;
              playerStatsMap[player]!.netResult -=
                  pointDifference; // 🔥 Loser gets -diff
            }
          }
        }

        debugPrint(
          '✅ Match ${match.id}: Team1=${score1}-${score2}=Team2, diff=$pointDifference',
        );
      } catch (e, stackTrace) {
        debugPrint('⚠️ Error processing match ${match.id}: $e');
        continue;
      }
    }

    debugPrint('✅ Stats calculated for ${completedMatches.length} matches');

    // Debug output
    playerStatsMap.forEach((player, stats) {
      if (stats.matchesPlayed > 0) {
        debugPrint(
          '   $player: ${stats.wins}W-${stats.losses}L (${stats.winRate.toStringAsFixed(1)}%)',
        );
      }
    });

    return playerStatsMap;
  }

  /// Get tournament statistics summary
  Future<TournamentStatsSummary> getTournamentStats(
    String userEmail,
    String tournamentId,
  ) async {
    try {
      final matches = await getAllMatches(userEmail, tournamentId);
      final teams = await getTeams(userEmail, tournamentId);

      final completedMatches = matches
          .where((m) => m.status == 'Completed')
          .toList();
      final scheduledMatches = matches
          .where((m) => m.status == 'scheduled')
          .toList();
      final ongoingMatches = matches
          .where((m) => m.status == 'ongoing')
          .toList();

      return TournamentStatsSummary(
        totalMatches: matches.length,
        completedMatches: completedMatches.length,
        scheduledMatches: scheduledMatches.length,
        ongoingMatches: ongoingMatches.length,
        totalTeams: teams.length,
        playerStats: calculatePlayerStats(completedMatches, teams),
      );
    } catch (e) {
      debugPrint('❌ Error getting tournament stats: $e');
      rethrow;
    }
  }

  /// Stream of tournament statistics (real-time)
  Stream<TournamentStatsSummary> getTournamentStatsStream(
    String userEmail,
    String tournamentId,
  ) async* {
    try {
      await for (final matches in getAllMatchesStream(
        userEmail,
        tournamentId,
      )) {
        try {
          final teams = await getTeams(userEmail, tournamentId);

          final completedMatches = matches
              .where((m) => m.status == 'Completed')
              .toList();
          final scheduledMatches = matches
              .where((m) => m.status == 'scheduled')
              .toList();
          final ongoingMatches = matches
              .where((m) => m.status == 'ongoing')
              .toList();

          yield TournamentStatsSummary(
            totalMatches: matches.length,
            completedMatches: completedMatches.length,
            scheduledMatches: scheduledMatches.length,
            ongoingMatches: ongoingMatches.length,
            totalTeams: teams.length,
            playerStats: calculatePlayerStats(completedMatches, teams),
          );
        } catch (e) {
          debugPrint('❌ Error processing tournament stats stream: $e');
          debugPrint('   Stack trace: ${StackTrace.current}');
          // Yield empty stats instead of breaking the stream
          yield TournamentStatsSummary(
            totalMatches: 0,
            completedMatches: 0,
            scheduledMatches: 0,
            ongoingMatches: 0,
            totalTeams: 0,
            playerStats: {},
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Fatal error in tournament stats stream: $e');
      rethrow;
    }
  }

  /// Get matches by status
  Future<List<Match>> getMatchesByStatus(
    String userEmail,
    String tournamentId,
    String status,
  ) async {
    try {
      debugPrint('📥 Fetching $status matches');

      final matchesSnapshot = await _getUserTournamentsCollection(
        userEmail,
      ).doc(tournamentId).collection('matches').get();

      final matches = <Match>[];
      for (final doc in matchesSnapshot.docs) {
        try {
          final data = doc.data();
          final matchStatus = data['status'] ?? data['Status'] ?? '';

          if (matchStatus.toString().toLowerCase() == status.toLowerCase()) {
            matches.add(Match.fromMap(data));
          }
        } catch (e) {
          debugPrint('⚠️ Error parsing match ${doc.id}: $e');
        }
      }

      debugPrint('✅ Fetched ${matches.length} $status matches');
      return matches;
    } catch (e, stackTrace) {
      debugPrint('❌ Error fetching $status matches: $e');
      debugPrint('Stack: $stackTrace');
      rethrow;
    }
  }

  /// Get player-specific matches
  Future<List<Match>> getPlayerMatches(
    String userEmail,
    String tournamentId,
    String playerName,
  ) async {
    try {
      final allMatches = await getAllMatches(userEmail, tournamentId);

      // Filter matches where the player participated
      final playerMatches = allMatches.where((match) {
        final team1HasPlayer = match.team1.players.contains(playerName);
        final team2HasPlayer = match.team2.players.contains(playerName);
        return team1HasPlayer || team2HasPlayer;
      }).toList();

      debugPrint('✅ Found ${playerMatches.length} matches for $playerName');
      return playerMatches;
    } catch (e) {
      debugPrint('❌ Error fetching player matches: $e');
      rethrow;
    }
  }

  /// Get team-specific matches
  Future<List<Match>> getTeamMatches(
    String userEmail,
    String tournamentId,
    String teamId,
  ) async {
    try {
      final allMatches = await getAllMatches(userEmail, tournamentId);

      // Filter matches where the team participated (check parent team IDs)
      final teamMatches = allMatches.where((match) {
        return match.parentTeam1Id == teamId || match.parentTeam2Id == teamId;
      }).toList();

      debugPrint('✅ Found ${teamMatches.length} matches for team $teamId');
      return teamMatches;
    } catch (e) {
      debugPrint('❌ Error fetching team matches: $e');
      rethrow;
    }
  }

  /// Get top performers
  List<PlayerStats> getTopPerformers(
    Map<String, PlayerStats> playerStats, {
    int limit = 5,
    String sortBy = 'winRate', // 'winRate', 'wins', 'matchesPlayed'
  }) {
    final players = playerStats.values.toList();

    switch (sortBy) {
      case 'wins':
        players.sort((a, b) => b.wins.compareTo(a.wins));
        break;
      case 'matchesPlayed':
        players.sort((a, b) => b.matchesPlayed.compareTo(a.matchesPlayed));
        break;
      case 'winRate':
      default:
        players.sort((a, b) {
          // Only consider players who have played at least 3 matches
          if (a.matchesPlayed < 3) return 1;
          if (b.matchesPlayed < 3) return -1;
          return b.winRate.compareTo(a.winRate);
        });
    }

    return players.take(limit).toList();
  }
}

// Model for tournament statistics summary
class TournamentStatsSummary {
  final int totalMatches;
  final int completedMatches;
  final int scheduledMatches;
  final int ongoingMatches;
  final int totalTeams;
  final Map<String, PlayerStats> playerStats;

  TournamentStatsSummary({
    required this.totalMatches,
    required this.completedMatches,
    required this.scheduledMatches,
    required this.ongoingMatches,
    required this.totalTeams,
    required this.playerStats,
  });

  double get completionPercentage =>
      totalMatches > 0 ? (completedMatches / totalMatches) * 100 : 0.0;
}

// Extension methods for easy access
extension MatchListExtensions on List<Match> {
  List<Match> get completed => where((m) => m.status == 'Completed').toList();
  List<Match> get scheduled => where((m) => m.status == 'scheduled').toList();
  List<Match> get ongoing => where((m) => m.status == 'ongoing').toList();

  List<Match> forPlayer(String playerName) {
    return where((match) {
      return match.team1.players.contains(playerName) ||
          match.team2.players.contains(playerName);
    }).toList();
  }

  List<Match> forTeam(String teamId) {
    return where((match) {
      return match.parentTeam1Id == teamId || match.parentTeam2Id == teamId;
    }).toList();
  }
}

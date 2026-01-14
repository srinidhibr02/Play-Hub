import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:play_hub/constants/badminton.dart';
import 'package:play_hub/screens/tournament/badminton/scorecard.dart';

// ============= MATCH GENERATION LOGIC =============
// CORRECTED MATCH GENERATION LOGIC FOR ROUND ROBIN

class MatchGenerator {
  final List<Team> teams;
  final int totalMatches;
  final bool allowRematches;
  final int rematches;
  final DateTime startDate;
  final TimeOfDay startTime;
  final int matchDuration;
  final int breakDuration;
  final String tournamentFormat;

  MatchGenerator({
    required this.teams,
    required this.totalMatches,
    required this.allowRematches,
    required this.rematches,
    required this.startDate,
    required this.startTime,
    required this.matchDuration,
    required this.breakDuration,
    required this.tournamentFormat,
  });

  List<Match> generate() {
    if (teams.length < 2) return [];

    if (tournamentFormat == 'knockout') {
      return _generateKnockout();
    } else {
      return _generateRoundRobin();
    }
  }

  /// Calculate total matches that should be generated
  /// Formula: C(n, 2) * rematchCount
  /// where n = number of teams, C(n,2) = n * (n-1) / 2
  int _calculateTotalRoundRobinMatches() {
    final teamCount = teams.length;

    // Unique matchups between all teams: C(n, 2) = n * (n-1) / 2
    final uniqueMatchups = (teamCount * (teamCount - 1)) ~/ 2;

    // If rematches are allowed, multiply by rematch value
    // rematchValue represents how many times each unique matchup occurs
    final matchesPerMatchup = allowRematches ? rematches : 1;

    return uniqueMatchups * matchesPerMatchup;
  }

  List<Match> _generateRoundRobin() {
    debugPrint('🔄 ROUND ROBIN GENERATION');
    debugPrint('Teams: ${teams.length}');
    debugPrint('Allow Rematches: $allowRematches');
    debugPrint('Rematch Value: $rematches');

    final totalCalculatedMatches = _calculateTotalRoundRobinMatches();
    debugPrint('Calculated Total Matches: $totalCalculatedMatches');
    debugPrint('User Requested Matches: $totalMatches');

    final matches = <Match>[];
    var currentTime = _getStartDateTime();

    // Generate all unique matchups
    final allMatchups = <List<Team>>[];
    for (int i = 0; i < teams.length; i++) {
      for (int j = i + 1; j < teams.length; j++) {
        allMatchups.add([teams[i], teams[j]]);
      }
    }

    debugPrint('Total Unique Matchups: ${allMatchups.length}');

    // Track how many times each matchup has occurred
    final matchupCount = <String, int>{};
    for (final matchup in allMatchups) {
      final key = '${matchup[0].id}_${matchup[1].id}';
      matchupCount[key] = 0;
    }

    int generated = 0;
    final maxMatchesPerMatchup = allowRematches ? rematches : 1;

    // Generate matches round by round
    // In each round, try to generate one match from each unique matchup
    while (generated < totalMatches && generated < totalCalculatedMatches) {
      for (final matchup in allMatchups) {
        if (generated >= totalMatches) break;

        final team1 = matchup[0];
        final team2 = matchup[1];
        final key = '${team1.id}_${team2.id}';

        // Check if this matchup can be repeated more times
        if ((matchupCount[key] ?? 0) < maxMatchesPerMatchup) {
          matches.add(
            Match(
              id: 'M${matches.length + 1}',
              team1: team1,
              team2: team2,
              date: currentTime,
              time: DateFormat('h:mm a').format(currentTime),
              status: 'Scheduled',
              score1: 0,
              score2: 0,
              winner: null,
              roundName: 'Match ${matches.length + 1}',
              stage: 'League',
              rematchNumber: (matchupCount[key] ?? 0) + 1,
            ),
          );

          matchupCount[key] = (matchupCount[key] ?? 0) + 1;
          generated++;

          currentTime = currentTime.add(
            Duration(minutes: matchDuration + breakDuration),
          );
        }
      }
    }

    debugPrint('✅ Generated $generated matches');
    return matches;
  }

  List<Match> _generateKnockout() {
    final matches = <Match>[];
    final shuffledTeams = List<Team>.from(teams)..shuffle();
    var currentTime = _getStartDateTime();

    for (int i = 0; i < totalMatches && shuffledTeams.isNotEmpty; i++) {
      if (shuffledTeams.length < 2) break;

      final team1 = shuffledTeams.removeAt(0);
      final team2 = shuffledTeams.removeAt(0);

      matches.add(
        Match(
          id: 'M${matches.length + 1}',
          team1: team1,
          team2: team2,
          date: currentTime,
          time: DateFormat('h:mm a').format(currentTime),
          status: 'Scheduled',
          score1: 0,
          score2: 0,
          winner: null,
          round: (i ~/ 2) + 1,
          roundName: _getKnockoutRoundName(matches.length + 1),
          stage: 'Knockout',
        ),
      );

      currentTime = currentTime.add(
        Duration(minutes: matchDuration + breakDuration),
      );
    }

    debugPrint('✅ Generated ${matches.length} knockout matches');
    return matches;
  }

  String _getKnockoutRoundName(int matchNumber) {
    final teamsCount = teams.length;
    final roundMatches = _calculateRoundMatches(teamsCount);

    int cumulative = 0;
    for (int i = 0; i < roundMatches.length; i++) {
      cumulative += roundMatches[i];
      if (matchNumber <= cumulative) {
        return _roundNameFromMatches(roundMatches[i]);
      }
    }
    return 'Round of ${roundMatches.last * 2}';
  }

  String _roundNameFromMatches(int matchesInRound) {
    if (matchesInRound == 1) return 'Final';
    if (matchesInRound == 2) return 'Semi-Final';
    if (matchesInRound <= 4) return 'Quarter-Final';
    if (matchesInRound <= 8) return 'Round of 16';
    return 'Round of ${matchesInRound * 2}';
  }

  List<int> _calculateRoundMatches(int teamCount) {
    final rounds = <int>[];
    int remaining = teamCount;
    while (remaining > 1) {
      final matches = (remaining + 1) ~/ 2;
      rounds.add(matches);
      remaining = matches;
    }
    return rounds;
  }

  DateTime _getStartDateTime() {
    return DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
      startTime.hour,
      startTime.minute,
    );
  }
}

class PlayoffGenerator {
  final List<Team> topTeams;
  final DateTime startDate;
  final TimeOfDay startTime;
  final int matchDuration;
  final int breakDuration;
  final PlayoffFormat format;

  PlayoffGenerator({
    required this.topTeams,
    required this.startDate,
    required this.startTime,
    required this.matchDuration,
    required this.breakDuration,
    required this.format,
  });

  List<Match> generate() {
    return switch (format) {
      PlayoffFormat.directFinal => _generateDirectFinal(),
      PlayoffFormat.semisAndFinal => _generateSemisAndFinal(),
    };
  }

  List<Match> _generateDirectFinal() {
    final matches = <Match>[];
    var currentTime = _getStartDateTime();

    if (topTeams.length >= 2) {
      matches.add(
        Match(
          id: 'P1',
          team1: topTeams[0],
          team2: topTeams[1],
          date: currentTime,
          time: DateFormat('h:mm a').format(currentTime),
          status: 'Scheduled',
          score1: 0,
          score2: 0,
          winner: null,
          round: 1,
          roundName: 'Final',
          stage: 'Playoff',
        ),
      );
    }

    return matches;
  }

  List<Match> _generateSemisAndFinal() {
    final matches = <Match>[];
    var currentTime = _getStartDateTime();
    int matchCounter = 1;

    // Semi-Final 1: 1st vs 4th
    if (topTeams.length >= 4) {
      matches.add(
        Match(
          id: 'P$matchCounter',
          team1: topTeams[0],
          team2: topTeams[3],
          date: currentTime,
          time: DateFormat('h:mm a').format(currentTime),
          status: 'Scheduled',
          score1: 0,
          score2: 0,
          winner: null,
          round: 1,
          roundName: 'Semi-Final 1',
          stage: 'Playoff',
          parentTeam1Id: topTeams[0].id,
          parentTeam2Id: topTeams[3].id,
        ),
      );

      matchCounter++;
      currentTime = currentTime.add(
        Duration(minutes: matchDuration + breakDuration),
      );

      // Semi-Final 2: 2nd vs 3rd
      matches.add(
        Match(
          id: 'P$matchCounter',
          team1: topTeams[1],
          team2: topTeams[2],
          date: currentTime,
          time: DateFormat('h:mm a').format(currentTime),
          status: 'Scheduled',
          score1: 0,
          score2: 0,
          winner: null,
          round: 1,
          roundName: 'Semi-Final 2',
          stage: 'Playoff',
          parentTeam1Id: topTeams[1].id,
          parentTeam2Id: topTeams[2].id,
        ),
      );

      matchCounter++;
      currentTime = currentTime.add(
        Duration(minutes: matchDuration + breakDuration),
      );

      // Final (placeholder - winners determined after semis)
      matches.add(
        Match(
          id: 'P$matchCounter',
          team1: topTeams[0],
          team2: topTeams[1],
          date: currentTime,
          time: DateFormat('h:mm a').format(currentTime),
          status: 'Pending',
          score1: 0,
          score2: 0,
          winner: null,
          round: 2,
          roundName: 'Final',
          stage: 'Playoff',
        ),
      );
    }

    return matches;
  }

  DateTime _getStartDateTime() {
    return DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
      startTime.hour,
      startTime.minute,
    );
  }
}

enum PlayoffFormat { directFinal, semisAndFinal }

// ============= UI WIDGETS =============

class MatchesListView extends StatelessWidget {
  final List<Match> matches;
  final Function(Match)? onScoreUpdate; // ✅ Add this callback
  final Function(Match) onMatchTap;

  const MatchesListView({
    super.key,
    required this.matches,
    required this.onScoreUpdate,
    required this.onMatchTap,
  });

  @override
  Widget build(BuildContext context) {
    final leagueMatches = matches
        .where((m) => m.stage == 'League' || m.stage == null)
        .toList();
    final playoffMatches = matches.where((m) => m.stage == 'Playoff').toList();
    final knockoutMatches = matches
        .where((m) => m.stage == 'Knockout')
        .toList();

    int leagueCompletedCount = leagueMatches
        .where((m) => m.status == 'Completed')
        .length;
    int leagueTotalCount = leagueMatches.length;

    int playoffCompletedCount = playoffMatches
        .where((m) => m.status == 'Completed')
        .length;
    int playoffTotalCount = playoffMatches.length;

    int knockoutCompletedCount = knockoutMatches
        .where((m) => m.status == 'Completed')
        .length;
    int knockoutTotalCount = knockoutMatches.length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (leagueMatches.isNotEmpty) ...[
          _buildSectionHeader(
            icon: Icons.sports_tennis,
            title: 'League Stage',
            color: Colors.blue,
            completedMatches: leagueCompletedCount,
            totalMatches: leagueTotalCount,
          ),
          ...leagueMatches
              .map((match) => _buildMatchCard(match, isLeague: true))
              .toList(),
          const SizedBox(height: 24),
        ],
        if (playoffMatches.isNotEmpty) ...[
          _buildSectionHeader(
            icon: Icons.emoji_events,
            title: 'Playoff Stage',
            color: Colors.amber,
            completedMatches: playoffCompletedCount,
            totalMatches: playoffTotalCount,
          ),
          ...playoffMatches
              .map((match) => _buildMatchCard(match, isLeague: false))
              .toList(),
          const SizedBox(height: 24),
        ],
        if (knockoutMatches.isNotEmpty) ...[
          _buildSectionHeader(
            icon: Icons.military_tech,
            title: 'Knockout Stage',
            color: Colors.red,
            completedMatches: knockoutCompletedCount,
            totalMatches: knockoutTotalCount,
          ),
          ...knockoutMatches
              .map((match) => _buildMatchCard(match, isLeague: false))
              .toList(),
        ],
      ],
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required Color color,
    required int completedMatches,
    required int totalMatches,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  '$completedMatches / $totalMatches matches completed',
                  style: TextStyle(fontSize: 12, color: color.withOpacity(0.7)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${((completedMatches / totalMatches) * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchCard(Match match, {required bool isLeague}) {
    final color = isLeague ? Colors.blue : Colors.amber;

    return Builder(
      builder: (BuildContext context) {
        // ✅ Proper syntax with {}
        return GestureDetector(
          // ✅ GestureDetector inside builder
          onTap: () =>
              _openScorecard(match, context), // ✅ Context now available
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.shade300, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Header with round name and status
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.shade600, color.shade400],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(14),
                      topRight: Radius.circular(14),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (match.roundName != null)
                            Text(
                              match.roundName!,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          Text(
                            match.id,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(match.status),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          match.status,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Match details
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Team 1
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  match.team1.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (match.team1.players.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    match.team1.players.join(' & '),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Text(
                            '${match.score1}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: color.shade600,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Team 2
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  match.team2.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (match.team2.players.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    match.team2.players.join(' & '),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Text(
                            '${match.score2}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: color.shade600,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 12),

                      // Date and time
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            DateFormat('MMM dd, yyyy').format(match.date),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            match.time,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openScorecard(Match match, BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScorecardScreen(
          match: match,
          onScoreUpdate: (updatedMatch) {
            onScoreUpdate?.call(updatedMatch); // ✅ Safe call to parent callback
          },
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Scheduled':
        return Colors.blue;
      case 'Ongoing':
        return Colors.orange;
      case 'Completed':
        return Colors.green;
      case 'Pending':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }
}

class MatchCard extends StatelessWidget {
  final Match match;
  final VoidCallback onTap;
  final bool isLeague;

  const MatchCard({
    super.key,
    required this.match,
    required this.onTap,
    required this.isLeague,
  });

  @override
  Widget build(BuildContext context) {
    final color = isLeague ? Colors.blue : Colors.amber;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.shade300, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.shade600, color.shade400],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (match.roundName != null)
                        Text(
                          match.roundName!,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      Text(
                        match.id,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                  _buildStatusBadge(match.status),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildTeamRow(match.team1, match.score1, color),
                  const SizedBox(height: 16),
                  _buildTeamRow(match.team2, match.score2, color),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  _buildMatchInfo(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamRow(Team team, int score, Color color) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                team.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (team.players.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  team.players.join(' & '),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        Text(
          '$score',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    final statusColor = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildMatchInfo() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Text(
          DateFormat('MMM dd, yyyy').format(match.date),
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
        const SizedBox(width: 16),
        Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Text(
          match.time,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    return switch (status) {
      'Scheduled' => Colors.blue,
      'Ongoing' => Colors.orange,
      'Completed' => Colors.green,
      'Pending' => Colors.grey,
      _ => Colors.grey,
    };
  }
}

class ReorderableMatchList extends StatelessWidget {
  final List<Match> matches;
  final Function(int, int) onReorder;

  const ReorderableMatchList({required this.matches, required this.onReorder});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.amber.shade50,
          child: Row(
            children: [
              Icon(Icons.drag_indicator, color: Colors.amber.shade700),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reorder Mode',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade800,
                    ),
                  ),
                  Text(
                    'Drag to change match order',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.amber.shade700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ReorderableListView(
            onReorder: onReorder,
            padding: const EdgeInsets.all(16),
            children: matches.asMap().entries.map((e) {
              return DraggableMatchCard(
                key: ValueKey('match_${e.value.id}_${e.key}'),
                match: e.value,
                index: e.key,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class DraggableMatchCard extends StatelessWidget {
  final Match match;
  final int index;

  const DraggableMatchCard({
    required Key key,
    required this.match,
    required this.index,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.shade300, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.amber.shade600, Colors.amber.shade400],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.grab,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: const Icon(
                        Icons.drag_indicator,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Match ${index + 1}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${match.team1.name} vs ${match.team2.name}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Pos ${index + 1}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${match.team1.players[0]} & ${match.team1.players[1]}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'vs',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${match.team2.players[0]} & ${match.team2.players[1]}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyMatchesWidget extends StatelessWidget {
  const EmptyMatchesWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.sports_baseball_outlined,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No matches scheduled yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

class ErrorStateWidget extends StatelessWidget {
  final Object? error;
  final VoidCallback onRetry;

  const ErrorStateWidget({
    super.key,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Error: $error',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red.shade600),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class TournamentMenuButton extends StatelessWidget {
  final VoidCallback onShare;
  final VoidCallback onInfo;

  const TournamentMenuButton({
    super.key,
    required this.onShare,
    required this.onInfo,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.white),
      onSelected: (value) {
        if (value == 'share') onShare();
        if (value == 'info') onInfo();
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'share',
          child: ListTile(leading: Icon(Icons.share), title: Text('Share')),
        ),
        PopupMenuItem(
          value: 'info',
          child: ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Tournament info'),
          ),
        ),
      ],
    );
  }
}

class CustomMatchGenerator {
  final List<Team> teams;
  final int totalMatches;
  final bool allowRematches;
  final int rematches;
  final DateTime startDate;
  final TimeOfDay startTime;
  final int matchDuration;
  final int breakDuration;
  final String tournamentFormat;

  CustomMatchGenerator({
    required this.teams,
    required this.totalMatches,
    required this.allowRematches,
    required this.rematches,
    required this.startDate,
    required this.startTime,
    required this.matchDuration,
    required this.breakDuration,
    required this.tournamentFormat,
  });

  List<Match> generate() {
    if (teams.length < 2) return [];

    debugPrint(
      '🔄 Custom Tournament: ${teams.length} teams, $totalMatches matches',
    );

    final matches = <Match>[];
    var currentTime = _getStartDateTime();

    // Generate ALL possible matchups between teams
    final allMatchups = _generateAllMatchups();
    debugPrint('📊 Total possible matchups: ${allMatchups.length}');

    // Select matches fairly if totalMatches < allMatchups.length
    final selectedMatchups = _selectMatchupsFairly(allMatchups);
    debugPrint('📊 Selected matchups: ${selectedMatchups.length}');

    int generated = 0;

    for (final matchup in selectedMatchups) {
      final parentTeam1 = matchup['parentTeam1'] as Team;
      final parentTeam2 = matchup['parentTeam2'] as Team;
      final team1Pair = matchup['team1Pair'] as List<String>;
      final team2Pair = matchup['team2Pair'] as List<String>;

      // Create playing pair teams with correct parent references
      final playingTeam1 = Team(
        id: '${parentTeam1.id}_p${team1Pair.join('')}',
        name: '${parentTeam1.name} (${team1Pair[0]}+${team1Pair[1]})',
        players: team1Pair,
      );

      final playingTeam2 = Team(
        id: '${parentTeam2.id}_p${team2Pair.join('')}',
        name: '${parentTeam2.name} (${team2Pair[0]}+${team2Pair[1]})',
        players: team2Pair,
      );

      final newMatch = Match(
        id: 'M${generated + 1}',
        team1: playingTeam1,
        team2: playingTeam2,
        date: currentTime,
        time: DateFormat('HH:mm').format(currentTime),
        status: 'scheduled',
        score1: 0,
        score2: 0,
        winner: null,
        parentTeam1Id: parentTeam1.id,
        parentTeam2Id: parentTeam2.id,
        round: (generated ~/ 6) + 1,
        roundName: 'League Stage',
        stage: 'league',
        rematchNumber: (generated ~/ allMatchups.length) + 1,
      );

      matches.add(newMatch);
      generated++;

      debugPrint(
        '✅ Match #$generated: ${parentTeam1.name} (${team1Pair.join("+")}) vs ${parentTeam2.name} (${team2Pair.join("+")})',
      );

      currentTime = currentTime.add(
        Duration(minutes: matchDuration + breakDuration),
      );
    }

    // Print player statistics
    _printPlayerStats(matches);

    debugPrint('🎉 GENERATED ${matches.length} matches with fair distribution');
    return matches;
  }

  List<Map<String, dynamic>> _selectMatchupsFairly(
    List<Map<String, dynamic>> allMatchups,
  ) {
    if (totalMatches >= allMatchups.length) {
      return allMatchups;
    }

    // Track how many times each player plays
    final playerMatchCount = <String, int>{};

    // Initialize all players with 0 matches
    for (final team in teams) {
      for (final player in team.players) {
        playerMatchCount[player] = 0;
      }
    }

    final selectedMatchups = <Map<String, dynamic>>[];
    final availableMatchups = List<Map<String, dynamic>>.from(allMatchups);

    // Shuffle to randomize selection order (ensures variety)
    availableMatchups.shuffle();

    // Greedy algorithm: Select matches that balance player participation
    while (selectedMatchups.length < totalMatches &&
        availableMatchups.isNotEmpty) {
      // Sort available matchups by total play count of involved players
      // (prefer matchups with players who have played less)
      availableMatchups.sort((a, b) {
        final aPair1 = a['team1Pair'] as List<String>;
        final aPair2 = a['team2Pair'] as List<String>;
        final bPair1 = b['team1Pair'] as List<String>;
        final bPair2 = b['team2Pair'] as List<String>;

        final aTotal =
            (playerMatchCount[aPair1[0]] ?? 0) +
            (playerMatchCount[aPair1[1]] ?? 0) +
            (playerMatchCount[aPair2[0]] ?? 0) +
            (playerMatchCount[aPair2[1]] ?? 0);

        final bTotal =
            (playerMatchCount[bPair1[0]] ?? 0) +
            (playerMatchCount[bPair1[1]] ?? 0) +
            (playerMatchCount[bPair2[0]] ?? 0) +
            (playerMatchCount[bPair2[1]] ?? 0);

        return aTotal.compareTo(bTotal);
      });

      // Select the matchup with least-played players
      final selected = availableMatchups.removeAt(0);
      selectedMatchups.add(selected);

      // Update player counts
      final pair1 = selected['team1Pair'] as List<String>;
      final pair2 = selected['team2Pair'] as List<String>;

      playerMatchCount[pair1[0]] = (playerMatchCount[pair1[0]] ?? 0) + 1;
      playerMatchCount[pair1[1]] = (playerMatchCount[pair1[1]] ?? 0) + 1;
      playerMatchCount[pair2[0]] = (playerMatchCount[pair2[0]] ?? 0) + 1;
      playerMatchCount[pair2[1]] = (playerMatchCount[pair2[1]] ?? 0) + 1;
    }

    debugPrint('📊 Player participation after fair selection:');
    playerMatchCount.forEach((player, count) {
      debugPrint('   $player: $count matches');
    });

    return selectedMatchups;
  }

  void _printPlayerStats(List<Match> matches) {
    final playerStats = <String, int>{};

    for (final match in matches) {
      for (final player in match.team1.players) {
        playerStats[player] = (playerStats[player] ?? 0) + 1;
      }
      for (final player in match.team2.players) {
        playerStats[player] = (playerStats[player] ?? 0) + 1;
      }
    }

    debugPrint('');
    debugPrint('📊 FINAL PLAYER STATISTICS:');
    debugPrint('─' * 40);

    final sortedPlayers = playerStats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (final entry in sortedPlayers) {
      debugPrint('   ${entry.key.padRight(15)}: ${entry.value} matches');
    }

    final maxMatches = sortedPlayers.first.value;
    final minMatches = sortedPlayers.last.value;
    final difference = maxMatches - minMatches;

    debugPrint('─' * 40);
    debugPrint('   Max: $maxMatches | Min: $minMatches | Diff: $difference');
    debugPrint('');
  }

  List<Map<String, dynamic>> _generateAllMatchups() {
    final matchups = <Map<String, dynamic>>[];

    for (int i = 0; i < teams.length; i++) {
      for (int j = i + 1; j < teams.length; j++) {
        final team1 = teams[i];
        final team2 = teams[j];

        final team1Pairs = _generatePairs(team1.players);
        final team2Pairs = _generatePairs(team2.players);

        debugPrint('${team1.name} has ${team1Pairs.length} pairs');
        debugPrint('${team2.name} has ${team2Pairs.length} pairs');

        for (final pair1 in team1Pairs) {
          for (final pair2 in team2Pairs) {
            matchups.add({
              'parentTeam1': team1,
              'parentTeam2': team2,
              'team1Pair': pair1,
              'team2Pair': pair2,
            });
          }
        }
      }
    }

    debugPrint('Total unique matchups (without rematches): ${matchups.length}');

    if (allowRematches && rematches > 1) {
      final baseMatchups = List<Map<String, dynamic>>.from(matchups);
      matchups.clear();

      for (int r = 0; r < rematches; r++) {
        matchups.addAll(baseMatchups);
      }

      debugPrint('With $rematches rematches: ${matchups.length} total matches');
    }

    return matchups;
  }

  List<List<String>> _generatePairs(List<String> players) {
    final pairs = <List<String>>[];
    for (int i = 0; i < players.length; i++) {
      for (int j = i + 1; j < players.length; j++) {
        pairs.add([players[i], players[j]]);
      }
    }
    return pairs;
  }

  DateTime _getStartDateTime() {
    return DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
      startTime.hour,
      startTime.minute,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:play_hub/constants/badminton.dart';

// ============= MATCH GENERATION LOGIC =============
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

    return tournamentFormat == 'knockout'
        ? _generateKnockout()
        : _generateRoundRobin();
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

    return matches;
  }

  List<Match> _generateRoundRobin() {
    final matches = <Match>[];
    var currentTime = _getStartDateTime();
    final matchupCount = <String, int>{};
    final recentOpponents = <String, Set<String>>{};
    final lastMatchTime = <String, DateTime>{};

    // Initialize
    for (final team in teams) {
      recentOpponents[team.id] = <String>{};
    }

    // Generate all matchups
    final allMatchups = <List<Team>>[];
    for (int i = 0; i < teams.length; i++) {
      for (int j = i + 1; j < teams.length; j++) {
        final key = '${teams[i].id}_${teams[j].id}';
        matchupCount[key] = 0;
        allMatchups.add([teams[i], teams[j]]);
      }
    }

    int generated = 0;
    final maxMatchesPerMatchup = allowRematches ? rematches : 1;

    while (generated < totalMatches) {
      final matchup = _findBestMatchup(
        allMatchups,
        matchupCount,
        maxMatchesPerMatchup,
        recentOpponents,
        lastMatchTime,
        currentTime,
      );

      if (matchup.isEmpty) break;

      final team1 = matchup[0];
      final team2 = matchup[1];
      final key = '${team1.id}_${team2.id}';

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
      recentOpponents[team1.id]!.add(team2.id);
      recentOpponents[team2.id]!.add(team1.id);
      lastMatchTime[team1.id] = currentTime;
      lastMatchTime[team2.id] = currentTime;
      generated++;

      currentTime = currentTime.add(
        Duration(minutes: matchDuration + breakDuration),
      );
    }

    return matches;
  }

  List<Team> _findBestMatchup(
    List<List<Team>> allMatchups,
    Map<String, int> matchupCount,
    int maxPerMatchup,
    Map<String, Set<String>> recentOpponents,
    Map<String, DateTime> lastMatchTime,
    DateTime currentTime,
  ) {
    for (final matchup in allMatchups) {
      final team1 = matchup[0];
      final team2 = matchup[1];
      final key = '${team1.id}_${team2.id}';

      if ((matchupCount[key] ?? 0) >= maxPerMatchup) continue;
      if (recentOpponents[team1.id]!.contains(team2.id)) continue;

      final team1Last = lastMatchTime[team1.id] ?? DateTime(1970);
      final team2Last = lastMatchTime[team2.id] ?? DateTime(1970);
      if (currentTime.isBefore(team1Last.add(Duration(minutes: 15)))) continue;
      if (currentTime.isBefore(team2Last.add(Duration(minutes: 15)))) continue;

      return matchup;
    }
    return [];
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

// ============= UI WIDGETS =============

class MatchesListView extends StatelessWidget {
  final List<Match> matches;
  final Function(Match) onMatchTap;

  const MatchesListView({required this.matches, required this.onMatchTap});

  @override
  Widget build(BuildContext context) {
    final leagueMatches = matches
        .where((m) => m.stage == 'League' || m.stage == null)
        .toList();
    final playoffMatches = matches.where((m) => m.stage == 'Playoff').toList();
    final knockoutMatches = matches
        .where((m) => m.stage == 'Knockout')
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (leagueMatches.isNotEmpty) ...[
          _buildSectionHeader(
            icon: Icons.sports_tennis,
            title: 'League Stage',
            color: Colors.blue,
            count: leagueMatches.length,
          ),
          ...leagueMatches.map(
            (m) =>
                MatchCard(match: m, onTap: () => onMatchTap(m), isLeague: true),
          ),
          const SizedBox(height: 24),
        ],
        if (playoffMatches.isNotEmpty) ...[
          _buildSectionHeader(
            icon: Icons.emoji_events,
            title: 'Playoff Stage',
            color: Colors.amber,
            count: playoffMatches.length,
          ),
          ...playoffMatches.map(
            (m) => MatchCard(
              match: m,
              onTap: () => onMatchTap(m),
              isLeague: false,
            ),
          ),
          const SizedBox(height: 24),
        ],
        if (knockoutMatches.isNotEmpty) ...[
          _buildSectionHeader(
            icon: Icons.military_tech,
            title: 'Knockout Stage',
            color: Colors.red,
            count: knockoutMatches.length,
          ),
          ...knockoutMatches.map(
            (m) => MatchCard(
              match: m,
              onTap: () => onMatchTap(m),
              isLeague: false,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required Color color,
    required int count,
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
                  '$count matches',
                  style: TextStyle(fontSize: 12, color: color.withOpacity(0.7)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              count.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MatchCard extends StatelessWidget {
  final Match match;
  final VoidCallback onTap;
  final bool isLeague;

  const MatchCard({
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
  const EmptyMatchesWidget();

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

  const ErrorStateWidget({required this.error, required this.onRetry});

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

  const TournamentMenuButton({required this.onShare, required this.onInfo});

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

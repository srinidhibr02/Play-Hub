import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:play_hub/constants/badminton.dart';
import 'package:play_hub/screens/tournament/badminton/scorecard.dart';

class BadmintonMatchScheduleScreen extends StatefulWidget {
  final List<Team> teams;
  final String teamType;
  final int matchesPerTeam;
  final DateTime startDate;
  final TimeOfDay startTime;
  final int matchDuration;
  final int breakDuration;
  final bool allowRematches;
  final int?
  customTeamSize; // NEW: Track custom team size for doubles generation

  const BadmintonMatchScheduleScreen({
    super.key,
    required this.teams,
    required this.teamType,
    required this.matchesPerTeam,
    required this.startDate,
    required this.startTime,
    required this.matchDuration,
    required this.breakDuration,
    required this.allowRematches,
    this.customTeamSize,
  });

  @override
  State<BadmintonMatchScheduleScreen> createState() =>
      _BadmintonMatchScheduleScreenState();
}

class _BadmintonMatchScheduleScreenState
    extends State<BadmintonMatchScheduleScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late List<Match> matches;
  late List<TeamStats> teamStats;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _generateMatches();
    _initializeTeamStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _generateMatches() {
    matches = [];
    if (widget.teams.length < 2) return;

    DateTime currentMatchTime = DateTime(
      widget.startDate.year,
      widget.startDate.month,
      widget.startDate.day,
      widget.startTime.hour,
      widget.startTime.minute,
    );

    // Check if this is a custom doubles-within-teams tournament
    final isCustomDoublesFormat =
        widget.teamType != 'Singles' &&
        widget.teamType != 'Doubles' &&
        widget.customTeamSize != null &&
        widget.customTeamSize! >= 2;

    if (isCustomDoublesFormat) {
      // Generate matches for custom doubles-within-teams format
      _generateCustomDoublesMatches(currentMatchTime);
    } else {
      // Generate matches for standard Singles/Doubles format
      _generateStandardMatches(currentMatchTime);
    }
  }

  void _generateStandardMatches(DateTime currentMatchTime) {
    // Generate all unique team pairs (combinations)
    List<MatchPair> pairs = [];
    for (int i = 0; i < widget.teams.length; i++) {
      for (int j = i + 1; j < widget.teams.length; j++) {
        pairs.add(MatchPair(widget.teams[i], widget.teams[j]));
      }
    }

    // Create match schedule based on rematches setting
    List<MatchPair> schedule = [];

    if (widget.allowRematches) {
      // Calculate how many times each pair should play
      int totalMatchesNeeded =
          (widget.teams.length * widget.matchesPerTeam) ~/ 2;
      int timesPerPair = (totalMatchesNeeded / pairs.length).ceil();

      for (int repeat = 0; repeat < timesPerPair; repeat++) {
        schedule.addAll(pairs);
        if (schedule.length >= totalMatchesNeeded) break;
      }

      // Trim to exact number needed
      if (schedule.length > totalMatchesNeeded) {
        schedule = schedule.sublist(0, totalMatchesNeeded);
      }
    } else {
      // Round-robin: each pair plays only once
      schedule = pairs;
    }

    // Shuffle to randomize schedule order
    schedule.shuffle();

    // Schedule all matches
    for (var matchPair in schedule) {
      matches.add(
        Match(
          id: 'M${matches.length + 1}',
          team1: matchPair.team1,
          team2: matchPair.team2,
          date: currentMatchTime,
          time: _formatTime(currentMatchTime),
          status: 'Scheduled',
          score1: 0,
          score2: 0,
          winner: null,
        ),
      );

      currentMatchTime = currentMatchTime.add(
        Duration(minutes: widget.matchDuration + widget.breakDuration),
      );
    }
  }

  void _generateCustomDoublesMatches(DateTime currentMatchTime) {
    // Generate all possible doubles pairs for each team
    List<TeamWithDoublesPairs> teamsWithPairs = [];

    for (var team in widget.teams) {
      List<DoublesPair> doublesPairs = _generateDoublesPairs(team);
      teamsWithPairs.add(TeamWithDoublesPairs(team, doublesPairs));
    }

    // Generate matches between all team combinations
    List<DoublesMatch> allMatches = [];

    for (int i = 0; i < teamsWithPairs.length; i++) {
      for (int j = i + 1; j < teamsWithPairs.length; j++) {
        // Each doubles pair from team i plays each doubles pair from team j
        for (var pair1 in teamsWithPairs[i].doublesPairs) {
          for (var pair2 in teamsWithPairs[j].doublesPairs) {
            allMatches.add(
              DoublesMatch(
                teamsWithPairs[i].team,
                teamsWithPairs[j].team,
                pair1,
                pair2,
              ),
            );
          }
        }
      }
    }

    // Apply rematches if enabled
    List<DoublesMatch> schedule = [];
    if (widget.allowRematches) {
      for (int repeat = 0; repeat < widget.matchesPerTeam; repeat++) {
        schedule.addAll(allMatches);
      }
    } else {
      schedule = allMatches;
    }

    // Shuffle to randomize
    schedule.shuffle();

    // Create Match objects
    for (var doublesMatch in schedule) {
      // Create virtual teams for the doubles pairs
      Team pair1Team = Team(
        id: '${doublesMatch.team1.id}_${doublesMatch.pair1.player1}_${doublesMatch.pair1.player2}',
        name:
            '${doublesMatch.team1.name}: ${doublesMatch.pair1.player1} & ${doublesMatch.pair1.player2}',
        players: [doublesMatch.pair1.player1, doublesMatch.pair1.player2],
      );

      Team pair2Team = Team(
        id: '${doublesMatch.team2.id}_${doublesMatch.pair2.player1}_${doublesMatch.pair2.player2}',
        name:
            '${doublesMatch.team2.name}: ${doublesMatch.pair2.player1} & ${doublesMatch.pair2.player2}',
        players: [doublesMatch.pair2.player1, doublesMatch.pair2.player2],
      );

      matches.add(
        Match(
          id: 'M${matches.length + 1}',
          team1: pair1Team,
          team2: pair2Team,
          date: currentMatchTime,
          time: _formatTime(currentMatchTime),
          status: 'Scheduled',
          score1: 0,
          score2: 0,
          winner: null,
          parentTeam1Id: doublesMatch.team1.id,
          parentTeam2Id: doublesMatch.team2.id,
        ),
      );

      currentMatchTime = currentMatchTime.add(
        Duration(minutes: widget.matchDuration + widget.breakDuration),
      );
    }
  }

  List<DoublesPair> _generateDoublesPairs(Team team) {
    List<DoublesPair> pairs = [];
    List<String> players = team.players;

    // Generate all combinations of 2 players from the team
    for (int i = 0; i < players.length; i++) {
      for (int j = i + 1; j < players.length; j++) {
        pairs.add(DoublesPair(players[i], players[j]));
      }
    }

    return pairs;
  }

  String _formatTime(DateTime dateTime) =>
      DateFormat('h:mm a').format(dateTime);

  void _initializeTeamStats() {
    teamStats = widget.teams
        .map(
          (team) => TeamStats(
            teamId: team.id,
            teamName: team.name,
            players: team.players,
            matchesPlayed: 0,
            won: 0,
            lost: 0,
            points: 0,
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.orange.shade600,
        elevation: 0,
        title: const Text(
          'Tournament Schedule',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            onPressed: _showTournamentInfo,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.orange.shade600,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
              ),
              labelColor: Colors.orange.shade600,
              unselectedLabelColor: Colors.white.withOpacity(0.7),
              labelStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.sports_tennis, size: 20),
                      SizedBox(width: 8),
                      Text('Matches'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.leaderboard, size: 20),
                      SizedBox(width: 8),
                      Text('Standings'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildMatchesTab(), _buildPointsTableTab()],
            ),
          ),
        ],
      ),
    );
  }

  void _showTournamentInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.info, color: Colors.orange.shade600),
            const SizedBox(width: 12),
            const Text('Tournament Info'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Format', widget.teamType),
            _buildInfoRow(
              widget.teamType == 'Singles' ? 'Total Players' : 'Total Teams',
              '${widget.teams.length}',
            ),
            if (widget.customTeamSize != null &&
                widget.customTeamSize! >= 2) ...[
              _buildInfoRow('Members per Team', '${widget.customTeamSize}'),
              _buildInfoRow(
                'Pairs per Team',
                '${_getPairsPerTeam(widget.customTeamSize!)}',
              ),
            ],
            _buildInfoRow('Total Matches', '${matches.length}'),
            _buildInfoRow(
              widget.teamType == 'Singles' ? 'Matches/Player' : 'Matches/Team',
              '${widget.matchesPerTeam}',
            ),
            _buildInfoRow('Match Duration', '${widget.matchDuration} min'),
            _buildInfoRow('Break Time', '${widget.breakDuration} min'),
            if (matches.isNotEmpty) ...[
              _buildInfoRow(
                'Start',
                DateFormat('MMM d, h:mm a').format(matches.first.date),
              ),
              _buildInfoRow(
                'End (Est.)',
                DateFormat('h:mm a').format(
                  matches.last.date.add(
                    Duration(minutes: widget.matchDuration),
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  int _getPairsPerTeam(int teamSize) {
    return (teamSize * (teamSize - 1)) ~/ 2;
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchesTab() {
    if (matches.isEmpty) {
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
              'No matches scheduled',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Not enough teams to create matches',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: matches.length,
      itemBuilder: (context, index) => _buildMatchCard(matches[index], index),
    );
  }

  Widget _buildMatchCard(Match match, int index) {
    final isUpcoming = match.date.isAfter(DateTime.now());
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ScorecardScreen(
              match: match,
              teamType: widget.teamType,
              onScoreUpdate: (updatedMatch) {
                setState(() {
                  matches[index] = updatedMatch as Match;
                  _updateTeamStats();
                });
              },
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUpcoming ? Colors.orange.shade200 : Colors.grey.shade200,
            width: 2,
          ),
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
                  colors: [Colors.orange.shade600, Colors.orange.shade400],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Match ${match.id}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
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
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: _buildTeamDisplay(match.team1, Colors.orange),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Column(
                          children: [
                            Text(
                              match.score1.toString(),
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade600,
                              ),
                            ),
                            const Text(
                              'VS',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              match.score2.toString(),
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: _buildTeamDisplay(match.team2, Colors.blue),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        DateFormat('MMM dd, yyyy').format(match.date),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        match.time,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
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
  }

  Widget _buildTeamDisplay(Team team, Color color) {
    return Column(
      children: [
        if (team.players.length == 1)
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color, color]),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.5),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                team.players[0][0].toUpperCase(),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 0; i < team.players.length && i < 2; i++)
                Padding(
                  padding: EdgeInsets.only(left: i > 0 ? 4 : 0),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [color, color]),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.5),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        team.players[i][0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 10),
        Text(
          team.name,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (team.players.length > 0)
          Text(
            team.players.join(' & '),
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }

  Widget _buildPointsTableTab() {
    if (teamStats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.leaderboard_outlined,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'No standings available',
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

    teamStats.sort((a, b) {
      int res = b.points.compareTo(a.points);
      if (res != 0) return res;
      res = b.won.compareTo(a.won);
      if (res != 0) return res;
      return a.matchesPlayed.compareTo(b.matchesPlayed);
    });

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange.shade600, Colors.orange.shade400],
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
          child: Row(
            children: [
              const SizedBox(
                width: 40,
                child: Text(
                  'Rank',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  widget.teamType == 'Singles' ? 'Player' : 'Team',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(
                width: 45,
                child: Text(
                  'Played',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(
                width: 40,
                child: Text(
                  'Won',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
              const SizedBox(
                width: 40,
                child: Text(
                  'Pts',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: teamStats.length,
            itemBuilder: (context, index) {
              final team = teamStats[index];
              final isTopRanked = index == 0;
              final isTopThree = index < 3 && teamStats.length >= 3;
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: isTopRanked
                      ? Colors.orange.shade50
                      : isTopThree
                      ? Colors.orange.shade100
                      : Colors.white,
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey.shade200,
                      width: index == teamStats.length - 1 ? 0 : 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 40,
                      child: Row(
                        children: [
                          if (isTopThree)
                            Icon(
                              index == 0
                                  ? Icons.emoji_events
                                  : index == 1
                                  ? Icons.workspace_premium
                                  : Icons.military_tech,
                              size: 20,
                              color: index == 0
                                  ? Colors.amber.shade700
                                  : index == 1
                                  ? Colors.grey
                                  : Colors.orange.shade800,
                            )
                          else
                            Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade700,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            team.teamName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isTopRanked
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              color: Colors.grey.shade800,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (team.players.length > 1)
                            Text(
                              team.players.join(', '),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 45,
                      child: Text(
                        team.matchesPlayed.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      child: Text(
                        team.won.toString(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade600,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      child: Text(
                        team.points.toString(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade600,
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
    );
  }

  void _updateTeamStats() {
    for (var stat in teamStats) {
      stat.matchesPlayed = 0;
      stat.won = 0;
      stat.lost = 0;
      stat.points = 0;
    }

    for (var match in matches) {
      if (match.status == 'Completed' && match.winner != null) {
        // For custom doubles format, use parent team IDs
        String? winnerTeamId;
        String? loserTeamId;

        if (match.parentTeam1Id != null && match.parentTeam2Id != null) {
          // Custom doubles format - use parent team IDs
          if (match.winner?.contains(match.parentTeam1Id!) == true) {
            winnerTeamId = match.parentTeam1Id;
            loserTeamId = match.parentTeam2Id;
          } else {
            winnerTeamId = match.parentTeam2Id;
            loserTeamId = match.parentTeam1Id;
          }
        } else {
          // Standard format
          winnerTeamId = match.winner;
          loserTeamId = match.winner == match.team1.id
              ? match.team2.id
              : match.team1.id;
        }

        // Update winner stats
        final winnerIndex = teamStats.indexWhere(
          (t) => t.teamId == winnerTeamId,
        );
        if (winnerIndex != -1) {
          teamStats[winnerIndex].matchesPlayed++;
          teamStats[winnerIndex].won++;
          teamStats[winnerIndex].points += 2;
        }

        // Update loser stats
        final loserIndex = teamStats.indexWhere((t) => t.teamId == loserTeamId);
        if (loserIndex != -1) {
          teamStats[loserIndex].matchesPlayed++;
          teamStats[loserIndex].lost++;
        }
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Scheduled':
        return Colors.blue;
      case 'Ongoing':
        return Colors.orange;
      case 'Completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:play_hub/constants/badminton.dart';
import 'package:play_hub/screens/tournament/badminton/scorecard.dart';
import 'package:play_hub/service/auth_service.dart';
import 'package:play_hub/service/badminton_service.dart';

class BadmintonMatchScheduleScreen extends StatefulWidget {
  final String? tournamentId;
  final List<Team>? teams;
  final String? teamType;
  final int? matchesPerTeam;
  final DateTime? startDate;
  final TimeOfDay? startTime;
  final int? matchDuration;
  final int? breakDuration;
  final bool? allowRematches;
  final int? customTeamSize;
  final List<String>? members;

  const BadmintonMatchScheduleScreen({
    super.key,
    this.tournamentId,
    this.teams,
    this.teamType,
    this.matchesPerTeam,
    this.startDate,
    this.startTime,
    this.matchDuration,
    this.breakDuration,
    this.allowRematches,
    this.customTeamSize,
    this.members,
  });

  @override
  State<BadmintonMatchScheduleScreen> createState() =>
      _BadmintonMatchScheduleScreenState();
}

class _BadmintonMatchScheduleScreenState
    extends State<BadmintonMatchScheduleScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TournamentFirestoreService _firestoreService =
      TournamentFirestoreService();
  final AuthService _authService = AuthService();

  String? _tournamentId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeTournament();
  }

  Future<void> _initializeTournament() async {
    if (widget.tournamentId != null) {
      setState(() {
        _tournamentId = widget.tournamentId;
      });
    } else if (widget.teams != null &&
        widget.teamType != null &&
        widget.members != null) {
      await _createTournament();
    }
  }

  Future<void> _createTournament() async {
    setState(() => _isLoading = true);

    try {
      List<Match> matches = _generateMatches();

      String userEmail = _authService.currentUserEmailId!;
      String creatorName = _authService.currentUser?.displayName ?? 'Anonymous';

      String tournamentId = await _firestoreService.createTournament(
        userEmail: userEmail,
        creatorName: creatorName,
        members: widget.members!,
        teamType: widget.teamType!,
        teams: widget.teams!,
        matches: matches,
        startDate: widget.startDate!,
        startTime: widget.startTime!,
        matchDuration: widget.matchDuration!,
        breakDuration: widget.breakDuration!,
        matchesPerTeam: widget.matchesPerTeam!,
        allowRematches: widget.allowRematches!,
        customTeamSize: widget.customTeamSize,
      );

      setState(() {
        _tournamentId = tournamentId;
        _isLoading = false;
      });

      _showSuccessSnackBar('Tournament created successfully!');
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to create tournament: $e');
      print('Error creating tournament: $e');
    }
  }

  List<Match> _generateMatches() {
    List<Match> matches = [];
    if (widget.teams!.length < 2) return matches;

    DateTime currentMatchTime = DateTime(
      widget.startDate!.year,
      widget.startDate!.month,
      widget.startDate!.day,
      widget.startTime!.hour,
      widget.startTime!.minute,
    );

    final isCustomDoublesFormat =
        widget.teamType != 'Singles' &&
        widget.teamType != 'Doubles' &&
        widget.customTeamSize != null &&
        widget.customTeamSize! >= 2;

    if (isCustomDoublesFormat) {
      matches = _generateCustomDoublesMatches(currentMatchTime);
    } else {
      matches = _generateStandardMatches(currentMatchTime);
    }

    return matches;
  }

  List<Match> _generateStandardMatches(DateTime currentMatchTime) {
    List<Match> matches = [];
    List<MatchPair> pairs = [];

    for (int i = 0; i < widget.teams!.length; i++) {
      for (int j = i + 1; j < widget.teams!.length; j++) {
        pairs.add(MatchPair(widget.teams![i], widget.teams![j]));
      }
    }

    List<MatchPair> schedule = [];
    if (widget.allowRematches!) {
      for (int repeat = 0; repeat < widget.matchesPerTeam!; repeat++) {
        schedule.addAll(pairs);
      }
    } else {
      schedule = pairs;
    }

    schedule.shuffle();

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
        Duration(minutes: widget.matchDuration! + widget.breakDuration!),
      );
    }

    return matches;
  }

  List<Match> _generateCustomDoublesMatches(DateTime currentMatchTime) {
    List<Match> matches = [];

    // Generate all possible doubles pairs for each team
    List<TeamWithDoublesPairs> teamsWithPairs = [];

    for (var team in widget.teams!) {
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
    if (widget.allowRematches!) {
      for (int repeat = 0; repeat < widget.matchesPerTeam!; repeat++) {
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
        Duration(minutes: widget.matchDuration! + widget.breakDuration!),
      );
    }

    return matches;
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

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.orange.shade600),
              const SizedBox(height: 16),
              Text(
                'Creating tournament...',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
      );
    }

    if (_tournamentId == null) {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: Center(
          child: Text(
            'Tournament not found',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
          ),
        ),
      );
    }

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
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: _shareTournament,
          ),
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
              children: [_buildMatchesTab(), _buildStandingsTab()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchesTab() {
    return StreamBuilder<List<Match>>(
      stream: _firestoreService.getMatches(
        _authService.currentUserEmailId!,
        _tournamentId!,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: Colors.orange.shade600),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
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
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) =>
              _buildMatchCard(snapshot.data![index]),
        );
      },
    );
  }

  Widget _buildMatchCard(Match match) {
    return GestureDetector(
      onTap: () => _openScorecard(match),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
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
                    children: [
                      Expanded(
                        child: Text(
                          match.team1.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        '${match.score1}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          match.team2.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        '${match.score2}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
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
  }

  Widget _buildStandingsTab() {
    return StreamBuilder<List<TeamStats>>(
      stream: _firestoreService.getTeamStats(
        _authService.currentUserEmailId!,
        _tournamentId!,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: Colors.orange.shade600),
          );
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No teams found'));
        }

        List<TeamStats> teamStats = snapshot.data!;
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
              child: const Row(
                children: [
                  SizedBox(
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
                      'Team',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(
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
                  SizedBox(
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
                  SizedBox(
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
                itemBuilder: (context, index) =>
                    _buildTeamRow(teamStats[index], index),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTeamRow(TeamStats team, int index) {
    final isTopRanked = index == 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isTopRanked ? Colors.orange.shade50 : Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              '${index + 1}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
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
                    fontWeight: isTopRanked ? FontWeight.bold : FontWeight.w600,
                  ),
                ),
                if (team.players.length > 1)
                  Text(
                    team.players.join(', '),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
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
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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
  }

  void _openScorecard(Match match) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScorecardScreen(
          match: match,
          teamType: widget.teamType ?? 'Singles',
          onScoreUpdate: (updatedMatch) {
            _firestoreService.updateMatch(
              _authService.currentUserEmailId!,
              _tournamentId!,
              updatedMatch,
            );
          },
        ),
      ),
    );
  }

  void _shareTournament() async {
    if (_authService.currentUserEmailId == null || _tournamentId == null)
      return;

    try {
      String shareCode = await _firestoreService.createShareableLink(
        _authService.currentUserEmailId!,
        _tournamentId!,
      );

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.share, color: Colors.orange.shade600),
              const SizedBox(width: 12),
              const Text('Share Tournament'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Share Code',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200, width: 2),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        shareCode,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade900,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.copy, color: Colors.orange.shade600),
                      onPressed: () {
                        _showSuccessSnackBar('Code copied!');
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Share this code with others. Valid for 30 days.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
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
    } catch (e) {
      _showErrorSnackBar('Failed to create share link: $e');
    }
  }

  void _showTournamentInfo() {
    // Show tournament details
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

// Helper classes
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

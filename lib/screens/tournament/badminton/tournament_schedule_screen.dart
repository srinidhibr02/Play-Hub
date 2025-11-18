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
  final String? tournamentFormat;

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
    this.tournamentFormat,
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
  bool _isGeneratingNextRound = false;

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
        tournamentFormat: widget.tournamentFormat as String,
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

  // ==================== MATCH GENERATION ====================

  List<Match> _generateMatches() {
    if (widget.teams == null || widget.teams!.length < 2) return [];

    DateTime currentMatchTime = DateTime(
      widget.startDate!.year,
      widget.startDate!.month,
      widget.startDate!.day,
      widget.startTime!.hour,
      widget.startTime!.minute,
    );

    final format = widget.tournamentFormat ?? "round_robin";

    if (format == "knockout") {
      return _generateKnockoutFirstRound(currentMatchTime);
    } else {
      final isCustomDoublesFormat =
          widget.teamType != 'Singles' &&
          widget.teamType != 'Doubles' &&
          widget.customTeamSize != null &&
          widget.customTeamSize! >= 2;

      if (isCustomDoublesFormat) {
        return _generateCustomDoublesMatches(currentMatchTime);
      } else {
        return _generateStandardMatches(currentMatchTime);
      }
    }
  }

  // ==================== ROUND ROBIN SCHEDULING ====================

  List<Match> _generateStandardMatches(DateTime currentMatchTime) {
    List<Match> matches = [];
    List<MatchPair> schedule = _generateNonConsecutiveRoundRobinPairs(
      widget.teams!,
      widget.matchesPerTeam!,
    );

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

  List<MatchPair> _generateNonConsecutiveRoundRobinPairs(
    List<Team> teams,
    int matchesPerTeam,
  ) {
    List<MatchPair> allPairs = [];
    int n = teams.length;

    for (int repeat = 0; repeat < matchesPerTeam; repeat++) {
      for (int i = 0; i < n; i++) {
        for (int j = i + 1; j < n; j++) {
          allPairs.add(MatchPair(teams[i], teams[j]));
        }
      }
    }

    List<MatchPair> schedule = [];
    List<MatchPair> pool = List.from(allPairs);

    while (pool.isNotEmpty) {
      bool found = false;
      for (int i = 0; i < pool.length; i++) {
        if (schedule.isEmpty ||
            (schedule.last.team1.id != pool[i].team1.id &&
                schedule.last.team1.id != pool[i].team2.id &&
                schedule.last.team2.id != pool[i].team1.id &&
                schedule.last.team2.id != pool[i].team2.id)) {
          schedule.add(pool[i]);
          pool.removeAt(i);
          found = true;
          break;
        }
      }
      if (!found) {
        pool.shuffle();
      }
    }
    return schedule;
  }

  // ==================== CUSTOM DOUBLES SCHEDULING ====================

  List<Match> _generateCustomDoublesMatches(DateTime currentMatchTime) {
    List<Match> matches = [];

    List<TeamWithDoublesPairs> teamsWithPairs = [];
    for (var team in widget.teams!) {
      List<DoublesPair> doublesPairs = _generateDoublesPairs(team);
      teamsWithPairs.add(TeamWithDoublesPairs(team, doublesPairs));
    }

    List<DoublesMatch> allMatches = [];
    for (int i = 0; i < teamsWithPairs.length; i++) {
      for (int j = i + 1; j < teamsWithPairs.length; j++) {
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

    List<DoublesMatch> schedule = [];
    if (widget.allowRematches!) {
      for (int repeat = 0; repeat < widget.matchesPerTeam!; repeat++) {
        schedule.addAll(allMatches);
      }
    } else {
      schedule = allMatches;
    }

    schedule.shuffle();

    for (var doublesMatch in schedule) {
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

    for (int i = 0; i < players.length; i++) {
      for (int j = i + 1; j < players.length; j++) {
        pairs.add(DoublesPair(players[i], players[j]));
      }
    }

    return pairs;
  }

  // ==================== KNOCKOUT SCHEDULING ====================

  List<Match> _generateKnockoutFirstRound(DateTime currentMatchTime) {
    List<Match> matches = [];
    List<Team> teams = List.from(widget.teams!);
    teams.shuffle();

    int n = teams.length;

    // Calculate next power of 2
    int nextPowerOf2 = 1;
    while (nextPowerOf2 < n) {
      nextPowerOf2 <<= 1;
    }

    int numByes = nextPowerOf2 - n;
    int numFirstRoundTeams = n - numByes;

    // Teams that play in Round 1
    List<Team> round1Teams = teams.sublist(0, numFirstRoundTeams);

    // Teams that get byes (automatically advance to Round 2)
    // We don't store bye teams anywhere, they're just excluded from Round 1

    int totalRounds = _calculateKnockoutRounds(n);
    int matchNumber = 1;

    // Generate first round matches
    for (int i = 0; i < round1Teams.length; i += 2) {
      if (i + 1 < round1Teams.length) {
        matches.add(
          Match(
            id: 'M$matchNumber',
            team1: round1Teams[i],
            team2: round1Teams[i + 1],
            date: currentMatchTime,
            time: _formatTime(currentMatchTime),
            status: 'Scheduled',
            score1: 0,
            score2: 0,
            winner: null,
            round: 1,
            roundName: _getRoundName(1, totalRounds),
          ),
        );
        currentMatchTime = currentMatchTime.add(
          Duration(minutes: widget.matchDuration! + widget.breakDuration!),
        );
        matchNumber++;
      }
    }

    return matches;
  }

  // Generate next knockout round
  Future<void> _generateNextKnockoutRound(List<Match> allMatches) async {
    setState(() => _isGeneratingNextRound = true);

    try {
      int n = widget.teams?.length ?? 0;
      int totalRounds = _calculateKnockoutRounds(n);

      // Find current highest round
      int currentRound = 0;
      for (var match in allMatches) {
        if (match.round != null && match.round! > currentRound) {
          currentRound = match.round!;
        }
      }

      // Get all matches from current round
      List<Match> currentRoundMatches = allMatches
          .where((m) => m.round == currentRound)
          .toList();

      // Check if all matches in current round are completed
      bool allCompleted = currentRoundMatches.every((m) => m.winner != null);

      if (!allCompleted) {
        _showErrorSnackBar(
          'Please complete all matches in current round first',
        );
        setState(() => _isGeneratingNextRound = false);
        return;
      }

      int nextRound = currentRound + 1;

      // Calculate bye teams (only needed for Round 2)
      List<Team> byeTeams = [];
      if (currentRound == 1) {
        // Find teams that didn't play in Round 1 (these got byes)
        Set<String> round1TeamIds = {};
        for (var match in currentRoundMatches) {
          round1TeamIds.add(match.team1.id);
          round1TeamIds.add(match.team2.id);
        }

        for (var team in widget.teams!) {
          if (!round1TeamIds.contains(team.id)) {
            byeTeams.add(team);
          }
        }
      }

      // Get winners from current round
      List<Team> winners = [];
      for (var match in currentRoundMatches) {
        if (match.winner != null) {
          Team winningTeam = match.winner == match.team1.id
              ? match.team1
              : match.team2;
          winners.add(winningTeam);
        }
      }

      // Combine winners with bye teams (only for Round 2)
      List<Team> advancingTeams = currentRound == 1
          ? [...winners, ...byeTeams]
          : winners;

      // Shuffle for random pairings
      advancingTeams.shuffle();

      // Validate we have enough teams
      if (advancingTeams.length < 2) {
        _showErrorSnackBar('Not enough teams to generate next round');
        setState(() => _isGeneratingNextRound = false);
        return;
      }

      // Get last match time from current round
      DateTime lastMatchTime = currentRoundMatches
          .map((m) => m.date)
          .reduce((a, b) => a.isAfter(b) ? a : b);

      // Add break between rounds
      DateTime nextRoundStartTime = lastMatchTime.add(
        Duration(minutes: widget.breakDuration! * 3),
      );

      List<Match> nextRoundMatches = [];
      DateTime currentTime = nextRoundStartTime;
      int matchNumber = allMatches.length + 1;

      // Generate next round matches (pair teams sequentially)
      for (int i = 0; i < advancingTeams.length - 1; i += 2) {
        nextRoundMatches.add(
          Match(
            id: 'M$matchNumber',
            team1: advancingTeams[i],
            team2: advancingTeams[i + 1],
            date: currentTime,
            time: _formatTime(currentTime),
            status: 'Scheduled',
            score1: 0,
            score2: 0,
            winner: null,
            round: nextRound,
            roundName: _getRoundName(nextRound, totalRounds),
          ),
        );

        currentTime = currentTime.add(
          Duration(minutes: widget.matchDuration! + widget.breakDuration!),
        );
        matchNumber++;
      }

      if (nextRoundMatches.isEmpty) {
        _showErrorSnackBar('Could not generate next round matches');
        setState(() => _isGeneratingNextRound = false);
        return;
      }

      // Save next round matches to Firestore
      await _firestoreService.addMatches(
        _authService.currentUserEmailId!,
        _tournamentId!,
        nextRoundMatches,
      );

      setState(() => _isGeneratingNextRound = false);
      _showSuccessSnackBar(
        '${_getRoundName(nextRound, totalRounds)} generated successfully!',
      );
    } catch (e) {
      setState(() => _isGeneratingNextRound = false);
      _showErrorSnackBar('Failed to generate next round: $e');
      print('Error generating next round: $e');
    }
  }

  int _calculateKnockoutRounds(int numTeams) {
    if (numTeams <= 1) return 1;

    // Find next power of 2
    int nextPowerOf2 = 1;
    while (nextPowerOf2 < numTeams) {
      nextPowerOf2 <<= 1;
    }

    // Calculate number of rounds needed
    int rounds = 0;
    int temp = nextPowerOf2;
    while (temp > 1) {
      temp ~/= 2;
      rounds++;
    }

    return rounds;
  }

  String _getRoundName(int round, int totalRounds) {
    // Calculate how many teams are left in this round
    int teamsInRound = 1 << (totalRounds - round + 1);

    switch (teamsInRound) {
      case 2:
        return "Final";
      case 4:
        return "Semi Finals";
      case 8:
        return "Quarter Finals";
      case 16:
        return "Round of 16";
      default:
        return "Round $round";
    }
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

  // Check if current round is complete
  bool _isCurrentRoundComplete(List<Match> matches) {
    if (matches.isEmpty) return false;

    // Get current round number
    int currentRound = matches
        .map((m) => m.round ?? 0)
        .reduce((a, b) => a > b ? a : b);

    if (currentRound == 0) return false;

    // Get all matches in current round
    List<Match> currentRoundMatches = matches
        .where((m) => m.round == currentRound)
        .toList();

    // Check if all matches have winners
    return currentRoundMatches.every((m) => m.winner != null);
  }

  // Check if tournament is complete
  bool _isTournamentComplete(List<Match> matches) {
    if (matches.isEmpty) return false;

    int currentRound = matches
        .map((m) => m.round ?? 0)
        .reduce((a, b) => a > b ? a : b);

    if (currentRound == 0) return false;

    int totalRounds = _calculateKnockoutRounds(widget.teams?.length ?? 0);

    return currentRound >= totalRounds && _isCurrentRoundComplete(matches);
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

        final matches = snapshot.data!;
        final isKnockout = widget.tournamentFormat == "knockout";
        final roundComplete = isKnockout && _isCurrentRoundComplete(matches);
        final tournamentComplete = isKnockout && _isTournamentComplete(matches);

        return Column(
          children: [
            // Next Round Button (for knockout only)
            if (isKnockout && roundComplete && !tournamentComplete)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  onPressed: _isGeneratingNextRound
                      ? null
                      : () => _generateNextKnockoutRound(matches),
                  icon: _isGeneratingNextRound
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.arrow_forward, color: Colors.white),
                  label: Text(
                    _isGeneratingNextRound
                        ? 'Generating...'
                        : 'Generate Next Round',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

            // Tournament Complete Banner
            if (isKnockout && tournamentComplete)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.amber.shade600, Colors.orange.shade600],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.emoji_events,
                      color: Colors.white,
                      size: 40,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '🏆 Tournament Complete!',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Congratulations to all participants!',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: matches.length,
                itemBuilder: (context, index) =>
                    _buildMatchCard(matches[index]),
              ),
            ),
          ],
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Match ${match.id}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      if (match.roundName != null)
                        Text(
                          match.roundName!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.9),
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
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
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
                          color: Colors.orange.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
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
    if (_authService.currentUserEmailId == null || _tournamentId == null) {
      return;
    }

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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Scheduled':
        return Colors.blue;
      case 'Ongoing':
        return Colors.orange;
      case 'Completed':
        return Colors.green;
      case 'Bye':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }
}

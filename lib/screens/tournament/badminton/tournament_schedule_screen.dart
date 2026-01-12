import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:play_hub/constants/badminton.dart';
import 'package:play_hub/screens/tournament/badminton/scorecard.dart';
import 'package:play_hub/screens/tournament/badminton/points_table_screen.dart';
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
  final TournamentFirestoreService _badmintonFirestoreService =
      TournamentFirestoreService();
  final AuthService _authService = AuthService();

  String? _tournamentId;
  bool _isLoading = false;
  late int _tabCount;

  @override
  void initState() {
    super.initState();
    _tabCount = widget.tournamentFormat == 'knockout' ? 1 : 2;
    _tabController = TabController(length: _tabCount, vsync: this);
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
    } else {
      _showErrorSnackBar('Tournament data is incomplete');
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  Future<void> _createTournament() async {
    setState(() => _isLoading = true);

    try {
      if (widget.teams == null ||
          widget.teams!.isEmpty ||
          widget.teamType == null ||
          widget.members == null ||
          widget.startDate == null ||
          widget.startTime == null ||
          widget.matchDuration == null ||
          widget.breakDuration == null ||
          widget.matchesPerTeam == null ||
          widget.allowRematches == null) {
        throw Exception('Missing required tournament parameters');
      }

      List<Match> matches = _generateMatches();

      if (matches.isEmpty) {
        throw Exception('Could not generate matches');
      }

      String? userEmail = _authService.currentUserEmailId;
      if (userEmail == null || userEmail.isEmpty) {
        throw Exception('User not authenticated');
      }

      String creatorName = _authService.currentUser?.displayName ?? 'Anonymous';

      String tournamentId = await _badmintonFirestoreService.createTournament(
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
        tournamentFormat: widget.tournamentFormat ?? 'round_robin',
      );

      if (!mounted) return;

      setState(() {
        _tournamentId = tournamentId;
        _isLoading = false;
      });

      _showSuccessSnackBar('Tournament created successfully!');
    } catch (e) {
      print('❌ Error creating tournament: $e');
      if (!mounted) return;

      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to create tournament: $e');
    }
  }

  List<Match> _generateMatches() {
    List<Match> matches = [];

    if (widget.teams == null || widget.teams!.length < 2) {
      print('❌ Error: Not enough teams (${widget.teams?.length ?? 0})');
      return matches;
    }

    if (widget.startDate == null || widget.startTime == null) {
      print('❌ Error: Start date or time is null');
      return matches;
    }

    DateTime currentMatchTime = DateTime(
      widget.startDate!.year,
      widget.startDate!.month,
      widget.startDate!.day,
      widget.startTime!.hour,
      widget.startTime!.minute,
    );

    final isCustomDoublesFormat =
        widget.teamType != null &&
        widget.teamType != 'Singles' &&
        widget.teamType != 'Doubles' &&
        widget.customTeamSize != null &&
        widget.customTeamSize! >= 2;

    if (widget.tournamentFormat == 'knockout') {
      matches = isCustomDoublesFormat
          ? _generateCustomDoublesKnockout(currentMatchTime)
          : _generateKnockoutMatches(currentMatchTime);
    } else {
      matches = isCustomDoublesFormat
          ? _generateCustomDoublesMatches(currentMatchTime)
          : _generateRoundRobinMatches(currentMatchTime);
    }

    print('✅ Generated ${matches.length} matches');
    return matches;
  }

  // ==================== ROUND ROBIN SCHEDULING ====================

  List<Match> _generateRoundRobinMatches(DateTime currentMatchTime) {
    List<Match> matches = [];
    List<Team> teams = List.from(widget.teams!);

    if (teams.length % 2 != 0) {
      teams.add(Team(id: 'BYE', name: 'BYE', players: []));
    }

    int numTeams = teams.length;
    int numRounds = numTeams - 1;
    int matchesPerRound = numTeams ~/ 2;

    for (int round = 0; round < numRounds; round++) {
      for (int match = 0; match < matchesPerRound; match++) {
        int home = (round + match) % (numTeams - 1);
        int away = (numTeams - 1 - match + round) % (numTeams - 1);

        if (match == 0) {
          away = numTeams - 1;
        }

        Team team1 = teams[home];
        Team team2 = teams[away];

        if (team1.id == 'BYE' || team2.id == 'BYE') continue;

        matches.add(
          Match(
            id: 'M${matches.length + 1}',
            team1: team1,
            team2: team2,
            date: currentMatchTime,
            time: _formatTime(currentMatchTime),
            status: 'Scheduled',
            score1: 0,
            score2: 0,
            winner: null,
            round: round + 1,
            roundName: 'Round ${round + 1}',
            stage: 'League',
          ),
        );
      }

      if (widget.matchDuration != null && widget.breakDuration != null) {
        currentMatchTime = currentMatchTime.add(
          Duration(
            minutes:
                (widget.matchDuration! + widget.breakDuration!) *
                matchesPerRound,
          ),
        );
      }
    }

    return matches;
  }

  List<Match> _generateCustomDoublesMatches(DateTime currentMatchTime) {
    List<Match> matches = [];
    Map<String, DateTime> teamLastMatchTime = {};

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

    allMatches.shuffle();

    for (var doublesMatch in allMatches) {
      DateTime team1LastMatch =
          teamLastMatchTime[doublesMatch.team1.id] ?? DateTime(1970);
      DateTime team2LastMatch =
          teamLastMatchTime[doublesMatch.team2.id] ?? DateTime(1970);

      DateTime maxLastMatch = team1LastMatch.isAfter(team2LastMatch)
          ? team1LastMatch
          : team2LastMatch;

      if (widget.matchDuration != null && widget.breakDuration != null) {
        if (currentMatchTime.isBefore(
          maxLastMatch.add(
            Duration(minutes: widget.matchDuration! + widget.breakDuration!),
          ),
        )) {
          currentMatchTime = maxLastMatch.add(
            Duration(minutes: widget.matchDuration! + widget.breakDuration!),
          );
        }
      }

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
          round: null,
          roundName: null,
          stage: 'League',
        ),
      );

      teamLastMatchTime[doublesMatch.team1.id] = currentMatchTime;
      teamLastMatchTime[doublesMatch.team2.id] = currentMatchTime;

      if (widget.matchDuration != null && widget.breakDuration != null) {
        currentMatchTime = currentMatchTime.add(
          Duration(minutes: widget.matchDuration! + widget.breakDuration!),
        );
      }
    }

    return matches;
  }

  // ==================== KNOCKOUT SCHEDULING ====================

  List<Match> _generateKnockoutMatches(DateTime currentMatchTime) {
    List<Match> matches = [];
    List<Team> teams = List.from(widget.teams!);
    teams.shuffle();

    int numTeams = teams.length;
    int totalRounds = _calculateKnockoutRounds(numTeams);

    int currentRound = 1;
    List<Team> currentTeams = teams;

    while (currentTeams.length > 1) {
      List<Team> nextRoundTeams = [];

      for (int i = 0; i < currentTeams.length; i += 2) {
        if (i + 1 < currentTeams.length) {
          matches.add(
            Match(
              id: 'M${matches.length + 1}',
              team1: currentTeams[i],
              team2: currentTeams[i + 1],
              date: currentMatchTime,
              time: _formatTime(currentMatchTime),
              status: 'Scheduled',
              score1: 0,
              score2: 0,
              winner: null,
              round: currentRound,
              roundName: _getRoundName(currentRound, totalRounds),
              stage: 'Knockout',
            ),
          );

          nextRoundTeams.add(currentTeams[i]);

          if (widget.matchDuration != null && widget.breakDuration != null) {
            currentMatchTime = currentMatchTime.add(
              Duration(minutes: widget.matchDuration! + widget.breakDuration!),
            );
          }
        } else {
          nextRoundTeams.add(currentTeams[i]);
        }
      }

      currentTeams = nextRoundTeams;
      currentRound++;

      if (currentTeams.length > 1 && widget.breakDuration != null) {
        currentMatchTime = currentMatchTime.add(
          Duration(minutes: widget.breakDuration! * 2),
        );
      }
    }

    return matches;
  }

  List<Match> _generateCustomDoublesKnockout(DateTime currentMatchTime) {
    List<Match> matches = [];

    List<Team> allPairs = [];
    for (var team in widget.teams!) {
      List<DoublesPair> doublesPairs = _generateDoublesPairs(team);
      for (var pair in doublesPairs) {
        allPairs.add(
          Team(
            id: '${team.id}_${pair.player1}_${pair.player2}',
            name: '${team.name}: ${pair.player1} & ${pair.player2}',
            players: [pair.player1, pair.player2],
          ),
        );
      }
    }

    allPairs.shuffle();

    int totalRounds = _calculateKnockoutRounds(allPairs.length);
    int currentRound = 1;
    List<Team> currentTeams = allPairs;

    while (currentTeams.length > 1) {
      List<Team> nextRoundTeams = [];

      for (int i = 0; i < currentTeams.length; i += 2) {
        if (i + 1 < currentTeams.length) {
          matches.add(
            Match(
              id: 'M${matches.length + 1}',
              team1: currentTeams[i],
              team2: currentTeams[i + 1],
              date: currentMatchTime,
              time: _formatTime(currentMatchTime),
              status: 'Scheduled',
              score1: 0,
              score2: 0,
              winner: null,
              round: currentRound,
              roundName: _getRoundName(currentRound, totalRounds),
              stage: 'Knockout',
            ),
          );

          nextRoundTeams.add(currentTeams[i]);
          if (widget.matchDuration != null && widget.breakDuration != null) {
            currentMatchTime = currentMatchTime.add(
              Duration(minutes: widget.matchDuration! + widget.breakDuration!),
            );
          }
        } else {
          nextRoundTeams.add(currentTeams[i]);
        }
      }

      currentTeams = nextRoundTeams;
      currentRound++;

      if (currentTeams.length > 1 && widget.breakDuration != null) {
        currentMatchTime = currentMatchTime.add(
          Duration(minutes: widget.breakDuration! * 2),
        );
      }
    }

    return matches;
  }

  int _calculateKnockoutRounds(int numTeams) {
    int rounds = 0;
    int remaining = numTeams;
    while (remaining > 1) {
      remaining = (remaining + 1) ~/ 2;
      rounds++;
    }
    return rounds;
  }

  String _getRoundName(int currentRound, int totalRounds) {
    int roundsFromEnd = totalRounds - currentRound;
    switch (roundsFromEnd) {
      case 0:
        return 'Final';
      case 1:
        return 'Semi-Final';
      case 2:
        return 'Quarter-Final';
      default:
        return 'Round $currentRound';
    }
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

  String _formatTime(DateTime dateTime) =>
      DateFormat('h:mm a').format(dateTime);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
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
    if (!mounted) return;
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
              tabs: _tabCount == 1
                  ? const [
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
                    ]
                  : [
                      const Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.sports_tennis, size: 20),
                            SizedBox(width: 8),
                            Text('Matches'),
                          ],
                        ),
                      ),
                      const Tab(
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
            child: _tabCount == 1
                ? _buildMatchesTab()
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildMatchesTab(),
                      StandingsTab(
                        tournamentId: _tournamentId,
                        matchDuration: widget.matchDuration,
                        breakDuration: widget.breakDuration,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchesTab() {
    return StreamBuilder<List<Match>>(
      stream: _badmintonFirestoreService.getMatches(
        _authService.currentUserEmailId ?? '',
        _tournamentId ?? '',
      ),
      builder: (context, snapshot) {
        // ✅ Better debugging
        if (snapshot.hasError) {
          print('❌ Snapshot Error: ${snapshot.error}');
          print('❌ Stack trace: ${snapshot.stackTrace}');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Error: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red.shade600),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: Colors.orange.shade600),
          );
        }

        if (!snapshot.hasData) {
          print('❌ No data in snapshot');
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

        List<Match> allMatches = snapshot.data ?? [];

        if (allMatches.isEmpty) {
          print('❌ Matches list is empty');
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
                  'No matches found',
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

        print('✅ Found ${allMatches.length} matches');

        // ✅ FIX: Separate matches by stage
        List<Match> leagueMatches = allMatches
            .where((m) => m.stage == 'League' || m.stage == null)
            .toList();
        List<Match> playoffMatches = allMatches
            .where((m) => m.stage == 'Playoff')
            .toList();
        List<Match> knockoutMatches = allMatches
            .where((m) => m.stage == 'Knockout')
            .toList();

        print(
          '✅ League: ${leagueMatches.length}, Playoff: ${playoffMatches.length}, Knockout: ${knockoutMatches.length}',
        );

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ✅ LEAGUE STAGE SECTION
            if (leagueMatches.isNotEmpty) ...[
              _buildSectionHeader(
                icon: Icons.sports_tennis,
                title: 'League Stage',
                color: Colors.blue,
                matchCount: leagueMatches.length,
              ),
              ...leagueMatches
                  .map((match) => _buildMatchCard(match, isLeague: true))
                  .toList(),
              const SizedBox(height: 24),
            ],

            // ✅ PLAYOFF STAGE SECTION
            if (playoffMatches.isNotEmpty) ...[
              _buildSectionHeader(
                icon: Icons.emoji_events,
                title: 'Playoff Stage',
                color: Colors.amber,
                matchCount: playoffMatches.length,
              ),
              ...playoffMatches
                  .map((match) => _buildMatchCard(match, isLeague: false))
                  .toList(),
              const SizedBox(height: 24),
            ],

            // ✅ KNOCKOUT STAGE SECTION
            if (knockoutMatches.isNotEmpty) ...[
              _buildSectionHeader(
                icon: Icons.military_tech,
                title: 'Knockout Stage',
                color: Colors.red,
                matchCount: knockoutMatches.length,
              ),
              ...knockoutMatches
                  .map((match) => _buildMatchCard(match, isLeague: false))
                  .toList(),
            ],

            // ✅ Show message if no matches in any stage
            if (leagueMatches.isEmpty &&
                playoffMatches.isEmpty &&
                knockoutMatches.isEmpty)
              Center(
                child: Text(
                  'No matches in any stage',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
              ),
          ],
        );
      },
    );
  }

  // ✅ NEW: Section header widget
  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required Color color,
    required int matchCount,
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
                  '$matchCount matches',
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
              matchCount.toString(),
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
    return GestureDetector(
      onTap: () => _openScorecard(match),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          // ✅ FIX: Different border colors for league vs playoff
          border: Border.all(
            color: isLeague ? Colors.blue.shade300 : Colors.amber.shade300,
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
                // ✅ FIX: Different gradient for league vs playoff
                gradient: LinearGradient(
                  colors: isLeague
                      ? [Colors.blue.shade600, Colors.blue.shade400]
                      : [Colors.amber.shade600, Colors.amber.shade400],
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
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white70,
                          ),
                        ),
                      // ✅ NEW: Show stage label
                      const SizedBox(height: 4),
                      Text(
                        match.stage ?? 'Match',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white60,
                          fontStyle: FontStyle.italic,
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
                          color: isLeague
                              ? Colors.blue.shade600
                              : Colors.amber.shade600,
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

  void _openScorecard(Match match) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScorecardScreen(
          match: match,
          teamType: widget.teamType ?? 'Singles',
          onScoreUpdate: (updatedMatch) {
            _badmintonFirestoreService.updateMatch(
              _authService.currentUserEmailId ?? '',
              _tournamentId ?? '',
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
      String shareCode = await _badmintonFirestoreService.createShareableLink(
        _authService.currentUserEmailId!,
        _tournamentId!,
      );

      if (!mounted) return;

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
            _infoRow(
              'Format',
              widget.tournamentFormat?.toUpperCase() ?? 'ROUND ROBIN',
            ),
            _infoRow('Team Type', widget.teamType ?? 'Singles'),
            _infoRow('Teams', '${widget.teams?.length ?? 0}'),
            _infoRow('Match Duration', '${widget.matchDuration} min'),
            _infoRow('Break Duration', '${widget.breakDuration} min'),
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

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
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
      default:
        return Colors.grey;
    }
  }
}

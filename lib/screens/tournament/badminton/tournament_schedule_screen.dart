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
  final int? rematches;
  final DateTime? startDate;
  final TimeOfDay? startTime;
  final int? matchDuration;
  final int? breakDuration;
  final int? totalMatches;
  final bool? allowRematches;
  final int? customTeamSize;
  final List<String>? members;
  final String? tournamentFormat;

  const BadmintonMatchScheduleScreen({
    super.key,
    this.tournamentId,
    this.teams,
    this.teamType,
    this.rematches,
    this.startDate,
    this.startTime,
    this.matchDuration,
    this.breakDuration,
    this.totalMatches,
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
          widget.rematches == null ||
          widget.totalMatches == null ||
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
        totalMatches: widget.totalMatches!,
        rematches: widget.rematches!,
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
    debugPrint('🔢 Generating ${widget.totalMatches} matches');
    debugPrint('  allowRematches: ${widget.allowRematches}');
    debugPrint('  rematches: ${widget.rematches}');

    List<Match> matches = [];

    if (widget.teams == null || widget.teams!.length < 2) {
      debugPrint('❌ Not enough teams: ${widget.teams?.length ?? 0}');
      return matches;
    }

    if (widget.startDate == null || widget.startTime == null) {
      debugPrint('❌ Missing start date/time');
      return matches;
    }

    DateTime currentMatchTime = DateTime(
      widget.startDate!.year,
      widget.startDate!.month,
      widget.startDate!.day,
      widget.startTime!.hour,
      widget.startTime!.minute,
    );

    // 🎯 HANDLE KNOCKOUT (always teamsCount - 1 matches)
    if (widget.tournamentFormat == 'knockout') {
      return _generateKnockoutMatchesLimited(
        currentMatchTime,
        widget.totalMatches!,
      );
    }

    // 🎯 ROUND ROBIN WITH REMATCHES LOGIC
    // Calculate unique team matchups: C(n,2)
    final int teamsCount = widget.teams!.length;
    final int uniqueMatchups = (teamsCount * (teamsCount - 1)) ~/ 2;

    debugPrint('  📊 Teams: $teamsCount, Unique matchups: $uniqueMatchups');

    int matchesPerMatchup = widget.allowRematches! ? widget.rematches! : 1;
    int maxPossibleMatches = uniqueMatchups * matchesPerMatchup;

    debugPrint(
      '  🎯 Max possible: $maxPossibleMatches, User requested: ${widget.totalMatches}',
    );

    // Generate exactly user-specified totalMatches
    return _generateRoundRobinWithRematches(
      currentMatchTime,
      widget.totalMatches!,
      uniqueMatchups,
      matchesPerMatchup,
    );
  }

  List<Match> _generateRoundRobinWithRematches(
    DateTime currentMatchTime,
    int totalMatchesRequested,
    int uniqueMatchups,
    int matchesPerMatchup,
  ) {
    List<Match> matches = [];
    List<Team> teams = List.from(widget.teams!);

    // 🎯 TRACK LAST MATCHED OPPONENTS FOR EACH TEAM
    Map<String, Set<String>> teamRecentOpponents = {};
    Map<String, DateTime> teamLastMatchTime = {};

    // Initialize tracking
    for (var team in teams) {
      teamRecentOpponents[team.id] = <String>{};
    }

    // Generate ALL possible matchups
    List<List<Team>> allMatchups = [];
    for (int i = 0; i < teams.length; i++) {
      for (int j = i + 1; j < teams.length; j++) {
        allMatchups.add([teams[i], teams[j]]);
      }
    }

    int generated = 0;

    while (generated < totalMatchesRequested) {
      // 🎯 Find BEST next matchup (no recent opponents)
      List<Team> bestMatchup = _findBestMatchup(
        allMatchups,
        teamRecentOpponents,
        teamLastMatchTime,
        currentMatchTime,
      );

      if (bestMatchup.isEmpty) {
        // Fallback: use first available
        bestMatchup = allMatchups.isNotEmpty ? allMatchups.removeAt(0) : [];
      }

      if (bestMatchup.isEmpty) break;

      Team team1 = bestMatchup[0];
      Team team2 = bestMatchup[1];

      // Generate this match
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
          round: null,
          roundName: 'Match ${matches.length + 1}',
          stage: 'League',
          rematchNumber: widget.allowRematches! ? 1 : null,
        ),
      );

      // 🎯 UPDATE RECENT OPPONENTS (last 2 matches only)
      teamRecentOpponents[team1.id]!
        ..add(team2.id)
        ..removeWhere((id) => teamRecentOpponents[team1.id]!.length > 2);
      teamRecentOpponents[team2.id]!
        ..add(team1.id)
        ..removeWhere((id) => teamRecentOpponents[team2.id]!.length > 2);

      teamLastMatchTime[team1.id] = currentMatchTime;
      teamLastMatchTime[team2.id] = currentMatchTime;

      generated++;

      // Remove this matchup from available (avoid immediate repeat)
      allMatchups.removeWhere(
        (m) =>
            (m[0].id == team1.id && m[1].id == team2.id) ||
            (m[0].id == team2.id && m[1].id == team1.id),
      );

      // Advance time
      currentMatchTime = currentMatchTime.add(
        Duration(
          minutes: (widget.matchDuration ?? 30) + (widget.breakDuration ?? 5),
        ),
      );
    }

    debugPrint('✅ Generated $generated matches - NO CONSECUTIVE TEAMS');
    return matches;
  }

  List<Match> _generateKnockoutMatchesLimited(
    DateTime currentMatchTime,
    int totalMatchesRequested,
  ) {
    List<Match> matches = [];
    List<Team> teams = List.from(widget.teams!);
    teams.shuffle();

    // Generate matches sequentially until we hit totalMatches
    int matchIndex = 0;
    while (matchIndex < totalMatchesRequested && teams.isNotEmpty) {
      if (teams.length < 2) break;

      Team team1 = teams.removeAt(0);
      Team team2 = teams.removeAt(0);

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
          round: (matchIndex ~/ 2) + 1,
          roundName: _getKnockoutRoundName(matches.length + 1),
          stage: 'Knockout',
        ),
      );

      matchIndex++;

      if (widget.matchDuration != null && widget.breakDuration != null) {
        currentMatchTime = currentMatchTime.add(
          Duration(minutes: widget.matchDuration! + widget.breakDuration!),
        );
      }
    }

    debugPrint(
      '✅ Generated $matchIndex/$totalMatchesRequested knockout matches',
    );
    return matches;
  }

  List<Team> _findBestMatchup(
    List<List<Team>> availableMatchups,
    Map<String, Set<String>> teamRecentOpponents,
    Map<String, DateTime> teamLastMatchTime,
    DateTime currentTime,
  ) {
    List<List<Team>> validMatchups = [];

    for (var matchup in availableMatchups) {
      Team team1 = matchup[0];
      Team team2 = matchup[1];

      // 🎯 RULE 1: No recent opponents (last 2 matches)
      bool hasRecentOpponent =
          teamRecentOpponents[team1.id]!.contains(team2.id) ||
          teamRecentOpponents[team2.id]!.contains(team1.id);

      // 🎯 RULE 2: Minimum time gap (15 mins since last match)
      DateTime team1Last = teamLastMatchTime[team1.id] ?? DateTime(1970);
      DateTime team2Last = teamLastMatchTime[team2.id] ?? DateTime(1970);
      bool hasTimeGap =
          currentTime.isAfter(team1Last.add(Duration(minutes: 15))) &&
          currentTime.isAfter(team2Last.add(Duration(minutes: 15)));

      if (!hasRecentOpponent && hasTimeGap) {
        validMatchups.add(matchup);
      }
    }

    // Return BEST available (or empty)
    return validMatchups.isNotEmpty ? validMatchups[0] : [];
  }

  String _getKnockoutRoundName(int matchNumber) {
    switch (matchNumber) {
      case 1:
        return 'Final';
      case 2:
      case 3:
        return 'Semi-Final';
      case 4:
      case 5:
      case 6:
      case 7:
        return 'Quarter-Final';
      default:
        return 'Round ${matchNumber}';
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
                      // ✅ NEW: Show stage label
                      const SizedBox(height: 4),
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

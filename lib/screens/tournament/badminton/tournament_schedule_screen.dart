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

  bool _isReorderMode = false;
  List<Match> _reorderMatches = [];

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

    if (widget.tournamentFormat == 'knockout') {
      return _generateKnockoutMatchesLimited(
        currentMatchTime,
        widget.totalMatches!,
      );
    }

    final int teamsCount = widget.teams!.length;
    final int uniqueMatchups = (teamsCount * (teamsCount - 1)) ~/ 2;

    debugPrint('  📊 Teams: $teamsCount, Unique matchups: $uniqueMatchups');

    int matchesPerMatchup = widget.allowRematches! ? widget.rematches! : 1;
    int maxPossibleMatches = uniqueMatchups * matchesPerMatchup;

    debugPrint(
      '  🎯 Max possible: $maxPossibleMatches, User requested: ${widget.totalMatches}',
    );

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

    // 🎯 TRACK MATCH COUNT PER MATCHUP (NOT remove matchups!)
    Map<String, int> matchupCount = {}; // "team1_team2": count
    Map<String, Set<String>> teamRecentOpponents = {};
    Map<String, DateTime> teamLastMatchTime = {};

    // Initialize tracking
    for (var team in teams) {
      teamRecentOpponents[team.id] = <String>{};
    }

    // Generate ALL possible matchups (keep them available!)
    List<List<Team>> allMatchups = [];
    for (int i = 0; i < teams.length; i++) {
      for (int j = i + 1; j < teams.length; j++) {
        String key = '${teams[i].id}_${teams[j].id}';
        matchupCount[key] = 0;
        allMatchups.add([teams[i], teams[j]]);
      }
    }

    int generated = 0;

    while (generated < totalMatchesRequested) {
      // 🎯 Find BEST matchup respecting ALL constraints
      List<Team> bestMatchup = _findBestMatchupWithRematchSupport(
        allMatchups,
        matchupCount,
        matchesPerMatchup,
        teamRecentOpponents,
        teamLastMatchTime,
        currentMatchTime,
      );

      if (bestMatchup.isEmpty) break;

      Team team1 = bestMatchup[0];
      Team team2 = bestMatchup[1];
      String matchupKey = '${team1.id}_${team2.id}';

      // ✅ Generate this match
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
          rematchNumber: (matchupCount[matchupKey]! + 1),
        ),
      );

      // ✅ INCREMENT matchup count (don't remove!)
      matchupCount[matchupKey] = matchupCount[matchupKey]! + 1;

      // Update recent opponents (max 2)
      teamRecentOpponents[team1.id]!
        ..add(team2.id)
        ..removeWhere((id) => teamRecentOpponents[team1.id]!.length > 2);
      teamRecentOpponents[team2.id]!
        ..add(team1.id)
        ..removeWhere((id) => teamRecentOpponents[team2.id]!.length > 2);

      teamLastMatchTime[team1.id] = currentMatchTime;
      teamLastMatchTime[team2.id] = currentMatchTime;
      generated++;

      // Advance time
      currentMatchTime = currentMatchTime.add(
        Duration(
          minutes: (widget.matchDuration ?? 30) + (widget.breakDuration ?? 5),
        ),
      );
    }

    // 🎯 FALLBACK: Fill remaining matches if needed
    while (generated < totalMatchesRequested) {
      List<Team> fallbackMatchup = _getAnyValidMatchup(
        allMatchups,
        matchupCount,
        matchesPerMatchup,
      );
      if (fallbackMatchup.isEmpty) break;

      Team team1 = fallbackMatchup[0];
      Team team2 = fallbackMatchup[1];
      String matchupKey = '${team1.id}_${team2.id}';

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
          rematchNumber: matchupCount[matchupKey]! + 1,
        ),
      );

      matchupCount[matchupKey] = matchupCount[matchupKey]! + 1;
      generated++;
      currentMatchTime = currentMatchTime.add(Duration(minutes: 35));
    }

    debugPrint('✅ Generated $generated/$totalMatchesRequested matches');
    debugPrint('  Matchup counts: $matchupCount');
    return matches;
  }

  List<Match> _generateKnockoutMatchesLimited(
    DateTime currentMatchTime,
    int totalMatchesRequested,
  ) {
    List<Match> matches = [];
    List<Team> teams = List.from(widget.teams!);
    teams.shuffle();

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

  List<Team> _findBestMatchupWithRematchSupport(
    List<List<Team>> allMatchups,
    Map<String, int> matchupCount,
    int maxMatchesPerMatchup,
    Map<String, Set<String>> teamRecentOpponents,
    Map<String, DateTime> teamLastMatchTime,
    DateTime currentTime,
  ) {
    List<List<Team>> validMatchups = [];

    for (var matchup in allMatchups) {
      Team team1 = matchup[0];
      Team team2 = matchup[1];
      String key = '${team1.id}_${team2.id}';

      // ✅ RULE 1: Respect rematch limit
      if (matchupCount[key]! >= maxMatchesPerMatchup) continue;

      // RULE 2: No recent opponents
      bool hasRecentOpponent =
          teamRecentOpponents[team1.id]!.contains(team2.id) ||
          teamRecentOpponents[team2.id]!.contains(team1.id);
      if (hasRecentOpponent) continue;

      // RULE 3: Time gap (15 mins)
      DateTime team1Last = teamLastMatchTime[team1.id] ?? DateTime(1970);
      DateTime team2Last = teamLastMatchTime[team2.id] ?? DateTime(1970);
      bool hasTimeGap =
          currentTime.isAfter(team1Last.add(Duration(minutes: 15))) &&
          currentTime.isAfter(team2Last.add(Duration(minutes: 15)));
      if (!hasTimeGap) continue;

      validMatchups.add(matchup);
    }

    return validMatchups.isNotEmpty ? validMatchups[0] : [];
  }

  List<Team> _getAnyValidMatchup(
    List<List<Team>> allMatchups,
    Map<String, int> matchupCount,
    int maxMatchesPerMatchup,
  ) {
    for (var matchup in allMatchups) {
      String key = '${matchup[0].id}_${matchup[1].id}';
      if (matchupCount[key]! < maxMatchesPerMatchup) {
        return matchup;
      }
    }
    return [];
  }

  String _getKnockoutRoundName(int matchNumber, {int? teamCount}) {
    // Calculate round based on match number and total teams
    final int totalTeams = teamCount ?? widget.teams?.length ?? 2;
    final int matchesInRound = _getMatchesInRound(matchNumber, totalTeams);

    if (matchesInRound == 1) return 'Final';
    if (matchesInRound == 2) return 'Semi-Final';
    if (matchesInRound <= 4) return 'Quarter-Final';
    if (matchesInRound <= 8) return 'Round of 16';
    if (matchesInRound <= 16) return 'Round of 32';

    return 'Round of ${matchesInRound * 2}';
  }

  int _getMatchesInRound(int matchNumber, int totalTeams) {
    // Simulate bracket to find which round this match belongs to
    List<int> roundMatches = [];
    int remainingTeams = totalTeams;

    while (remainingTeams > 1) {
      int matches = (remainingTeams + 1) ~/ 2;
      roundMatches.add(matches);
      remainingTeams = matches;
    }

    // Find round for this match number
    int cumulativeMatches = 0;
    for (int i = 0; i < roundMatches.length; i++) {
      cumulativeMatches += roundMatches[i];
      if (matchNumber <= cumulativeMatches) {
        return roundMatches[i];
      }
    }

    return 1; // Final fallback
  }

  void _toggleReorderMode() {
    if (!_isReorderMode) {
      setState(() => _isReorderMode = true);
    } else {
      _saveReorderedMatches();
    }
  }

  Future<void> _saveReorderedMatches() async {
    try {
      DateTime currentTime = DateTime(
        widget.startDate!.year,
        widget.startDate!.month,
        widget.startDate!.day,
        widget.startTime!.hour,
        widget.startTime!.minute,
      );

      List<Match> updatedMatches = [];
      for (int i = 0; i < _reorderMatches.length; i++) {
        Match match = _reorderMatches[i];

        Match updatedMatch = Match(
          id: 'M${i + 1}',
          team1: match.team1,
          team2: match.team2,
          date: currentTime,
          time: _formatTime(currentTime),
          status: match.status,
          score1: match.score1,
          score2: match.score2,
          winner: match.winner,
          round: match.round,
          roundName: match.roundName,
          stage: match.stage,
          parentTeam1Id: match.parentTeam1Id,
          parentTeam2Id: match.parentTeam2Id,
        );

        updatedMatches.add(updatedMatch);

        currentTime = currentTime.add(
          Duration(
            minutes: (widget.matchDuration ?? 30) + (widget.breakDuration ?? 5),
          ),
        );
      }

      await _badmintonFirestoreService.updateMatchOrder(
        _authService.currentUserEmailId ?? '',
        _tournamentId ?? '',
        updatedMatches,
      );

      setState(() {
        _isReorderMode = false;
        _reorderMatches = [];
      });

      _showSuccessSnackBar('Match order updated successfully!');
    } catch (e) {
      debugPrint('❌ Error saving reorder: $e');
      _showErrorSnackBar('Failed to save match order: $e');
    }
  }

  Widget _buildMatchesTab() {
    return StreamBuilder<List<Match>>(
      stream: _badmintonFirestoreService.getMatches(
        _authService.currentUserEmailId ?? '',
        _tournamentId ?? '',
      ),
      builder: (context, snapshot) {
        if (_isReorderMode) {
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text(
                'No matches to reorder',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
            );
          }

          if (_reorderMatches.isEmpty) {
            _reorderMatches = List.from(snapshot.data!);
          }

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.amber.shade50,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.drag_indicator,
                          color: Colors.amber.shade700,
                        ),
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
                  ],
                ),
              ),
              Expanded(
                child: ReorderableListView(
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) newIndex--;
                      final Match match = _reorderMatches.removeAt(oldIndex);
                      _reorderMatches.insert(newIndex, match);
                    });
                  },
                  padding: const EdgeInsets.all(16),
                  children: [
                    ..._reorderMatches.asMap().entries.map((entry) {
                      int index = entry.key;
                      Match match = entry.value;
                      return _buildDraggableMatchCard(
                        match,
                        index,
                        key: ValueKey('reorder_${match.id}_$index'),
                      );
                    }),
                  ],
                ),
              ),
            ],
          );
        }

        return _buildNormalMatchesList(snapshot);
      },
    );
  }

  Widget _buildDraggableMatchCard(Match match, int index, {required Key key}) {
    return Container(
      key: key,
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
            child: Column(
              children: [
                Row(
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
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNormalMatchesList(AsyncSnapshot<List<Match>> snapshot) {
    if (snapshot.hasError) {
      debugPrint('❌ Snapshot Error: ${snapshot.error}');
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

    if (!snapshot.hasData || (snapshot.data ?? []).isEmpty) {
      debugPrint('❌ No matches data');
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

    List<Match> allMatches = snapshot.data!;
    debugPrint('✅ Found ${allMatches.length} matches');

    List<Match> leagueMatches = allMatches
        .where((m) => m.stage == 'League' || m.stage == null)
        .toList();
    List<Match> playoffMatches = allMatches
        .where((m) => m.stage == 'Playoff')
        .toList();
    List<Match> knockoutMatches = allMatches
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
            matchCount: leagueMatches.length,
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
            matchCount: playoffMatches.length,
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
            matchCount: knockoutMatches.length,
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
    if (_authService.currentUserEmailId == null || _tournamentId == null) {
      return;
    }

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

  String _formatTime(DateTime dateTime) =>
      DateFormat('h:mm a').format(dateTime);

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

    return WillPopScope(
      onWillPop: () async {
        if (_isReorderMode) {
          setState(() => _isReorderMode = false);
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          backgroundColor: Colors.orange.shade600,
          elevation: 0,
          centerTitle: false,
          title: Text(
            _isReorderMode ? 'Reorder Matches' : 'Tournament Schedule',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          actions: [
            // 🔀 Reorder toggle
            IconButton(
              tooltip: 'Reorder matches',
              icon: Icon(Icons.swap_vert_rounded, color: Colors.white),
              onPressed: _toggleReorderMode,
            ),

            // ⋮ More options (ONLY when not reordering)
            if (!_isReorderMode)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onSelected: (value) {
                  switch (value) {
                    case 'share':
                      _shareTournament();
                      break;
                    case 'info':
                      _showTournamentInfo();
                      break;
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'share',
                    child: ListTile(
                      leading: Icon(Icons.share),
                      title: Text('Share'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'info',
                    child: ListTile(
                      leading: Icon(Icons.info_outline),
                      title: Text('Tournament info'),
                    ),
                  ),
                ],
              ),
          ],
        ),

        body: Column(
          children: [
            Container(
              color: Colors.orange.shade600,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: _isReorderMode
                  ? const SizedBox.shrink()
                  : TabBar(
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
                  : _isReorderMode
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
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:play_hub/constants/badminton.dart';
import 'package:play_hub/screens/tournament/badminton/knockout_widget.dart';
import 'package:play_hub/screens/tournament/badminton/points_table_screen.dart';
import 'package:play_hub/screens/tournament/badminton/scorecard.dart';
import 'package:play_hub/service/auth_service.dart';
import 'package:play_hub/service/badminton_services/badminton_service.dart';
import 'package:play_hub/service/badminton_services/match_util_service.dart';
import 'package:play_hub/service/badminton_services/tournament_dialog.dart';

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
  final _badmintonService = TournamentFirestoreService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final _authService = AuthService();

  String? _tournamentId;
  bool _isLoading = false;
  late int _tabCount;
  String? _tournamentFormat;
  String? _teamType;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeTournament();
  }

  Future<void> _initializeTournament() async {
    if (widget.tournamentId != null) {
      setState(() => _tournamentId = widget.tournamentId);
      await _fetchTournamentData();
    } else if (_validateTournamentData()) {
      await _createTournament();
    } else {
      if (mounted) {
        _showErrorSnackBar('Tournament data is incomplete');
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });
      }
    }
  }

  Future<void> _fetchTournamentData() async {
    try {
      final tournamentData = await _badmintonService.getTournament(
        _authService.currentUserEmailId ?? '',
        _tournamentId ?? '',
      );

      if (tournamentData != null && mounted) {
        final format = tournamentData['tournamentFormat'] as String?;
        final teamType = tournamentData['teamType'] as String?;

        setState(() {
          _tournamentFormat = format;
          _teamType = teamType;
          _tabCount = 2;
        });

        _tabController = TabController(length: _tabCount, vsync: this);

        debugPrint('✅ Fetched tournamentFormat: $format');
        debugPrint('✅ Fetched teamType: $teamType');
      }
    } catch (e) {
      debugPrint('❌ Error fetching tournament data: $e');
    }
  }

  bool _validateTournamentData() =>
      widget.teams != null &&
      widget.teamType != null &&
      widget.members != null &&
      widget.startDate != null &&
      widget.startTime != null &&
      widget.matchDuration != null &&
      widget.breakDuration != null &&
      widget.rematches != null &&
      widget.totalMatches != null &&
      widget.allowRematches != null;

  Future<void> _createTournament() async {
    setState(() => _isLoading = true);

    try {
      if (!_validateTournamentData()) {
        throw Exception('Missing required tournament parameters');
      }

      List<Match> matches = [];
      if (widget.teamType == 'Custom') {
        matches = CustomMatchGenerator(
          teams: widget.teams!,
          totalMatches: widget.totalMatches!,
          allowRematches: widget.allowRematches!,
          rematches: widget.rematches!,
          startDate: widget.startDate!,
          startTime: widget.startTime!,
          matchDuration: widget.matchDuration!,
          breakDuration: widget.breakDuration!,
          tournamentFormat: widget.tournamentFormat ?? 'Custom',
        ).generate();
      } else if (widget.tournamentFormat == 'knockout') {
        matches = _generateInitialKnockout();
      } else {
        matches = MatchGenerator(
          teams: widget.teams!,
          totalMatches: widget.totalMatches!,
          allowRematches: widget.allowRematches!,
          rematches: widget.rematches!,
          startDate: widget.startDate!,
          startTime: widget.startTime!,
          matchDuration: widget.matchDuration!,
          breakDuration: widget.breakDuration!,
          tournamentFormat: widget.tournamentFormat ?? 'round_robin',
        ).generate();
      }

      if (matches.isEmpty) throw Exception('Could not generate matches');

      final userEmail = _authService.currentUserEmailId;
      if (userEmail == null || userEmail.isEmpty) {
        throw Exception('User not authenticated');
      }

      final tournamentId = await _badmintonService.createTournament(
        userEmail: userEmail,
        creatorName: _authService.currentUser?.displayName ?? 'Anonymous',
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
        _tournamentFormat = widget.tournamentFormat;
        _teamType = widget.teamType;
        _tabCount = 2;
        _isLoading = false;
      });

      _tabController = TabController(length: _tabCount, vsync: this);
      _showSuccessSnackBar('Tournament created successfully!');
    } catch (e) {
      debugPrint('❌ Error creating tournament: $e');
      if (!mounted) return;

      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to create tournament: $e');
    }
  }

  List<Match> _generateInitialKnockout() {
    final matches = <Match>[];
    var shuffledTeams = List<Team>.from(widget.teams ?? [])..shuffle();
    var currentTime = widget.startDate ?? DateTime.now();

    final hasOddTeams = shuffledTeams.length.isOdd;

    if (hasOddTeams) {
      final byeTeam = shuffledTeams.removeAt(0);

      matches.add(
        Match(
          id: 'M1_BYE',
          team1: byeTeam,
          team2: byeTeam,
          date: currentTime,
          time: DateFormat('h:mm a').format(currentTime),
          status: 'Completed',
          score1: 1,
          score2: 0,
          winner: byeTeam.id,
          round: 1,
          roundName: _getRoundNameFromTeamCount(shuffledTeams.length + 1),
          stage: 'Knockout',
          isBye: true,
        ),
      );
    }

    for (int i = 0; i < shuffledTeams.length; i += 2) {
      if (i + 1 < shuffledTeams.length) {
        final team1 = shuffledTeams[i];
        final team2 = shuffledTeams[i + 1];

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
            round: 1,
            roundName: _getRoundNameFromTeamCount(
              shuffledTeams.length + (hasOddTeams ? 1 : 0),
            ),
            stage: 'Knockout',
          ),
        );

        currentTime = currentTime.add(
          Duration(
            minutes: (widget.matchDuration ?? 30) + (widget.breakDuration ?? 5),
          ),
        );
      }
    }

    debugPrint('✅ Generated ${matches.length} initial knockout matches');
    return matches;
  }

  void _initiatePlayout() async {
    try {
      final allMatches = await _badmintonService
          .getAllMatchesStream(
            _authService.currentUserEmailId ?? '',
            _tournamentId ?? '',
          )
          .first;

      final tournament = await _badmintonService.getTournament(
        _authService.currentUserEmailId ?? '',
        _tournamentId ?? '',
      );

      final leagueMatches = allMatches
          .where((m) => m.stage == 'League' || m.stage == null)
          .toList();
      final allCompleted =
          leagueMatches.isNotEmpty &&
          leagueMatches.every((m) => m.status == 'Completed');

      if (!allCompleted) {
        _showErrorSnackBar('All league matches must be completed first');
        return;
      }

      final teamsCount = tournament?["stats"]?["totalTeams"];

      List<Team> topTeams;

      switch (teamsCount) {
        case 2:
        case 3:
        case 4:
          topTeams = await _getTopTeams(2);
          break;
        case 5:
        case 6:
        case 7:
          topTeams = await _getTopTeams(4);
          break;
        case 8:
        case 9:
        case 10:
        case 11:
        case 12:
        case 13:
        case 14:
        case 15:
          topTeams = await _getTopTeams(8);
          break;
        default:
          if (teamsCount > 15) {
            topTeams = await _getTopTeams(8);
          } else {
            topTeams = [];
          }
          break;
      }

      if (topTeams.length < 2) {
        _showErrorSnackBar('Not enough teams to conduct playoffs');
        return;
      }

      if (!mounted) return;

      PlayoffChoice? choice;
      if (topTeams.length == 2) {
        choice = PlayoffChoice.directFinal;
      } else {
        choice = await _showPlayoffOptionsBottomSheet(context, topTeams.length);
      }

      if (choice == null) return;

      final playoffGenerator = PlayoffGenerator(
        topTeams: topTeams,
        startDate: widget.startDate ?? DateTime.now(),
        startTime: widget.startTime ?? const TimeOfDay(hour: 9, minute: 0),
        matchDuration: widget.matchDuration ?? 30,
        breakDuration: widget.breakDuration ?? 5,
        format: choice == PlayoffChoice.directFinal
            ? PlayoffFormat.directFinal
            : PlayoffFormat.semisAndFinal,
      );

      final playoffMatches = playoffGenerator.generate();

      await _badmintonService.addPlayoffMatches(
        _authService.currentUserEmailId ?? '',
        _tournamentId ?? '',
        playoffMatches,
      );

      // If semis & final format, schedule finals after semis are completed
      if (choice == PlayoffChoice.semisAndFinal) {
        _watchSemiFinalsCompletion(playoffMatches);
      }

      if (!mounted) return;

      setState(() {});

      _showSuccessSnackBar('Playoff matches generated successfully!');
    } catch (e) {
      debugPrint('❌ Error generating playoffs: $e');
      _showErrorSnackBar('Failed to generate playoffs: $e');
    }
  }

  void _watchSemiFinalsCompletion(List<Match> playoffMatches) {
    final userEmail = _authService.currentUserEmailId ?? '';
    final tournamentId = _tournamentId ?? '';

    _getAllMatchesStream(userEmail, tournamentId).listen((matches) async {
      final playoffRound = matches.where((m) => m.stage == 'Playoff').toList();
      final semiFinals = playoffRound
          .where((m) => m.roundName!.contains('Semi-Final'))
          .toList();

      final finalMatch = matches.where((m) => m.stage == 'Final').firstOrNull;
      // Check if both semi-finals are completed

      if (semiFinals.length == 2 &&
          semiFinals.every((m) => m.status == 'Completed') &&
          finalMatch != null &&
          (finalMatch.status == 'Pending')) {
        // Get winners from semi-finals
        final semifinal1Winner = semiFinals[0].winner;
        final semifinal2Winner = semiFinals[1].winner;

        if (semifinal1Winner != null && semifinal2Winner != null) {
          // Find the team objects
          final winner1Team = semiFinals[0].team1.id == semifinal1Winner
              ? semiFinals[0].team1
              : semiFinals[0].team2;
          final winner2Team = semiFinals[1].team1.id == semifinal2Winner
              ? semiFinals[1].team1
              : semiFinals[1].team2;

          // Update final match with winners
          final updatedFinal = Match(
            id: finalMatch.id,
            team1: winner1Team,
            team2: winner2Team,
            date: finalMatch.date,
            time: finalMatch.time,
            status: 'Scheduled',
            score1: 0,
            score2: 0,
            winner: null,
            round: 2,
            roundName: 'Final',
            stage: 'Final',
          );

          await _badmintonService.finalMatchUpdate(
            userEmail,
            tournamentId,
            updatedFinal,
          );

          debugPrint('✅ Finals scheduled with actual semifinal winners');
        }
      }
    });
  }

  Future<PlayoffChoice?> _showPlayoffOptionsBottomSheet(
    BuildContext context,
    int teamCount,
  ) async {
    return showModalBottomSheet<PlayoffChoice>(
      context: context,
      isDismissible: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.amber.shade600, Colors.amber.shade400],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.emoji_events,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Playoff Options',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$teamCount teams qualifying',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Choose your playoff format',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 16),
            _buildPlayoffOption(
              icon: Icons.flash_on,
              title: 'Direct Final',
              subtitle: 'Top 2 teams play the final immediately',
              onTap: () => Navigator.pop(context, PlayoffChoice.directFinal),
              color: Colors.blue,
            ),
            const SizedBox(height: 12),
            _buildPlayoffOption(
              icon: Icons.stairs,
              title: 'Semis & Final',
              subtitle: 'Top 4 teams compete in semi-finals first',
              onTap: () => Navigator.pop(context, PlayoffChoice.semisAndFinal),
              color: Colors.purple,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayoffOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withAlpha((255 * 0.1).toInt()),
              color.withAlpha((255 * 0.05).toInt()),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withAlpha((255 * 0.3).toInt()),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withAlpha((255 * 0.7).toInt())],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 18,
              color: color.withAlpha((255 * 0.6).toInt()),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<Team>> _getTopTeams(int count) async {
    try {
      final userEmail = _authService.currentUserEmailId;
      final tournamentId = _tournamentId;

      if (userEmail == null || tournamentId == null) {
        throw Exception('User not authenticated');
      }

      final allMatches = await _badmintonService
          .getMatches(userEmail, tournamentId)
          .first;

      final leagueMatches = allMatches
          .where(
            (m) =>
                (m.stage == 'League' || m.stage == null) &&
                m.status == 'Completed',
          )
          .toList();

      final teamPoints = <String, TeamRanking>{};

      final allTeams = allMatches
          .expand((m) => [m.team1, m.team2])
          .toSet()
          .toList();

      for (final team in allTeams) {
        teamPoints[team.id] = TeamRanking(
          team: team,
          points: 0,
          wins: 0,
          losses: 0,
          pointsFor: 0,
          pointsAgainst: 0,
        );
      }

      for (final match in leagueMatches) {
        final team1Id = match.team1.id;
        final team2Id = match.team2.id;
        final score1 = match.score1;
        final score2 = match.score2;

        if (score1 > score2) {
          teamPoints[team1Id]?.wins++;
          teamPoints[team1Id]?.points += 2;
          teamPoints[team2Id]?.losses++;
        } else if (score2 > score1) {
          teamPoints[team2Id]?.wins++;
          teamPoints[team2Id]?.points += 2;
          teamPoints[team1Id]?.losses++;
        } else {
          teamPoints[team1Id]?.points += 1;
          teamPoints[team2Id]?.points += 1;
        }

        teamPoints[team1Id]?.pointsFor += score1;
        teamPoints[team1Id]?.pointsAgainst += score2;
        teamPoints[team2Id]?.pointsFor += score2;
        teamPoints[team2Id]?.pointsAgainst += score1;
      }

      final sortedTeams = teamPoints.values.toList()
        ..sort((a, b) {
          if (a.points != b.points) {
            return b.points.compareTo(a.points);
          }

          final goalDiffA = a.pointsFor - a.pointsAgainst;
          final goalDiffB = b.pointsFor - b.pointsAgainst;
          if (goalDiffA != goalDiffB) {
            return goalDiffB.compareTo(goalDiffA);
          }

          return b.pointsFor.compareTo(a.pointsFor);
        });

      return sortedTeams.take(count).map((r) => r.team).toList();
    } catch (e) {
      debugPrint('❌ Error fetching top teams: $e');
      rethrow;
    }
  }

  void _shareTournament() {
    TournamentDialogs.showShareDialog(
      context,
      _badmintonService,
      _authService.currentUserEmailId,
      _tournamentId,
      _showSuccessSnackBar,
      _showErrorSnackBar,
    );
  }

  void _showTournamentInfo() {
    TournamentDialogs.showInfoDialog(
      context,
      _badmintonService,
      _authService.currentUserEmailId,
      _tournamentFormat,
      _teamType,
      widget.tournamentId,
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
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
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildMainContent();
  }

  Widget _buildMainContent() {
    if (_isLoading && _tournamentId == null) {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: Colors.orange.shade600,
                strokeWidth: 4,
              ),
              const SizedBox(height: 24),
              Text(
                'Creating your tournament',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Setting up matches and teams...',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red.shade400,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Tournament not found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(child: _buildTabContent()),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tournament',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade900,
            ),
          ),
          Text(
            'Schedule & Standings',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
      actions: [
        TournamentMenuButton(
          onShare: _shareTournament,
          onInfo: _showTournamentInfo,
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: Colors.grey.shade200),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: [Colors.orange.shade600, Colors.orange.shade400],
          ),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey.shade600,
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.3,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        tabs: _buildTabs(),
      ),
    );
  }

  List<Widget> _buildTabs() {
    const matchTab = Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.sports_tennis, size: 20),
          SizedBox(width: 8),
          Text('Matches'),
        ],
      ),
    );

    const standingsTab = Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.leaderboard, size: 20),
          SizedBox(width: 8),
          Text('Standings'),
        ],
      ),
    );

    return [matchTab, standingsTab];
  }

  Widget _buildTabContent() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildMatchesTab(),
        StandingsTab(
          tournamentId: _tournamentId,
          matchDuration: widget.matchDuration,
          breakDuration: widget.breakDuration,
        ),
      ],
    );
  }

  Stream<List<Match>> _getAllMatchesStream(
    String userEmail,
    String tournamentId,
  ) {
    return _firestore
        .collection('friendlyTournaments')
        .doc(tournamentId)
        .collection('matches')
        .snapshots()
        .map((snapshot) {
          final matches = snapshot.docs
              .map((doc) => Match.fromMap(doc.data()))
              .toList();

          // ✅ Client-side sort by scheduledDate
          return matches..sort((a, b) => a.date.compareTo(b.date));
        });
  }

  Widget _buildMatchesTab() {
    if (_tournamentFormat == 'knockout') {
      return KnockoutMatchesWidget(
        tournamentId: _tournamentId ?? '',
        userEmail: _authService.currentUserEmailId ?? '',
        matchDuration: widget.matchDuration,
        breakDuration: widget.breakDuration,
        startDate: widget.startDate,
        startTime: widget.startTime,
        onMatchTap: _openScorecard,
        onScoreUpdate: (updatedMatch) {
          _badmintonService.updateMatch(
            _authService.currentUserEmailId ?? '',
            _tournamentId ?? '',
            updatedMatch,
          );
        },
      );
    }

    return StreamBuilder<List<Match>>(
      stream: _getAllMatchesStream(
        _authService.currentUserEmailId ?? '',
        _tournamentId ?? '',
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ErrorStateWidget(
            error: snapshot.error,
            onRetry: () => setState(() {}),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: Colors.orange.shade600),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const EmptyMatchesWidget();
        }

        final matches = snapshot.data!;
        final leagueMatches = matches
            .where((m) => m.stage == 'League' || m.stage == null)
            .toList();
        final playoffMatches = matches
            .where((m) => m.stage == 'Playoff')
            .toList();

        final allLeagueCompleted =
            leagueMatches.isNotEmpty &&
            leagueMatches.every((m) => m.status == 'Completed');

        final allPlayoffCompleted =
            playoffMatches.isNotEmpty &&
            playoffMatches.every((m) => m.status == 'Completed');

        if (allPlayoffCompleted) {
          _watchSemiFinalsCompletion(playoffMatches);
        }

        final hasPlayoffMatches = playoffMatches.isNotEmpty;

        return Column(
          children: [
            if (allLeagueCompleted &&
                !hasPlayoffMatches &&
                _teamType != 'Custom')
              _buildNextRoundCard(),
            Expanded(
              child: MatchesListView(
                tournamentId: _tournamentId as String,
                matches: matches,
                onScoreUpdate: (updatedMatch) {
                  _badmintonService.updateMatch(
                    _authService.currentUserEmailId ?? '',
                    _tournamentId ?? '',
                    updatedMatch,
                  );
                },
                onMatchTap: _openScorecard,
              ),
            ),
          ],
        );
      },
    );
  }

  Team? _getWinner() {
    return null;
  }

  Widget _buildNextRoundCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade50, Colors.green.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.green.shade200.withAlpha((255 * 0.5).toInt()),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade600,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.shade600.withAlpha(
                          (255 * 0.3).toInt(),
                        ),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'League Completed! 🎉',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'All matches finished successfully',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha((255 * 0.8).toInt()),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.green.shade200, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ready for playoffs?',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Generate playoff matches from top-ranked teams. Choose between direct finals or semi-finals format.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _initiatePlayout,
                icon: const Icon(Icons.emoji_events, size: 20),
                label: const Text(
                  'Generate Playoffs',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 4,
                  shadowColor: Colors.green.shade600.withAlpha(
                    (255 * 0.5).toInt(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openScorecard(Match match, bool isBestOf3) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScorecardScreen(
          match: match,
          onScoreUpdate: (updatedMatch) {
            _badmintonService.updateMatch(
              _authService.currentUserEmailId ?? '',
              _tournamentId ?? '',
              updatedMatch,
            );
          },
          isBestOf3: isBestOf3,
        ),
      ),
    );
  }

  String _getRoundNameFromTeamCount(int teamCount) {
    if (teamCount == 2) return 'Final';
    if (teamCount == 4) return 'Semi-Final';
    if (teamCount <= 8) return 'Quarter-Final';
    if (teamCount <= 16) return 'Round of 16';
    if (teamCount <= 32) return 'Round of 32';
    return 'Round of $teamCount';
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

class TeamRanking {
  final Team team;
  int points;
  int wins;
  int losses;
  int pointsFor;
  int pointsAgainst;

  TeamRanking({
    required this.team,
    required this.points,
    required this.wins,
    required this.losses,
    required this.pointsFor,
    required this.pointsAgainst,
  });

  int get goalDifference => pointsFor - pointsAgainst;
}

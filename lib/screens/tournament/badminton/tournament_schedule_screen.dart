import 'package:flutter/material.dart';
import 'package:play_hub/constants/badminton.dart';
import 'package:play_hub/screens/tournament/badminton/points_table_screen.dart';
import 'package:play_hub/screens/tournament/badminton/scorecard.dart';
import 'package:play_hub/service/auth_service.dart';
import 'package:play_hub/service/badminton_services/badminton_service.dart';
import 'package:play_hub/service/badminton_services/match_util_service.dart';
import 'package:play_hub/service/badminton_services/tournament_dialog.dart';

// Helper class for team rankings
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
  final _authService = AuthService();

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
      setState(() => _tournamentId = widget.tournamentId);
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
        print('Custom Tournament Match Generator');
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
        _isLoading = false;
      });

      _showSuccessSnackBar('Tournament created successfully!');
    } catch (e) {
      debugPrint('❌ Error creating tournament: $e');
      if (!mounted) return;

      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to create tournament: $e');
    }
  }

  Future<bool> _checkAllLeagueMatchesCompleted() async {
    try {
      final allMatches = await _badmintonService
          .getMatches(
            _authService.currentUserEmailId ?? '',
            _tournamentId ?? '',
          )
          .first;

      final leagueMatches = allMatches
          .where((m) => m.stage == 'League' || m.stage == null)
          .toList();

      if (leagueMatches.isEmpty) return false;

      return leagueMatches.every((m) => m.status == 'Completed');
    } catch (e) {
      debugPrint('Error checking league completion: $e');
      return false;
    }
  }

  Widget _buildSavingOverlay(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: Colors.black.withOpacity(0.45),
      child: Center(
        child: AnimatedScale(
          scale: 1,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: AnimatedOpacity(
            opacity: 1,
            duration: const Duration(milliseconds: 200),
            child: Material(
              color: theme.colorScheme.surface,
              elevation: 8,
              borderRadius: BorderRadius.circular(20),
              shadowColor: Colors.black26,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 18),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Saving order',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Hang tight, this won\'t take long',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoundOption({
    required bool enabled,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(
            color: enabled ? Colors.amber.shade300 : Colors.grey.shade300,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
          color: enabled ? Colors.white : Colors.grey.shade100,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: enabled ? Colors.amber.shade100 : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: enabled ? Colors.amber.shade700 : Colors.grey.shade500,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: enabled ? Colors.black : Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: enabled
                          ? Colors.grey.shade600
                          : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            if (enabled)
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.amber.shade600,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _initiatePlayout() async {
    try {
      final tournament = await _badmintonService.getTournament(
        _authService.currentUserEmailId ?? '',
        _tournamentId ?? '',
      );
      final allMatches = await _badmintonService
          .getMatches(
            _authService.currentUserEmailId ?? '',
            _tournamentId ?? '',
          )
          .first;

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
      debugPrint(
        'Printing to see teams count : ${tournament?["stats"]?["totalTeams"]}',
      );
      final teamsCount = tournament?["stats"]?["totalTeams"];

      List<Team> topTeams;

      switch (teamsCount) {
        case 2:
          topTeams = await _getTopTeams(2);
          break;

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
            print('🌟 $teamsCount teams → Top 8 Playoffs');
          } else {
            topTeams = [];
          }
          break;
      }

      debugPrint('Total teams $teamsCount');
      debugPrint('Top Teams $topTeams');

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

      if (!mounted) return;

      setState(() {});

      _showSuccessSnackBar('Playoff matches generated successfully!');
    } catch (e) {
      debugPrint('❌ Error generating playoffs: $e');
      _showErrorSnackBar('Failed to generate playoffs: $e');
    }
  }

  Future<PlayoffChoice?> _showPlayoffOptionsBottomSheet(
    BuildContext context,
    int teamCount,
  ) async {
    return showModalBottomSheet<PlayoffChoice>(
      context: context,
      isDismissible: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.emoji_events,
                    color: Colors.amber.shade600,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Playoff Options',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$teamCount teams competing',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Description
            Text(
              'How would you like to proceed with the playoffs?',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),

            // Option 1: Direct Final
            _buildPlayoffOptionBottomSheet(
              icon: Icons.flash_on,
              title: 'Direct Final',
              subtitle: 'Top 2 teams play the final',
              onTap: () => Navigator.pop(context, PlayoffChoice.directFinal),
            ),
            const SizedBox(height: 12),

            // Option 2: Semis & Final
            _buildPlayoffOptionBottomSheet(
              icon: Icons.stairs,
              title: 'Semis & Final',
              subtitle: 'Top 4 teams battle for semis & final',
              onTap: () => Navigator.pop(context, PlayoffChoice.semisAndFinal),
            ),
            const SizedBox(height: 16),

            // Cancel Button
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayoffOptionBottomSheet({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.amber.shade300, width: 2),
          borderRadius: BorderRadius.circular(14),
          color: Colors.amber.shade50,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.amber.shade700, size: 28),
            ),
            const SizedBox(width: 14),
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
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 18,
              color: Colors.amber.shade600,
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
      widget.tournamentFormat,
      widget.teamType,
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
    return Stack(
      children: [
        _buildMainContent(),
        if (_isLoading) _buildSavingOverlay(context),
      ],
    );
  }

  Widget _buildMainContent() {
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
      backgroundColor: Colors.orange.shade600,
      elevation: 0,
      centerTitle: false,
      title: Text(
        'Tournament Schedule',
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      actions: [
        TournamentMenuButton(
          onShare: _shareTournament,
          onInfo: _showTournamentInfo,
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
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
        labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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

    return _tabCount == 1 ? [matchTab] : [matchTab, standingsTab];
  }

  Widget _buildTabContent() {
    return _tabCount == 1
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
          );
  }

  Widget _buildMatchesTab() {
    return StreamBuilder<List<Match>>(
      stream: _badmintonService.getAllMatchesStream(
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
        final hasPlayoffMatches = playoffMatches.isNotEmpty;

        return Column(
          children: [
            // Show next round option if all league matches are completed and no playoffs exist
            if (allLeagueCompleted &&
                !hasPlayoffMatches &&
                widget.tournamentFormat != 'knockout')
              _buildNextRoundCard(),

            // Matches List
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

  Widget _buildNextRoundCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade300, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Celebration Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.check_circle,
                  color: Colors.green.shade600,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'League Completed! 🎉',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                  Text(
                    'All matches finished successfully',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Information Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What happens next?',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Click below to generate playoff matches. The top-ranked teams from the league will compete in the next round to determine the tournament champion.',
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

          // Generate Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _initiatePlayout,
              icon: const Icon(Icons.emoji_events),
              label: const Text('Generate Next Round'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
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
          onScoreUpdate: (updatedMatch) {
            _badmintonService.updateMatch(
              _authService.currentUserEmailId ?? '',
              _tournamentId ?? '',
              updatedMatch,
            );
          },
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
